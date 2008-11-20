package ApiCommonData::Load::WorkflowSteps::LoadNrdbXrefs;

@ISA = (ApiCommonData::Load::WorkflowSteps::WorkflowStep);
use strict;
use ApiCommonData::Load::WorkflowSteps::WorkflowStep;

TEMPLATE
sub run {
  my ($self, $test) = @_;

  # get parameters
  my $xrefsFile = $self->getParamValue('xrefsFile');
  my $dbAbbrevList = $self->getParamValue('dbAbbrevList');
  my $nrdbExtDbRlsSpec = $self->getParamValue('nrdbExtDbRlsSpec');

  # get global properties
  my $ = $self->getGlobalConfig('');

  # get step properties
  my $ = $self->getConfig('');

  my $localDataDir = $self->getLocalDataDir();

  if ($test) {
  } else {
  }

  $self->runPlugin($test, '', $args);

}

sub getParamsDeclaration {
  return (
          'xrefsFile',
          'dbAbbrevList',
          'nrdbVersion',
         );
}

sub getConfigDeclaration {
  return (
         # [name, default, description]
         # ['', '', ''],
         );
}

sub restart {
}

sub undo {

}

sub getDocumentation {
}
