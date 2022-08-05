package ApiCommonData::Load::Plugin::ParameterizedSchema;
use strict;
use warnings;
use Data::Dumper;

sub resetUndoTables {
  ## Called in run() only; so logRowsInserted() has the correct list of tables
  my($self) = @_;
  my $schema = $self->getArg('schema');
  my @tables = map { sprintf("%s.%s", $schema, $_) } @{$self->{_undo_tables}};
  $self->{_undo_tables} = \@tables;
}

sub getGusModelClass {
  my ($self,$table) = @_;
  my $schema = $self->getArg('schema');
  return sprintf("GUS::Model::%s::%s", $schema, $table);
}

sub requireModelObjects {
  my ($self,$schema) = @_;
  $schema ||= $self->getArg('schema');
  foreach my $table (@{ $self->{_require_tables}}){
    eval "require GUS::Model::${schema}::${table}";
  }
}

sub undoTables {
  my ($self) = @_;
  return @{ $self->{_undo_tables} }
}

sub getAlgorithmParam {
  my ($self, $dbh, $rowAlgInvocationList, $paramKey) = @_;
  my $pluginName = ref($self);
  my %paramValues;
  foreach my $rowAlgInvId (@$rowAlgInvocationList){
    my $sql  = "SELECT p.STRING_VALUE
      FROM core.ALGORITHMPARAMKEY k
      LEFT JOIN core.ALGORITHMIMPLEMENTATION a ON k.ALGORITHM_IMPLEMENTATION_ID = a.ALGORITHM_IMPLEMENTATION_ID 
      LEFT JOIN core.ALGORITHMPARAM p ON k.ALGORITHM_PARAM_KEY_ID = p.ALGORITHM_PARAM_KEY_ID 
      WHERE a.EXECUTABLE = ? 
      AND p.ROW_ALG_INVOCATION_ID = ?
      AND k.ALGORITHM_PARAM_KEY = ?";
    my $sh = $dbh->prepare($sql);
    $sh->execute($pluginName,$rowAlgInvId, $paramKey);
    while(my ($name) = $sh->fetchrow_array){
      $paramValues{ $name } = 1;
    }
    $sh->finish();
  }
  my @values = keys %paramValues;
  return \@values;
}


sub preprocessUndoGetSchemas {
  my($self, $dbh, $rowAlgInvocationList) = @_;
  my $pluginName = ref($self);
 #my %schemaNames;
 #foreach my $rowAlgInvId (@$rowAlgInvocationList){
 #  my $sql  = "SELECT p.STRING_VALUE
 #FROM core.ALGORITHMPARAMKEY k
 #LEFT JOIN core.ALGORITHMIMPLEMENTATION a ON k.ALGORITHM_IMPLEMENTATION_ID = a.ALGORITHM_IMPLEMENTATION_ID 
 #LEFT JOIN core.ALGORITHMPARAM p ON k.ALGORITHM_PARAM_KEY_ID = p.ALGORITHM_PARAM_KEY_ID 
 #WHERE a.EXECUTABLE = ? 
 #AND p.ROW_ALG_INVOCATION_ID = ?
 #AND k.ALGORITHM_PARAM_KEY = 'schema'";
 #  my $sh = $dbh->prepare($sql);
 #  $sh->execute($pluginName,$rowAlgInvId);
 #  while(my ($name) = $sh->fetchrow_array){
 #    $schemaNames{ $name } = 1;
 #  }
 #  $sh->finish();
 #}
 #my @schemas = keys %schemaNames;
 #return \@schemas;
  my $schemas = $self->getAlgorithmParam($dbh, $rowAlgInvocationList, 'schema');
  return $schemas;
}

sub undoPreprocess {
  my($self, $dbh, $rowAlgInvocationList) = @_;
  my @allUndoTables;
  my $schemas = $self->preprocessUndoGetSchemas($dbh, $rowAlgInvocationList);
  foreach my $schema (@$schemas){
     push(@allUndoTables, map { join(".", $schema, $_) } @{ $self->{_undo_tables} });
  }
  $self->{_undo_tables} = \@allUndoTables;
}

1;
