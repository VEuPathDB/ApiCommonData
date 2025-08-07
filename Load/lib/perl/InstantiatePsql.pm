package ApiCommonData::Load::InstantiatePsql;
use strict;

# library to perform psql macro instantiation, as used by the CreateDenormalizedTables plugin

sub instantiateSql {
    my ($sql, $tableName, $schema, $organismAbbrev, $mode, $taxonId, $projectId) = @_;

  # Quote organismAbbrev if it contains special characters (e.g., hyphen)
    my $quotedOrgAbbrev = quote_if_needed($organismAbbrev);

    if ($mode eq 'parent') {
	$sql =~ s/\:CREATE_AND_POPULATE/CREATE TABLE $schema.${tableName}_temporary AS /g;

    my $s = qq{

create table $schema.$tableName (like $schema.${tableName}_temporary including all)
partition by list (org_abbrev);

drop table $schema.${tableName}_temporary;
};
    $sql =~ s/\:DECLARE_PARTITION/$s/g;

    } elsif ($mode eq 'child') {

	my $childTable = "${tableName}_$quotedOrgAbbrev";

	my $s = qq{

create table :SCHEMA.$childTable
partition of :SCHEMA.$tableName
for values in (':ORG_ABBREV');

insert into :SCHEMA.$childTable
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

# Quote organismAbbrev only if it contains non-alphanumeric or underscore
sub quote_if_needed {
    my ($name) = @_;
    return $name =~ /[^a-zA-Z0-9_]/ ? qq{"$name"} : $name;
}

# use this for PLPGSQL (e.g., loops)
sub substituteDelims {
    my ($sql) = @_;
    $sql =~ s/\:PLPGSQL_DELIM/;/g;
    return $sql;
}

1;
