#!/usr/bin/perl

use strict;

use lib "$ENV{GUS_HOME}/lib/perl";

use DBI;
use DBD::Pg;

use Getopt::Long;

use GUS::Supported::GusConfig;

use JSON;

use ApiCommonData::Load::ApplicationTableDumper;

use Data::Dumper;

my ($help, $gusConfigFile, $jsonFile, $extDbRlsSpec);

&GetOptions('help|h' => \$help,
            'gusConfig|g=s' => \$gusConfigFile,
            'jsonFileForInstall|j=s' => \$jsonFile,
            'studyExtDbRlsSpec|x=s' => \$extDbRlsSpec
    );



my $jsonFh;
open($jsonFh, ">", $jsonFile) or die "Cannot open file $jsonFile for writing: $!";

my $schema = 'apidbuserdatasets';

# NOTE:  Will handle attributevalue separately as we already have the sqlldr files
my @tablePrefixes = ('attributegraph', 'ancestors', 'attributes', 'collection', 'attributevalue');
my $skipSqlldrTables = {'attributevalue' => [qr/^(?!attribute_stable_id$).+_stable_id$/
                                             , qr/^attribute_stable_id$/
                                             , qr/^string_value$/
                                             , qr/^number_value$/
                                             , qr/^date_value$/
                            ]};

my @viewPrefixes = ('attributevalue');

my $gusConfig = GUS::Supported::GusConfig->new($gusConfigFile);

my $login = $gusConfig->getDatabaseLogin();
my $password = $gusConfig->getDatabasePassword();
my $dbiDsn = $gusConfig->getDbiDsn();

my $dbh = DBI->connect($dbiDsn, $login, $password) or die DBI->errstr;
$dbh->{RaiseError} = 1;

my $studyRow = &lookupStudyFromSpec($extDbRlsSpec, $dbh, $schema);

my $tablesQuery = &tablesQuery(\@tablePrefixes, $schema);

my $viewsQuery = &viewsQuery(\@tablePrefixes, $schema);

my $studySpec = &studySpec();

my $entityTypeGraphSpec = &entityTypeGraphSpec();


my $applicationTableDumper = ApiCommonData::Load::ApplicationTableDumper->new({'_dbi_config_output_fh' => $jsonFh
                                                                                   , '_dbh' => $dbh
                                                                                   , '_tables_query' => $tablesQuery
                                                                                   , '_views_query' => $viewsQuery
                                                                                   , '_skip_sqlldr_tables' => $skipSqlldrTables
                                                                              });





$applicationTableDumper->addTableAndViewSpecs($studySpec);
$applicationTableDumper->addTableAndViewSpecs($entityTypeGraphSpec);

$applicationTableDumper->dumpFiles();


&dumpPreexistingCacheFiles($studyRow, $dbh, $schema, $studySpec, $entityTypeGraphSpec);

sub studySpec {
    return {name => "study",
            is_preexisting_table => JSON::true,
            type => "table",
            fields => [
                {name => "user_dataset_id",
                 type => "SQL_VARCHAR",
                 isNullable => "No",
                 maxLength => "32",
                 cacheFileIndex => 0,
                 macro => 'USER_DATASET_ID'
                },
                {name => "stable_id",
                 type => "SQL_VARCHAR",
                 isNullable => "No",
                 maxLength => "200",
                 cacheFileIndex => 1,
                },
                {name => "internal_abbrev",
                 type => "SQL_VARCHAR",
                 isNullable => "Yes",
                 maxLength => "75",
                 cacheFileIndex => 2,
                },
                {name => "modification_date",
                 type => "SQL_DATE",
                 isNullable => "No",
                 cacheFileIndex => 3,
                 macro => 'MODIFICATION_DATE'
               },
                ]
    };
}


sub entityTypeGraphSpec {
    return {name => "entitytypegraph",
            type => "table",
            is_preexisting_table => JSON::true,
            fields => [
                {name => "stable_id",
                 type => "SQL_VARCHAR",
                 isNullable => "No",
                 maxLength => "255",
                 cacheFileIndex => 0,
                },
                {name => "study_stable_id",
                 type => "SQL_VARCHAR",
                 isNullable => "No",
                 maxLength => "200",
                 cacheFileIndex => 1,
                },
                {name => "parent_stable_id",
                 type => "SQL_VARCHAR",
                 isNullable => "Yes",
                 maxLength => "255",
                 cacheFileIndex => 2,
                },
                {name => "internal_abbrev",
                 type => "SQL_VARCHAR",
                 isNullable => "No",
                 maxLength => "50",
                 cacheFileIndex => 3,
                },
                {name => "description",
                 type => "SQL_VARCHAR",
                 isNullable => "Yes",
                 maxLength => "4000",
                 cacheFileIndex => 4,
                },
                {name => "display_name",
                 type => "SQL_VARCHAR",
                 isNullable => "No",
                 maxLength => "200",
                 cacheFileIndex => 5,
                },
                {name => "display_name_plural",
                 type => "SQL_VARCHAR",
                 isNullable => "Yes",
                 maxLength => "200",
                 cacheFileIndex =>6,
                },
                {name => "has_attribute_collections",
                 type => "SQL_NUMBER",
                 isNullable => "Yes",
                 prec => "1",
                 cacheFileIndex => 7,
                },
                {name => "is_many_to_one_with_parent",
                 type => "SQL_NUMBER",
                 isNullable => "Yes",
                 prec => "1",
                 cacheFileIndex => 8,
                },
                {name => "cardinality",
                 type => "SQL_NUMBER",
                 isNullable => "Yes",
                 prec => "38",
                 cacheFileIndex => 9,
                }
                ]
    };
}



sub dumpPreexistingCacheFiles {
    my ($studyRow, $dbh, $schema, $studySpec, $entityTypeGraphSpec) = @_;

    my $studyId = $studyRow->{study_id};
    my $studyStableId = $studyRow->{stable_id};

    &writeCacheFile('study.cache', $studyRow, $studySpec);
    my $entityTypeGraphRows = &lookupEntityTypeGraphRowsFromStudyId($studyStableId, $dbh, $schema);
    foreach my $etgRow (@$entityTypeGraphRows) {
        &writeCacheFile('entitytypegraph.cache', $etgRow, $entityTypeGraphSpec);
    }
}


sub writeCacheFile {
    my ($fileName, $row, $spec) = @_;

    my @orderedFields = map {$_->{name}}
                            sort { $a->{cacheFileIndex} <=> $b->{cacheFileIndex}}
                                @{$spec->{fields}};

    open(FILE, ">", $fileName) or die "Cannot open $fileName for writing: $!";

    print FILE join("\t", map {$row->{$_}} @orderedFields) . "\n";

    close FILE;
}

sub lookupEntityTypeGraphRowsFromStudyId {
    my ($studyStableId, $dbh, $schema) = @_;

    my $sql = "select *
 from ${schema}.entitytypegraph etg
 where etg.study_stable_id = ?"
;

    my $sh = $dbh->prepare($sql);
    $sh->execute($studyStableId);

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

    my $sql = "select s.*
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

    $rv->{modification_date} = '@MODIFICATION_DATE@';
    $rv->{user_dataset_id} = '@USER_DATASET_ID@';
    return $rv;
}



sub tablesQuery {
    my ($tablePrefixes, $schema) = @_;

    return join("\nUNION\n", map {
"select table_schema, table_name
        from information_schema.tables
        where lower(table_type) != 'view'
        and lower(table_schema) = '$schema'
        and lower(table_name) like '${_}_%'"
                       } @$tablePrefixes);
}

sub viewsQuery {
    my ($prefixes, $schema) = @_;

    return join("\nUNION\n", map {
"select table_schema, table_name
        from information_schema.views
        where lower(table_schema) = '$schema'
        and lower(table_name) like '${_}_%'"
                       } @$prefixes);
}




1;
