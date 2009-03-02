package ApiCommonData::Load::WorkflowSteps::ExtractAnnotatedTranscriptSeqs;

@ISA = (ApiCommonData::Load::WorkflowSteps::WorkflowStep);

use strict;
use ApiCommonData::Load::WorkflowSteps::WorkflowStep;

sub run {
  my ($self, $test, $undo) = @_;

  my $extDbRlsSpec = $self->getParamValue('extDbRlsSpec');
  my $outputFile = $self->getParamValue('outputFile');
  my $transcriptTable = $self->getParamValue('transcriptTable');
  my $seqTable = $self->getParamValue('seqTable');
  my $identifier = $self->getParamValue('identifier');

  my $dbRlsId = $self->getExtDbRlsId($test, $extDbRlsSpec);

  my $sql = "select t.$identifier, s.description,
            'length='||s.length,s.sequence
             from dots.$transcriptTable t, dots.$seqTable s
             where t.external_database_release_id = $dbRlsId
             and t.na_sequence_id = s.na_sequence_id";


  my $localDataDir = $self->getLocalDataDir();

  if ($test) {
      $self->runCmd(0,"echo test > $localDataDir/$outputFile");
  }

    if ($undo) {
      $self->runCmd(0, "rm -f $localDataDir/$outputFile");
    } else {
      $self->runCmd($test,"gusExtractSequences --outputFile $localDataDir/$outputFile --idSQL \"$sql\" --verbose");
    }

sub getParamsDeclaration {
  return (
	  'extDbRlsSpec',
	  'outputFile',
	  'transcriptTable'
	  'seqTable'
	  'identifier'
	 );
}

sub getConfigDeclaration {
  return (
	  # [name, default, description]
	 );
}


