package ApiCommonData::Load::WorkflowSteps::InsertExportPred;

@ISA = (ApiCommonData::Load::WorkflowSteps::WorkflowStep);

use strict;
use ApiCommonData::Load::WorkflowSteps::WorkflowStep;


sub run {
  my ($self, $test, $undo) = @_;

  my $inputFile = $self->getParamValue('inputFile');
  my $genomeExtDbRlsSpec = $self->getParamValue('genomeExtDbRlsSpec');

  my $localDataDir = $self->getLocalDataDir();

  my $args = "--inputFile  $inputFile --seqTable DoTS::AASequence --seqExtDbRlsSpec '$genomeExtDbRlsSpec' --extDbRlsSpec '$genomeExtDbRlsSpec'";
  if ($test) {
    $self->testInputFile('inputFile', "$localDataDir/$inputFile");
  }

  $self->runPlugin($test, $undo, "ApiCommonData::Load::Plugin::InsertExportPredFeature", $args);

}

sub getParamDeclaration {
  return (
	  'inputFile',
	  'genomeExtDbRlsSpec',
	 );
}

sub getConfigDeclaration {
  return (
	  # [name, default, description]
	  ['version', "", ""],
	 );
}

