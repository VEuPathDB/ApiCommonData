package ApiCommonData::Load::InstantiatePsql;
use strict;

# library to perform psql macro instantiation, as used by the CreateDenormalizedTables plugin

sub instantiateSql {
  my ($sql, $tableName, $schema, $organismAbbrev, $mode, $taxonId, $projectId) = @_;

  if ($mode eq 'parent') {
    $sql =~ s/\:CREATE_AND_POPULATE/CREATE TABLE $schema.${tableName}_temporary AS /g;

    my $s = "
;

create table $schema.$tableName (like $schema.${tableName}_temporary including all)
partition by list (org_abbrev);

drop table $schema.${tableName}_temporary;
";
    $sql =~ s/\:DECLARE_PARTITION/$s/g;

  } elsif ($mode eq 'child') {

    my $s = "
create table :SCHEMA.$tableName:ORG_SUFFIX
partition of :SCHEMA.$tableName
for values in (':ORG_ABBREV');

insert into :SCHEMA.$tableName:ORG_SUFFIX
";
    $sql =~ s/\:CREATE_AND_POPULATE/$s/g;
    $sql =~ s/\:DECLARE_PARTITION//g;
  }
  $sql =~ s/\:TAXON_ID/$taxonId/g;
  $sql =~ s/\:PROJECT_ID/$projectId/g;
  $sql =~ s/\:ORG_ABBREV/$organismAbbrev/g;
  $sql =~ $organismAbbrev? s/\:ORG_SUFFIX/_$organismAbbrev/g : s/\:ORG_SUFFIX//g;
  $sql =~ s/\:SCHEMA/$schema/g;
  return $sql;
}


1;
