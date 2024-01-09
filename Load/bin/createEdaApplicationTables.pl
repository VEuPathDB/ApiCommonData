#!/usr/bin/perl

use strict;

use lib "$ENV{GUS_HOME}/lib/perl";

use DBI;
use DBD::Pg;

use Getopt::Long;

use GUS::Supported::GusConfig;

use Data::Dumper;

use ApiCommonData::Load::ApplicationTableDumper;

my ($help, $gusConfigFile, $sqlFile, $extDbRlsSpec);

&GetOptions('help|h' => \$help,
            'gusConfig|g=s' => \$gusConfigFile,
            'schemaSqlOuptutFile|o=s' => \$sqlFile,
            'studyExtDbRlsSpec|x=s' => \$extDbRlsSpec
    );


my $sqlFh;
open($sqlFh, ">", $sqlFile) or die "Cannot open file $sqlFile for writing: $@";

my $schema = 'apidbuserdatasets';

# NOTE:  Will handle attributevalue separately as we already have the sqlldr files
my @tablePrefixes = ('attributegraph', 'ancestors', 'attributes', 'collection');
my @tablePrefixesNoSqlldr = ('attributevalue');

my @viewPrefixes = ('attributevalue');

my $gusConfig = GUS::Supported::GusConfig->new($gusConfigFile);

my $login = $gusConfig->getDatabaseLogin();
my $password = $gusConfig->getDatabasePassword();
my $dbiDsn = $gusConfig->getDbiDsn();

my $dbh = DBI->connect($dbiDsn, $login, $password) or die DBI->errstr;
$dbh->{RaiseError} = 1;


my $studyRow = &lookupStudyFromSpec($extDbRlsSpec, $dbh, $schema);

my $tablesQuery = &tablesQuery(\@tablePrefixes);
my $tablesQueryNoSqlldr = &tablesQuery(\@tablePrefixesNoSqlldr);

my $applicationTableDumper = ApiCommonData::Load::ApplicationTableDumper->new({'_schema_output_fh' => $sqlFh
                                                                                   , '_dbh' => $dbh
                                                                                   , '_tables_query' => $tablesQuery
                                                                              });

my $applicationTableDumperSkipSqlldr = ApiCommonData::Load::ApplicationTableDumper->new({'_schema_output_fh' => $sqlFh
                                                                                             , '_dbh' => $dbh
                                                                                             , '_tables_query' => $tablesQueryNoSqlldr
                                                                                             , '_skip_sqlldr_files' => 1
                                                                                        });
$applicationTableDumper->dumpFiles();
$applicationTableDumperSkipSqlldr->dumpFiles();

&dumpInserts($studyRow, $sqlFh, $dbh, $schema);

close $sqlFh;


sub dumpInserts {
    my ($studyRow, $sqlFh, $dbh, $schema) = @_;

    my $studyId = $studyRow->{study_id};
    my $studyStableId = $studyRow->{stable_id};

    my $houseKeepingFields = "modification_date, user_read, user_write, group_read, group_write,other_read, other_write, row_user_id, row_group_id, row_project_id,row_alg_invocation_id";
    my $houseKeepingValues = "SYSDATE,1, 1, 1, 1, 1, 1, 1, 1, 1, 0";

    &writeStudyRow($sqlFh, $studyRow, $houseKeepingFields, $houseKeepingValues);
    my $entityTypeRows = &lookupEntityTypeRowsFromStudyId($studyId, $dbh, $schema);
    foreach my $etRow(@$entityTypeRows) {
        &writeEntityTypeRows($sqlFh, $etRow, $studyStableId, $houseKeepingFields, $houseKeepingValues);
    }
}

sub writeEntityTypeRows {
    my ($sqlFh, $etRow, $studyStableId, $houseKeepingFields, $houseKeepingValues) = @_;

    my $entityTypeName = $etRow->{name};
    my $internalAbbrev = $etRow->{internal_abbrev};

    my $entityTypeGraphDisplayName = $etRow->{display_name};


    my $etInsert = "INSERT INTO \&1.EntityType (entity_type_id
                                              , name
                                              , internal_abbrev
                                              , study_id
                                              , $houseKeepingFields
                                              )
                    select \&1.entitytype_sq.nextval
                          , '$entityTypeName'
                          , '$internalAbbrev'
                          , s.study_id
                          , $houseKeepingValues
                    from \&1.study s
                    where s.stable_id = '$studyStableId'
                    )
";

    print $sqlFh $etInsert;

    my $etgInsert = "INSERT INTO \&1.EntityTypeGraph (entity_type_graph_id
                                              , display_name
                                              , internal_abbrev
                                              , study_id
                                              , $houseKeepingFields
                                              )
                    select \&1.entitytypegraph_sq.nextval
                          , '$entityTypeGraphDisplayName'
                          , '$internalAbbrev'
                          , s.study_id
                          , $houseKeepingValues
                    from \&1.study s
                    where s.stable_id = '$studyStableId'
                    )
";
    print $sqlFh $etgInsert;
}

sub writeStudyRow {
    my ($sqlFh, $studyRow, $houseKeepingFields, $houseKeepingValues) = @_;

    my $stableId = $studyRow->{stable_id};
    my $internalAbbrev =  $studyRow->{internal_abbrev};

    # NOTE!! use sqlplus vars for schema and user dataset id
    my $insert = "insert into \&1.study (study_id
                                       , 'stable_id'
                                       , 'internal_abbrev'
                                       , user_dataset_id
                                       , $houseKeepingFields
                                         )
                  values (\&1.study_sq.nextval
                        , $stableId
                        , $internalAbbrev
                        , \&2
                        , $houseKeepingValues
                        )
";
    print $sqlFh $insert;

}

sub lookupEntityTypeRowsFromStudyId {
    my ($studyId, $dbh, $schema) = @_;

    my $sql = "select et.name, et.internal_abbrev, etg.display_name
 from ${schema}.entitytype et, ${schema}.entitytypegraph etg
 where et.study_id = ?
and et.study_id = etg.study_id
and et.internal_abbrev = etg.internal_abbrev";

    my $sh = $dbh->prepare($sql);
    $sh->execute($studyId);

    my @rv;

    while(my $hash = $sh->fetchrow_hashref()) {
        push @rv, $hash;
    }

    $sh->finish;
    return \@rv;
}


sub lookupStudyFromSpec {
    my ($extDbRlsSpec, $dbh, $schema) = @_;

    my ($name, $version) = split(/\|/, $extDbRlsSpec);

    my $sql = "select s.study_id, s.stable_id, s.internal_abbrev, s.user_dataset_id
from ${schema}.externaldatabase d, ${schema}.externaldatabaserelease r, ${schema}.study s
where s.external_database_release_id = r.external_database_release_id
 and d.external_database_id = r.external_database_id
 and d.name = ?
 and r.version = ?";

    my $sh = $dbh->prepare($sql);
    $sh->execute($name, $version);

    my $rv;
    my $count = 0;
    while(my $hash = $sh->fetchrow_hashref()) {
        $rv = $hash;
        $count++;
    }

    die "Expected 1 study row for $extDbRlsSpec but found: $count" unless($count == 1);

    return $rv;
}



sub tablesQuery {
    my ($tablePrefixes) = @_;

    return join("\nUNION\n", map {
"select table_schema, table_name
        from information_schema.tables
        where lower(table_schema) = '$schema'
        and lower(table_name) like '${_}_%'"
                       } @$tablePrefixes);
}



1;
