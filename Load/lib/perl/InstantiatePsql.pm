package ApiCommonData::Load::InstantiatePsql;
use strict;

# library to perform psql macro instantiation, as used by the CreateDenormalizedTables plugin

sub instantiateSql {
    my ($sql, $tableName, $schema, $organismAbbrev, $mode, $taxonId, $projectId) = @_;

    my $cleanOrganismAbbrev = $organismAbbrev;
    $cleanOrganismAbbrev =~ s/\.//g;
    $cleanOrganismAbbrev =~ s/\-//g;

    # nullable partition key column may cause performance issues during attach partition command, so we add a NOT NULL constraint. 
    my $s = "
;
    if ($mode eq 'parent') {
        my $s = qq{

create table $schema.$tableName (like $schema.${tableName}_temporary including all)
partition by list (org_abbrev);

ALTER TABLE $schema.$tableName ALTER COLUMN orgAbbrev SET NOT NULL;

drop table $schema.${tableName}_temporary;
};
        $sql =~ s/\:CREATE_AND_POPULATE/CREATE TABLE $schema.${tableName}_temporary AS /g;
        $sql =~ s/\:DECLARE_PARTITION/$s/g;

    } elsif ($mode eq 'child') {
        my $s = qq{

    # create the child partition as a standalone (detached) table
    # and create a check constraint ensuring all rows satisfy the partition key constraint. otherwise pg will do a full scan during attach partition.
    my $s = "
CREATE TABLE $schema.${tableName}_$cleanOrganismAbbrev (LIKE $schema.$tableName INCLUDING ALL EXCLUDING INDEXES);

ALTER TABLE $schema.${tableName}_$cleanOrganismAbbrev ADD CONSTRAINT $cleanOrganismAbbrev CHECK ( orgAbbrev = '$organismAbbrev' );

insert into $schema.${tableName}_$cleanOrganismAbbrev
";
    $sql =~ s/\:CREATE_AND_POPULATE/$s/g;

    # Attach the partitioned child table to the parent and drop the now redundant check constraint on the child table.
    $s = "
ALTER TABLE $schema.$tableName ATTACH PARTITION $schema.${tableName}_$cleanOrganismAbbrev FOR VALUES in ('$organismAbbrev');

ALTER TABLE $schema.${tableName}_$cleanOrganismAbbrev DROP CONSTRAINT $cleanOrganismAbbrev;

";

    $sql =~ s/\:DECLARE_PARTITION//g;
  }

  $sql =~ s/\:TAXON_ID/$taxonId/g;
  $sql =~ s/\:PROJECT_ID/$projectId/g;
  $sql =~ s/\:ORG_ABBREV/$organismAbbrev/g;
  $sql =~ s/\:CLEAN_ORG_ABBREV/$cleanOrganismAbbrev/g;
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
