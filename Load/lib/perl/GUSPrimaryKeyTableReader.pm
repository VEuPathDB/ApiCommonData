package ApiCommonData::Load::GUSPrimaryKeyTableReader;
use base qw(ApiCommonData::Load::GUSTableReader);

use strict;



sub getTableCount {
  my ($self, $fullTableName, $primaryKeyColumn, $maxPrimaryKey) = @_;

  my $tableName = $self->getTableNameFromPackageName($fullTableName);

  my $dbh = $self->getDatabaseHandle();
  my $sql = "select count(*) from $tableName where $primaryKeyColumn <= $maxPrimaryKey";

  my $sh = $dbh->prepare($sql);
  $sh->execute();
  my ($count) = $sh->fetchrow_array();
  $sh->finish();

  return $count;
}



# @OVERRIDE
sub getTableSql {
  my ($self, $tableName, $isSelfReferencing, $primaryKeyColumn, $maxPrimaryKey) = @_;

  $tableName = $self->getTableNameFromPackageName($tableName);

  my $sql = "select $primaryKeyColumn from $tableName";

  return $sql;
}


# @OVERRIDE
sub nextRowAsHashref {
  my ($self, $tableInfo) = @_;
  my $sh = $self->getStatementHandle();

  return $sh->fetchrow_hashref();
}

1;

