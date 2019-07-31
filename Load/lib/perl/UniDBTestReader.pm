package ApiCommonData::Load::UniDBTestReader;
use base qw(ApiCommonData::Load::UniDBTableReader);

use strict;

my $DATA = {'GUS::Model::Core::ProjectInfo' => [{'project_id' => '126', 'name' => 'TestReader'},
                                                {'project_id' => '127', 'name' => 'AnotherTestReader'},
                                                {'project_id' => '500', 'name' => 'NewerTestReader'},
#                                                {'project_id' => '501', 'name' => 'Inc addition'},
                ],
};

sub counter {
  my $self = shift;
  my $count = $self->{_counter} || 0;
  $self->{_counter}++;
  return $count;
}

sub getTableName {$_[0]->{_table_name}}
sub getMaxAlreadyLoadedPk {$_[0]->{_max_pk}}
sub getPrimaryKeyField {$_[0]->{_pk_field}}

sub prepareTable {
  my ($self, $tableName, $isSelfReferencing, $primaryKeyColumn, $maxAlreadyLoadedPk) = @_;

  $self->{_table_name} = $tableName;
}

sub finishTable {
  my $self = shift;
  $self->{_table_name} = undef;
}

sub nextRowAsHashref {
  my $self = shift;

  my $tableName = $self->getTableName();

  my $i = $self->counter();

  return $DATA->{$tableName}->[$i];
}

sub loadRow {
  return 1;
}


# TODO:  currently not testing table with soft key
sub getDistinctTablesForTableIdField {}


sub getDistinctValuesForField {
  my ($self, $tableName, $field) = @_;

  my $rows = $DATA->{$tableName} || [];

  my %rv;
  foreach my $row(@$rows) {
    my $value = $row->{lc($field)};
    $rv{$value} = 1;
  }

  return \%rv;

}


sub getMaxLobLength {
  return 3000; #more characters than I plan to type
}


sub getTableCount {
  my ($self, $tableName, $primaryKeyField, $maxPrimaryKey) = @_;

  my $rows = $DATA->{$tableName} || [];

  my $count = 0;
  foreach my $row(@$rows) {
    $count++ unless($maxPrimaryKey > $row->{$primaryKeyField});
  }

    return $count;
}


1;
