package ApiCommonData::Load::WorkflowSteps::InsertTandemRepeats;

@ISA = (ApiCommonData::Load::WorkflowSteps::WorkflowStep);

use strict;
use ApiCommonData::Load::WorkflowSteps::WorkflowStep;


sub run {
  my ($self, $test, $undo) = @_;

  my $inputFile = $self->getParamValue('inputFile');
  my $genomeExtDbRlsSpec = $self->getParamValue('genomeExtDbRlsSpec');

  my ($extDbName,$extDbRlsVer) = $self->getExtDbInfo($test,$genomeExtDbRlsSpec);

  my $localDataDir = $self->getLocalDataDir();

  my $args = "--tandemRepeatFile $localDataDir/$inputFile --extDbName '$extDbName' --extDbVersion '$extDbRlsVer'";

  if ($test) {
    $self->testInputFile('inputFile', "$localDataDir/$inputFile");
  }


  $self->runPlugin($test, $undo, "GUS::Supported::Plugin::InsertTandemRepeatFeatures", $args);
}

sub getParamsDeclaration {
  return (
	  'inputFile',
	  'genomeExtDbRlsSpec',
	 );
}

sub getConfigDeclaration {
  return (
	 );
}


