package ApiCommonData::Load::WorkflowSteps::DumpMixedGenomicSeqs;

@ISA = (GUS::Workflow::WorkflowStepInvoker);

use strict;
use GUS::Workflow::WorkflowStepInvoker;


## to do
## API $self->getExtDbRlsId($genomeExtDbRlsSpec)

sub run {
  my ($self, $test) = @_;

  my $outputFile = $self->getParamValue('outputFile');

  my $genomDbRlsId = $self->getExtDbRlsId($self->getParamValue('genomeExtDbRlsSpecc'));
 
  my $virtualDbRlsId = $self->getExtDbRlsId($self->getParamValue('genomeVirtualSeqsExtDbRlsSpec'));

  my $sql = "SELECT source_id, sequence from Dots.VIRTUALSEQUENCE
              WHERE external_database_release_id = $virtualDbRlsId
              UNION
             SELECT source_id, sequence from Dots.EXTERNALNASEQUENCE
              WHERE external_database_release_id = $genomDbRlsId
                AND na_sequence_id NOT IN (select sp.piece_na_sequence_id from dots.SEQUENCEPIECE sp, dots.VIRTUALSEQUENCE vs where vs.na_sequence_id = sp.virtual_na_sequence_id AND vs.external_database_release_id = $virtualDbRlsId)";
  
  my $cmd = "dumpSequencesFromTable.pl --outputfile $outputFile --idSQL \"$sql\" --vervbose";

  if ($test) {

      $self->runCmd(0,"test > $outputFile");

  } else {

      $self->runCmd($test,$cmd);

  }

}

sub restart {
}

sub undo {

}

sub getConfigDeclaration {
  my @properties = 
    (
     # [name, default, description]
     ['outputFile', "", ""],
     ['genomeExtDbRlsSpecc', "", ""],
     ['genomeVirtualSeqsExtDbRlsSpec', "", ""],
    );
  return @properties;
}

sub getDocumentation {
}
