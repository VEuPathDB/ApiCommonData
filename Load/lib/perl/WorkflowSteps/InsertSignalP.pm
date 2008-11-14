package ApiCommonData::Load::WorkflowSteps::InsertSignalP;

@ISA = (ApiCommonData::Load::WorkflowSteps::WorkflowStep);

use strict;
use ApiCommonData::Load::WorkflowSteps::WorkflowStep;


sub run {
  my ($self, $test) = @_;

  my $inputFile = $self->getParamValue('inputFile');
  my $genomeExtDbRlsSpec = $self->getParamValue('genomeExtDbRlsSpec');

  my ($extDbName,$extDbRlsVer) = $self->getExtDbInfo($genomeExtDbRlsSpec);

  my $projectName = $self->getGlobalConfig('projectName');
  my $version = $self->getConfig('version');

  my $localDataDir = $self->getLocalDataDir();

  my $args = "--data_file $localDataDir/$inputFile --algName 'SignalP' --algVer '$version' --algDesc 'SignalP' --extDbName '$extDbName' --extDbRlsVer '$extDbRlsVer' --project_name $projectName --useSourceId";

  $self->runPlugin($test, "ApiCommonData::Load::Plugin::LoadSignalP", $args);

}

sub getParamsDeclaration {
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
