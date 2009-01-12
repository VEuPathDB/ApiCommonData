package ApiCommonData::Load::WorkflowSteps::MakeApiSiteFilesDir;

@ISA = (ApiCommonData::Load::WorkflowSteps::WorkflowStep);
use strict;
use ApiCommonData::Load::WorkflowSteps::WorkflowStep;

## make a dir relative to the workflow's data dir

sub run {
  my ($self, $test) = @_;

  # get parameters
  my $apiSiteFilesDir = $self->getParamValue('apiSiteFilesDir');

  my $baseDir = $self->getGlobalConfig('apiSiteFilesDir');

  $self->runCmd(0, "mkdir -p $baseDir/$apiSiteFilesDir");

  # go to root of local path to avoid skipping intermediate dirs
  my @path = split(/\//,$apiSiteFilesDir);
  $self->runCmd(0, "chmod -R g+w $baseDir/$path[0]");
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
