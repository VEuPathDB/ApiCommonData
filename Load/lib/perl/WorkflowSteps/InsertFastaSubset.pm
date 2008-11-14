package ApiCommonData::Load::WorkflowSteps::LoadFastaSubset;

@ISA = (ApiCommonData::Load::WorkflowSteps::WorkflowStep);

use strict;
use ApiCommonData::Load::WorkflowSteps::WorkflowStep;


sub run {
  my ($self, $test) = @_;

  my $extDbRlsSpec = $self->getParamValue('extDbRlsSpec');
  my $fastaFile = $self->getParamValue('fastaFile');
  my $idsFile = $self->getParamValue('idsFile');

  my ($extDbName,$extDbRlsVer) = $self->getExtDbInfo($extDbRlsSpec);

  my $localDataDir = $self->getLocalDataDir();

  my $args = "--externalDatabaseName $extDbName --externalDatabaseVersion $extDbRlsVer --sequenceFile $localDataDir/$fastaFile --sourceIdsFile  $localDataDir/$idsFile --regexSourceId  '>gi\\|(\\d+)\\|' --regexDesc '^>(.+)' --tableName DoTS::ExternalAASequence";

  $self->runPlugin("GUS::Supported::Plugin::LoadFastaSequences",$args);

}

sub getParamDeclaration {
  return (
	  'idsFile',
	  'extDbRlsSpec',
	  'fastaFile',
	 );
}


sub getConfigDeclaration {
  return (
	 );
}

sub restart {
}

sub undo {

}

sub getDocumentation {
}
