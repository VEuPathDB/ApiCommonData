package ApiCommonData::Load::InstantiatePsql;
use strict;

# library to perform psql macro instantiation, as used by the CreateDenormalizedTables plugin

sub instantiateSql {
  my ($sql, $tableName, $schema, $organismAbbrev, $mode, $taxonId, $projectId) = @_;

  if ($mode eq 'parent') {
    $sql =~ s/\:CREATE_AND_POPULATE/CREATE TABLE $schema.${tableName}_temporary AS /g;

    # nullable partition key column may cause performance issues during attach partition command, so we add a NOT NULL constraint. 
    my $s = "
;

create table $schema.$tableName (like $schema.${tableName}_temporary including all)
partition by list (org_abbrev);

ALTER TABLE $schema.$tableName ALTER COLUMN orgAbbrev SET NOT NULL;

drop table $schema.${tableName}_temporary;
";
    $sql =~ s/\:DECLARE_PARTITION/$s/g;

  } elsif ($mode eq 'child') {

    # create the child partition as a standalone (detached) table
    # and create a check constraint ensuring all rows satisfy the partition key constraint. otherwise pg will do a full scan during attach partition.
    my $s = "
CREATE TABLE $schema.${tableName}_$organismAbbrev (LIKE $schema.$tableName INCLUDING ALL EXCLUDING INDEXES);

ALTER TABLE $schema.${tableName}_$organismAbbrev ADD CONSTRAINT $organismAbbrev CHECK ( orgAbbrev = '$organismAbbrev' );

insert into $schema.${tableName}_$organismAbbrev
";
    $sql =~ s/\:CREATE_AND_POPULATE/$s/g;

    # Attach the partitioned child table to the parent and drop the now redundant check constraint on the child table.
    $s = "
ALTER TABLE $schema.$tableName ATTACH PARTITION $schema.${tableName}_$organismAbbrev FOR VALUES in ('$organismAbbrev');

ALTER TABLE $schema.${tableName}_$organismAbbrev DROP CONSTRAINT $organismAbbrev;

";

    $sql =~ s/\:DECLARE_PARTITION//g;
  }

  $sql =~ s/\:TAXON_ID/$taxonId/g;
  $sql =~ s/\:PROJECT_ID/$projectId/g;
  $sql =~ s/\:ORG_ABBREV/$organismAbbrev/g;
  $sql =~ s/\:SCHEMA/$schema/g;
  return $sql;
}

1;
