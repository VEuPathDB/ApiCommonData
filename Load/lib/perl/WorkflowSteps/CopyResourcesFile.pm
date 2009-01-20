package ApiCommonData::Load::WorkflowSteps::CopyResourcesFile;

@ISA = (ApiCommonData::Load::WorkflowSteps::WorkflowStep);
use strict;
use ApiCommonData::Load::WorkflowSteps::WorkflowStep;

sub run {
  my ($self, $test) = @_;

  # get parameters
  my $resourcesFile = $self->getParamValue('resourcesFile');
  my $toFile = $self->getParamValue('toFile');

  # get global properties
  my $downloadDir = $self->getGlobalConfig('downloadDir');

  my $localDataDir = $self->getLocalDataDir();

  $self->runCmd(0, "gunzip $downloadDir/$resourcesFile.gz") if (-e "$downloadDir/$resourcesFile.gz");

  if ($test) {
      $self->testInputFile('resourcesFile', "$downloadDir/$resourcesFile");
  }

  $self->runCmd(0, "cp $downloadDir/$resourcesFile $localDataDir/$toFile");

}

sub getParamsDeclaration {
  return (
          'resourcesFile',
          'toFile',
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
