package ApiCommonData::Load::WorkflowSteps::RunLowComplexityFilter;

@ISA = (ApiCommonData::Load::WorkflowSteps::WorkflowStep);

use strict;
use ApiCommonData::Load::WorkflowSteps::WorkflowStep;


sub run {
  my ($self, $test) = @_;

  my $seqFile = $self->getParamValue('seqFile');
  my $outputFile = $self->getParamValue('outputFile');
  my $filterType = $self->getParamValue('filterType');
  my $options = $self->getParamValue('options');

  my $blastDir = $self->getConfig('wuBlastPath');

  my $filter = "$blastDir/filter/$filterType";

  if ($test) {
      $self->runCmd(0,"echo test > $outputFile");
  } else {
      self->runCmd($test,"$filter $seqFile $options > $outputFile");
  }
}

sub getParamDeclaration {
  return (
	  'seqFile',
	  'outputFile',
	  'filterType',
	  'options',
	 );
}

sub getConfigDeclaration {
  return (
	  # [name, default, description]
	  ['wuBlastPath', "", ""],
	 );
}

sub restart {
}

sub undo {

}

sub getDocumentation {
}

