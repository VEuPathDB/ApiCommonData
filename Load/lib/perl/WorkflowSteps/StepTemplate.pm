package GUS::ApiCommonData::Load::WorkflowSteps::;

@ISA = (ApiCommonData::Load::WorkflowSteps::WorkflowStep);
use strict;
use ApiCommonData::Load::WorkflowSteps::WorkflowStep;

sub run {
  my ($self, $test) = @_;

  # get global properties
  my $ = $self->getGlobalConfig('');

  # get step properties
  my $ = $self->getConfig('');

  # get parameters
  my $ = $self->getParamValue('');

  if ($test) {
  } else {
  }

  $self->runCmd($test, "echo $name $mood $msg > teststep.out");

}

sub getConfigDeclaration {
  my $properties =
    [
     # [name, default, description]
     ['', "", ""],
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
