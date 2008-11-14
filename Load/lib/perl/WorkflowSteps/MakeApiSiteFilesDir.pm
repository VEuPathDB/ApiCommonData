package ApiCommonData::Load::WorkflowSteps::MakeApiSiteFilesDir;

@ISA = (ApiCommonData::Load::WorkflowSteps::WorkflowStep);
use strict;
use ApiCommonData::Load::WorkflowSteps::WorkflowStep;

## make a dir relative to the workflow's data dir

sub run {
  my ($self, $test) = @_;

  # get parameters
  my $apiSiteFilesDir = $self->getParamValue('apiSiteFilesDir');

  my $localDataDir = $self->getLocalDataDir();

  $self->runCmd(0, "mkdir $localDataDir/$apiSiteFilesDir");
}

sub getParamsDeclaration {
  return (
          'apiSiteFilesDir',
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
