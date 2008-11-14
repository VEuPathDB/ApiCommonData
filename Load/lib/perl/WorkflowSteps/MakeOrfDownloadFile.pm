package ApiCommonData::Load::WorkflowSteps::MakeOrfDownloadFile;

@ISA = (ApiCommonData::Load::WorkflowSteps::WorkflowStep);
use strict;
use ApiCommonData::Load::WorkflowSteps::WorkflowStep;

TEMPLATE
sub run {
  my ($self, $test) = @_;

  # get parameters
  my $outputFile = $self->getParamValue('outputFile');
  my $genomeExtDbRlsSpec = $self->getParamValue('genomeExtDbRlsSpec');
  my $projectDB = $self->getParamValue('projectDB');

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
          'outputFile',
          'genomeExtDbRlsSpec',
          'projectDB',
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
