package ApiCommonData::Load::InstantiatePsql;
use strict;

# library to perform psql macro instantiation, as used by the CreateDenormalizedTables plugin

sub instantiateSql {
  my ($sql, $tableName, $schema, $organismAbbrev, $mode, $taxonId, $projectId) = @_;

  if ($mode eq 'parent') {
    $sql =~ s/\:CREATE_AND_POPULATE/CREATE TABLE $schema.$tableName AS /g;
    $sql =~ s/\:DECLARE_PARTITION/partition by list (organismAbbrev)/g;
  } elsif ($mode eq 'child') {

    my $s = "
create table :SCHEMA.:ORG_ABBREV$tableName
partition of $tableName
for values in (':ORG_ABBREV');

insert into :SCHEMA.:ORG_ABBREV$tableName from
";
    $sql =~ s/\:CREATE_AND_POPULATE/$s/g;
    $sql =~ s/\:DECLARE_PARTITION//g;
  }
  $sql =~ s/\:TAXON_ID/$taxonId/g;
  $sql =~ s/\:PROJECT_ID/$projectId/g;
  $sql =~ s/\:ORG_ABBREV/$organismAbbrev/g;
  $sql =~ s/\:SCHEMA/$schema/g;
  return $sql;
}


1;
