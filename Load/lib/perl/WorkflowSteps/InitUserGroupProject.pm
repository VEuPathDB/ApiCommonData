package GUS::ApiCommonData::Load::WorkflowSteps::InitUserGroupProject;

@ISA = (ApiCommonData::Load::WorkflowSteps::WorkflowStep);
use strict;
use ApiCommonData::Load::WorkflowSteps::WorkflowStep;

sub run {
  my ($self, $test) = @_;

  # get global properties
  my $projectVersion = $self->getGlobalConfig('projectVersion');

  $self->runCmd($test, "insertUserProjectGroup --firstName dontcare --lastName dontcare --projectRelease $projectVersion --commit");

}

sub getParamsDeclaration {
  return (
	 );
}

sub getConfigDeclaration {
  return (
	 );
}

sub restart {
}

sub undo {

}

sub getDocumentation {
}
