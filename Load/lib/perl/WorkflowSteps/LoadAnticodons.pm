package ApiCommonData::Load::WorkflowSteps::LoadAnticodons;

@ISA = (ApiCommonData::Load::WorkflowSteps::WorkflowStep);

use strict;
use ApiCommonData::Load::WorkflowSteps::WorkflowStep;


sub run {
  my ($self, $test, $undo) = @_;

  my $inputFileRelativeToManualDeliveryDir = $self->getParamValue('inputFileRelativeToManualDeliveryDir');
  my $genomeExtDbRlsSpec = $self->getParamValue('genomeExtDbRlsSpec');

  my $manualDeliveryDir = $self->getGlobalConfig('manualDeliveryDir');

  my ($extDbName,$extDbRlsVer) = $self->getExtDbInfo($test,$genomeExtDbRlsSpec);

  my $args = "--data_file $manualDeliveryDir/$inputFileRelativeToManualDeliveryDir --genomeDbName '$extDbName' --genomeDbVer '$extDbRlsVer'";


  if ($test) {
    $self->testInputFile('inputFile', "$manualDeliveryDir/$inputFileRelativeToManualDeliveryDir");
  }

  $self->runPlugin($test, $undo, "ApiCommonData::Load::Plugin::InsertAntiCodon", $args);

}

sub getParamDeclaration {
  return (
	  'inputFileRelativeToManualDeliveryDir',
	  'genomeExtDbRlsSpec',
	 );
}

sub getConfigDeclaration {
  return (
	  # [name, default, description]
	  ['version', "", ""],
	 );
}

