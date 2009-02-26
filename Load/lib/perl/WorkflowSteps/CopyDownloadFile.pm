package ApiCommonData::Load::WorkflowSteps::CopyDownloadFile;

@ISA = (ApiCommonData::Load::WorkflowSteps::WorkflowStep);
use strict;
use ApiCommonData::Load::WorkflowSteps::WorkflowStep;

sub run {
  my ($self, $test, $undo) = @_;

  # get parameters
  my $fromFile = $self->getParamValue('fromFile');
  my $toFile = $self->getParamValue('toFile');

  my $apiSiteFilesDir = $self->getGlobalConfig('apiSiteFilesDir');

  my $localDataDir = $self->getLocalDataDir();

  my $cmd = "cp $apiSiteFilesDir/$fromFile $localDataDir/$toFile";

  if ($test) {
    $self->testInputFile('fromFile', "$apiSiteFilesDir/$fromFile");
    $self->runCmd(0, "cat test > $localDataDir/$toFile");
  }

  if ($undo) {
    $self->runCmd(0, "rm -f $localDataDir/$toFile");
  } else {
    $self->runCmd($test, $cmd);
  }

}

sub getParamsDeclaration {
  return (
          'fromFile',
          'toFile',
         );
}

sub getConfigDeclaration {
  return (
         # [name, default, description]
         # ['', '', ''],
         );
}


