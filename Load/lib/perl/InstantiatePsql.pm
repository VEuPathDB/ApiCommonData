package ApiCommonData::Load::InstantiatePsql;
use strict;

# library to perform psql macro instantiation, as used by the CreateDenormalizedTables plugin

sub instantiateSql {
    my ($sql, $tableName, $schema, $organismAbbrev, $mode, $taxonId, $projectId) = @_;

    # Escape quotes and convert to lowercase for PostgreSQL-safe quoted identifiers
    $schema         =~ s/"/""/g;
    $schema         = lc($schema);

    $tableName      =~ s/"/""/g;
    $tableName      = lc($tableName);

    $organismAbbrev =~ s/"/""/g;
    $organismAbbrev = lc($organismAbbrev);

    if ($mode eq 'parent') {
        $sql =~ s/\:CREATE_AND_POPULATE/CREATE TABLE "$schema"."${tableName}_temporary" AS /g;

        my $s = qq{

create table "$schema"."$tableName" (like "$schema"."${tableName}_temporary" including all)
partition by list (org_abbrev);

drop table "$schema"."${tableName}_temporary";
};
        $sql =~ s/\:DECLARE_PARTITION/$s/g;

    } elsif ($mode eq 'child') {

        my $s = qq{

create table ":SCHEMA"."${tableName}_$organismAbbrev"
partition of ":SCHEMA"."$tableName"
for values in (':ORG_ABBREV');

insert into ":SCHEMA"."${tableName}_$organismAbbrev"
};
        $sql =~ s/\:CREATE_AND_POPULATE/$s/g;
        $sql =~ s/\:DECLARE_PARTITION//g;
    }

    $sql =~ s/\:TAXON_ID/$taxonId/g;
    $sql =~ s/\:PROJECT_ID/$projectId/g;
    $sql =~ s/\:ORG_ABBREV/$organismAbbrev/g;
    $sql =~ s/\:SCHEMA/$schema/g;

    return $sql;
}

# use this for PLPGSQL (e.g., loops)
sub substituteDelims {
    my ($sql) = @_;
    $sql =~ s/\:PLPGSQL_DELIM/;/g;
    return $sql;
}

1;
