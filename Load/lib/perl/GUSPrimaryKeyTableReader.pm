package ApiCommonData::Load::GUSPrimaryKeyTableReader;
use base qw(ApiCommonData::Load::GUSTableReader);

use strict;

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

