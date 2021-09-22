package ApiCommonData::Load::Plugin::ParameterizedSchema;
@ISA = qw(GUS::PluginMgr::Plugin );
use strict;
use warnings;

sub getSchemaTables {
  my($self, $schema, $tables) = @_;
  return map { sprintf("%s.%s", $schema, $_) } @$tables;
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

sub undoPreprocess {
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
  my %schemas;
  while(my ($name) = $sh->fetchrow_array){
    $schemas{ $name } = 1;
  }
  $sh->finish();
  my @tables = @{ $self->{_undo_tables} };
  foreach my $schema (keys %schemas){
    @{ $self->{_undo_tables} } = map { join(".", $schema, $_) } @tables;
  }
}

1;
