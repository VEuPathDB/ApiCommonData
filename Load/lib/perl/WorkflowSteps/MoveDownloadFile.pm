package ApiCommonData::Load::WorkflowSteps::MoveDownloadFile;

@ISA = (ApiCommonData::Load::WorkflowSteps::WorkflowStep);
use strict;
use ApiCommonData::Load::WorkflowSteps::WorkflowStep;

sub run {
  my ($self, $test) = @_;

  # get parameters
  my $fromFile = $self->getParamValue('fromFile');
  my $toFile = $self->getParamValue('toFile');

  my $apiSiteFilesDir = $self->getGlobalConfig('apiSiteFilesDir');

  my $localDataDir = $self->getLocalDataDir();

  my $cmd = "cp $apiSiteFilesDir/$fromFile $localDataDir/$toFile";
  
  $self->runCmd(0, $cmd);

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

sub restart {
}

sub undo {

}

sub getDocumentation {
}
