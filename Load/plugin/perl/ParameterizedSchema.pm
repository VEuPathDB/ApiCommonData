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
    printf STDERR ("DEBUG OK require $schema $table\n");
  }
}

sub undoTables {
  my ($self) = @_;
  return @{ $self->{_undo_tables} }
}

sub preprocessUndoGetSchemas {
  my($self, $dbh, $rowAlgInvocationList) = @_;
  my $rowAlgInvocations = join(',', @{$rowAlgInvocationList});
  my $pluginName = ref($self);
  my $sql  = "SELECT p.STRING_VALUE
FROM core.ALGORITHMPARAMKEY k
LEFT JOIN core.ALGORITHMIMPLEMENTATION a ON k.ALGORITHM_IMPLEMENTATION_ID = a.ALGORITHM_IMPLEMENTATION_ID 
LEFT JOIN core.ALGORITHMPARAM p ON k.ALGORITHM_PARAM_KEY_ID = p.ALGORITHM_PARAM_KEY_ID 
WHERE a.EXECUTABLE = ? 
AND p.ROW_ALG_INVOCATION_ID in (?)
AND k.ALGORITHM_PARAM_KEY = 'schema'";
  my $sh = $dbh->prepare($sql);
  $sh->execute($pluginName,$rowAlgInvocations);
  my %schemaNames;
  while(my ($name) = $sh->fetchrow_array){
    $schemaNames{ $name } = 1;
  }
  $sh->finish();
  my @schemas = keys %schemaNames;
  return \@schemas;
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
