package ApiCommonData::Load::WorkflowSteps::CopyResourcesFileDir;

@ISA = (ApiCommonData::Load::WorkflowSteps::WorkflowStep);
use strict;
use ApiCommonData::Load::WorkflowSteps::WorkflowStep;

sub run {
  my ($self, $test) = @_;

  # get parameters
  my $resourcesFileDir = $self->getParamValue('resourcesFileDir');
  my $toDir = $self->getParamValue('toDir');

  # get global properties
  my $downloadDir = $self->getGlobalConfig('downloadDir');

  my $localDataDir = $self->getLocalDataDir();

  $self->runCmd(0,"mkdir -p $toDir") if $toDir;
  
  unless (-e $resourcesFileDir) { die "$resourcesFileDir doesn't exist\n";};

  $self->runCmd(0, "cp -ar  $resourcesFileDir $toDir");

}

sub getParamsDeclaration {
  return (
          'resourcesFileDir',
          'toDir',
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
