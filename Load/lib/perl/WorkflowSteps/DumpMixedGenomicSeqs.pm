package ApiCommonData::Load::WorkflowSteps::DumpMixedGenomicSeqs;

@ISA = (ApiCommonData::Load::WorkflowSteps::WorkflowStep);

use strict;
use ApiCommonData::Load::WorkflowSteps::WorkflowStep;


## to do
## API $self->getExtDbRlsId($genomeExtDbRlsSpec)

sub run {
  my ($self, $test) = @_;

  # get params
  my $outputFile = $self->getParamValue('outputFile');
  my $genomeExtDbRlsSpec = $self->getParamValue('genomeExtDbRlsSpec');
  my $genomeVirtualSeqsExtDbRlsSpec = $self->getParamValue('genomeVirtualSeqsExtDbRlsSpec');

  my $genomDbRlsId = $self->getExtDbRlsId($genomeExtDbRlsSpec);
  my $virtualDbRlsId = $self->getExtDbRlsId($genomeVirtualSeqsExtDbRlsSpec);

  my $sql = "SELECT source_id, sequence
              FROM Dots.VIRTUALSEQUENCE
              WHERE external_database_release_id = $virtualDbRlsId
              UNION
             SELECT source_id, sequence
              FROM Dots.EXTERNALNASEQUENCE
              WHERE external_database_release_id = $genomDbRlsId
                AND na_sequence_id NOT IN
                 (SELECT sp.piece_na_sequence_id
                  FROM dots.SEQUENCEPIECE sp, dots.VIRTUALSEQUENCE vs
                  WHERE vs.na_sequence_id = sp.virtual_na_sequence_id
                  AND vs.external_database_release_id = $virtualDbRlsId)";

  my $cmd = "dumpSequencesFromTable.pl --outputfile $outputFile --idSQL \"$sql\" --vervbose";

  if ($test) {

      $self->runCmd(0,"echo test $outputFile");

  } else {

      $self->runCmd($test,$cmd);

  }

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

