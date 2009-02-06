package ApiCommonData::Load::WorkflowSteps::ExtractNaSeqs;

@ISA = (ApiCommonData::Load::WorkflowSteps::WorkflowStep);

use strict;
use ApiCommonData::Load::WorkflowSteps::WorkflowStep;

sub run {
  my ($self, $test, $undo) = @_;

  my $table = $self->getParamValue('table');
  my $extDbRlsSpec = $self->getParamValue('extDbRlsSpec');
  my $alternateDefline = $self->getParamValue('alternateDefline');
  my $outputFile = $self->getParamValue('outputFile');
  my $separateFastaFiles = $self->getParamValue('separateFastaFiles');
  my $outputDirForSeparateFiles = $self->getParamValue('outputDirForSeparateFiles');

  my $dbRlsId = $self->getExtDbRlsId($test, $extDbRlsSpec);

  my $deflineSelect = $alternateDefline?
    $alternateDefline :
      "source_id, description, 'length='||length";

  my $sql = "SELECT $deflineSelect, sequence
             FROM dots.$table
             WHERE external_database_release_id = $dbRlsId";

  my $localDataDir = $self->getLocalDataDir();

  if ($separateFastaFiles eq 'true') {

    $self ->runCmd(0,"mkdir -p $localDataDir/$outputDirForSeparateFiles");

    if ($test) {
      $self->runCmd(0,"echo test > $localDataDir/$outputDirForSeparateFiles/IndividualSeqTest.out");
    }

    if ($undo) {
      $self->runCmd(0, "rm -rf $localDataDir/$outputDirForSeparateFiles");
    } else {
      $self->runCmd($test,"gusExtractIndividualSequences --outputDir $localDataDir/$outputDirForSeparateFiles --idSQL \"$sql\" --verbose";);
    }

  } else {

    if ($test) {
      $self->runCmd(0,"echo test > $localDataDir/$outputFile");
    }

    if ($undo) {
      $self->runCmd(0, "rm -f $localDataDir/$outputFile");
    } else {
      $self->runCmd($test,"gusExtractSequences --outputFile $localDataDir/$outputFile --idSQL \"$sql\" --verbose");
    }
}

sub getParamsDeclaration {
  return (
	  'table',
	  'extDbRlsSpec',
	  'alternateDefline',
	  'separateFastaFiles',
	  'outputFile',
	  'outputDirForSeparateFiles',
	 );
}

sub getConfigDeclaration {
  return (
	  # [name, default, description]
	 );
}


