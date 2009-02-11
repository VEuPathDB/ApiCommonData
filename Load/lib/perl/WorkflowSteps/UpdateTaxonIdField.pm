package ApiCommonData::Load::WorkflowSteps::UpdateTaxonIdField;

@ISA = (ApiCommonData::Load::WorkflowSteps::WorkflowStep);

use strict;
use ApiCommonData::Load::WorkflowSteps::WorkflowStep;


sub run {
  my ($self, $test,$undo) = @_;

  my $mappingFileRelativeToDownloadDir = $self->getParamValue('mappingFileRelativeToDownloadDir');
  my $sourceIdRegex = $self->getParamValue('sourceIdRegex');
  my $taxonRegex = $self->getParamValue('taxonRegex');
  my $idSql = $self->getParamValue('idSql');
  my $extDbRlsSpec = $self->getParamValue('extDbRlsSpec');
  my $tableName = $self->getParamValue('tableName');
 
  my $downloadDir = $self->getGlobalConfig('downloadDir');

  my $mappingFile = "$downloadDir/$mappingFileRelativeToDownloadDir";

  my $args = "--fileName '$mappingFile' --sourceIdRegex  \"$sourceIdRegex\" $taxonRegex --idSql '$idSql' --extDbRelSpec '$extDbRlsSpec'  --tableName '$tableName'";

  if ($test) {
    $self->testInputFile('mappingFile', "$mappingFile");
  }

  $self->runPlugin($test, $undo, "ApiCommonData::Load::Plugin::UpdateTaxonFieldFromFile", $args);

}

sub getParamsDeclaration {
  return ('mappingFileRelativeToDownloadDir',
	  'sourceIdRegex',
	  'taxonRegex',
	  'idSql',
	  'extDbRlsSpec',
	  'tableName',
	 );
}

sub getConfigDeclaration {
  return (
	  # [name, default, description]
	 );
}

sub getDocumentation {
}

sub restart {
}

sub undo {

}


