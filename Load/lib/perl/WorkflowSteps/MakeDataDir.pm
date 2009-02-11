package ApiCommonData::Load::WorkflowSteps::MakeDataDir;

@ISA = (ApiCommonData::Load::WorkflowSteps::WorkflowStep);
use strict;
use ApiCommonData::Load::WorkflowSteps::WorkflowStep;

## make a dir relative to the workflow's data dir

sub run {
  my ($self, $test) = @_;

  # get parameters
  my $dataDir = $self->getParamValue('dataDir');

  my $localDataDir = $self->getLocalDataDir();

  $self->runCmd(0, "mkdir $localDataDir/$dataDir");
}

sub getParamsDeclaration {
  return (
          'dataDir',
         );
}

sub getConfigDeclaration {
  return (
         # [name, default, description]
         # ['', '', ''],
         );
}


