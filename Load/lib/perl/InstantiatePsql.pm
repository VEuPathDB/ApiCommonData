package ApiCommonData::Load::InstantiatePsql;
use strict;

# library to perform psql macro instantiation, as used by the CreateDenormalizedTables plugin

sub instantiateSql {
    my ($sql, $tableName, $schema, $organismAbbrev, $mode, $taxonId, $projectId) = @_;

    # Escape quotes for PostgreSQL-safe quoted identifiers
    $schema    =~ s/"/""/g;
    $tableName =~ s/"/""/g;

    my $refOrgAbb = $organismAbbrev;
    $refOrgAbb =~ s/\./\_/g;
    $refOrgAbb =~ s/\-/\_/g;

    my $org_abbrev_literal = $organismAbbrev;
    $org_abbrev_litteral =~ s/'/''/g;              # escape single quotes for SQL
   
    if ($mode eq 'parent') {
        my $s = qq{

create table "$schema"."$tableName" (like "$schema"."${tableName}_temporary" including all)
partition by list (org_abbrev);

drop table "$schema"."${tableName}_temporary";
};
        $sql =~ s/\:CREATE_AND_POPULATE/CREATE TABLE "$schema"."${tableName}_temporary" AS /g;
        $sql =~ s/\:DECLARE_PARTITION/$s/g;

    } elsif ($mode eq 'child') {
        my $s = qq{

create table ":SCHEMA"."${tableName}_${organismAbbrev}"
partition of ":SCHEMA"."$tableName"
for values in (:ORG_ABBREV);

insert into ":SCHEMA"."${tableName}_${organismAbbrev}"
};
        $sql =~ s/\:CREATE_AND_POPULATE/$s/g;
        $sql =~ s/\:DECLARE_PARTITION//g;
    }

    $sql =~ s/\:TAXON_ID/$taxonId/g;
    $sql =~ s/\:PROJECT_ID/$projectId/g;
    $sql =~ s/\:ORG_ABBREV/$organismAbbrev/g;
    $sql =~ s/\:REF_ORG_ABBREV/$refOrgAbb/g;
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
