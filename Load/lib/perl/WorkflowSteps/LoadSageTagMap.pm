package ApiCommonData::Load::WorkflowSteps::LoadSageTagMap;

@ISA = (ApiCommonData::Load::WorkflowSteps::WorkflowStep);

use strict;
use ApiCommonData::Load::WorkflowSteps::WorkflowStep;


sub run {
  my ($self, $test, $undo) = @_;

  my $inputFile = $self->getParamValue('inputFile');

  my $localDataDir = $self->getLocalDataDir();
      
  my $args = "--tagToSeqFile $localDataDir/$inputFile";

  if ($test) {
    $self->testInputFile('inputFile', "$localDataDir/$inputFile");
  }

  $self->runPlugin($test, $undo, "ApiCommonData::Load::Plugin::LoadExpressionFeature", $args);

}

sub getParamDeclaration {
  return (
	  'inputFile',
	 );
}

sub getConfigDeclaration {
  return (
	  # [name, default, description]
	 );
}

