package ApiCommonData::Load::WorkflowSteps::FormatNcbiBlastFile;

@ISA = (ApiCommonData::Load::WorkflowSteps::WorkflowStep);

use strict;
use ApiCommonData::Load::WorkflowSteps::WorkflowStep;

sub run {
  my ($self, $test) = @_;

  my $inputFile = $self->getParamValue('inputFile');
  my $formatterArgs = $self->getParamValue('formatterArgs');
  my $ncbiBlastPath = $self->getConfig('ncbiBlastPath');

  my $localDataDir = $self->getLocalDataDir();

  $self->runcmd($test,"$ncbiBlastPath/formatdb -i $localDataDir/$inputFile -p $formatterArgs");
}

sub getParamsDeclaration {
  return ('inputFile',
	  'formatterArgs'
	 );
}

sub getConfigDeclaration {
  return (
	  # [name, default, description]
	  ['ncbiBlastPath', "", ""],
	 );
}

sub getDocumentation {
}

sub restart {
}

sub undo {

}
