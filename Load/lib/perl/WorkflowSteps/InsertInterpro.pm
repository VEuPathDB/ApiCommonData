package GUS::ApiCommonData::Load::WorkflowSteps::InsertInterpro;

@ISA = (ApiCommonData::Load::WorkflowSteps::WorkflowStep);
use strict;
use ApiCommonData::Load::WorkflowSteps::WorkflowStep;

TEMPLATE
sub run {
  my ($self, $test) = @_;

  # get parameters
  my $ = $self->getParamValue('');
  my $interproExtDbRlsSpec = $self->getParamValue('interproExtDbRlsSpec');
  my $configFileRelativeToDownloadDir = $self->getParamValue('configFileRelativeToDownloadDir');

  # get global properties
  my $ = $self->getGlobalConfig('');

  # get step properties
  my $ = $self->getConfig('');

  if ($test) {
  } else {
  }

  $self->runPlugin($test, '', $args);

}

sub getParamsDeclaration {
  return (
          '',
          'interproExtDbRlsSpec',
          'configFileRelativeToDownloadDir',
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
