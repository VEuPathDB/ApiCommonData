package ApiCommonData::Load::WorkflowSteps::StartClusterTask;

@ISA = (ApiCommonData::Load::WorkflowSteps::WorkflowStep);
use strict;
use ApiCommonData::Load::WorkflowSteps::WorkflowStep;

TEMPLATE
sub run {
  my ($self, $test) = @_;

  # get parameters
  my $taskDir = $self->getParamValue('taskDir');
  my $queue = $self->getParamValue('queue');
  my $cmdName = $self->getParamValue('cmdName');
  my $cmdArgs = $self->getParamValue('cmdArgs');

  # get global properties
  my $ = $self->getGlobalConfig('');

  # get step properties
  my $ = $self->getConfig('');

  if ($test) {
  } else {
  }

  $self->runPlugin($test, '', $args);

}

sub getParamsDeclaration {
  return (
          'taskDir',
          'queue',
          'cmdName',
          'cmdArgs',
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
