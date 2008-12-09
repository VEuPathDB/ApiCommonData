package ApiCommonData::Load::WorkflowSteps::InsertTmhmm;

@ISA = (ApiCommonData::Load::WorkflowSteps::WorkflowStep);

use strict;
use ApiCommonData::Load::WorkflowSteps::WorkflowStep;


sub run {
  my ($self, $test) = @_;

  my $inputFile = $self->getParamValue('inputFile');
  my $genomeExtDbRlsSpec = $self->getParamValue('genomeExtDbRlsSpec');

  my $version = $self->getConfig('version');

  my ($extDbName,$extDbRlsVer) = $self->getExtDbInfo($genomeExtDbRlsSpec);

  my $localDataDir = $self->getLocalDataDir();

  my $args = "--data_file $localDataDir/$inputFile --algName TMHMM --algDesc 'TMHMM $version' --useSourceId --extDbName '$extDbName' --extDbRlsVer '$extDbRlsVer'";

  if ($test) {
    $self->testInputFile('inputFile', "$localDataDir/$inputFile");
  }

  $self->runPlugin($test, "ApiCommonData::Load::Plugin::LoadTMDomains",$args);

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

sub restart {
}

sub undo {

}

sub getDocumentation {
}
