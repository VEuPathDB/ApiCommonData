package ApiCommonData::Load::WorkflowSteps::ExtractMixedGenomicSeqs;

@ISA = (ApiCommonData::Load::WorkflowSteps::WorkflowStep);

use strict;
use ApiCommonData::Load::WorkflowSteps::WorkflowStep;


## to do
## API $self->getExtDbRlsId($test, $genomeExtDbRlsSpec)

sub run {
  my ($self, $test) = @_;

  # get params
  my $outputFile = $self->getParamValue('outputFile');
  my $genomeExtDbRlsSpec = $self->getParamValue('genomeExtDbRlsSpec');
  my $genomeVirtualSeqsExtDbRlsSpec = $self->getParamValue('genomeVirtualSeqsExtDbRlsSpec');
  my $genomeSource = $self->getParamValue('genomeSource');

  my $genomDbRlsId = $self->getExtDbRlsId($test, $genomeExtDbRlsSpec);
  my $virtualDbRlsId = $self->getExtDbRlsId($test, $genomeVirtualSeqsExtDbRlsSpec);

  my $sql1 = "select source_id, sequence from Dots.VIRTUALSEQUENCE where external_database_release_id = '$virtualDbRlsId'";

  my $sql2 =  "select source_id, sequence from Dots.EXTERNALNASEQUENCE es where external_database_release_id = '$genomDbRlsId' and es.na_sequence_id NOT IN (select sp.piece_na_sequence_id from dots.SEQUENCEPIECE sp, dots.VIRTUALSEQUENCE vs where vs.na_sequence_id = sp.virtual_na_sequence_id AND vs.external_database_release_id ='$virtualDbRlsId')";

  my $localDataDir = $self->getLocalDataDir();

  my $cmd1 = "dumpSequencesFromTable.pl --outputfile $localDataDir/$outputFile --idSQL \"$sql1\" --verbose";

  my $cmd2 = "dumpSequencesFromTable.pl --outputfile $localDataDir/$outputFile --idSQL \"$sql2\" --verbose";

  if ($test) {
      $self->runCmd(0,"echo test > $localDataDir/$outputFile");
  }

  $self->runCmd($test,$cmd1);
  $self->runCmd($test,$cmd2);


}

sub getParamsDeclaration {
  my @properties =
    ('outputFile',
     'genomeExtDbRlsSpec',
     'genomeVirtualSeqsExtDbRlsSpec',
    );
  return @properties;
}

sub getConfigDeclaration {
  my @properties = 
    (
     # [name, default, description]
    );
  return @properties;
}

sub getDocumentation {
}

sub restart {
}

sub undo {

}

