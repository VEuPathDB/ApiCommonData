package GUS::ApiCommonData::Load::WorkflowSteps::InitUserGroupProject;

@ISA = (GUS::Workflow::WorkflowStepInvoker);
use strict;
use GUS::Workflow::WorkflowStepInvoker;

sub run {
  my ($self, $test) = @_;

  # get global properties
  my $projectVersion = $self->getGlobalConfig('projectVersion');

  $self->runCmd($test, "insertUserProjectGroup --firstName dontcare --lastName dontcare --projectRelease $projectVersion --commit");

}

sub getConfigDeclaration {
  my $properties =
    [
    ];
  return $properties;
}

sub getParamDeclaration {
  my $properties =
    [];
  return $properties;
}

sub restart {
}

sub undo {

}

sub getDocumentation {
}
