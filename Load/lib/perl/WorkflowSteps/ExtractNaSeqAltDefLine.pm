package ApiCommonData::Load::WorkflowSteps::ExtractNaSeqAltDefLine;

@ISA = (GUS::Workflow::WorkflowStepInvoker);

use strict;
use GUS::Workflow::WorkflowStepInvoker;


## to do
## API $self->getExtDbRlsId($genomeExtDbRlsSpec)

sub run {
  my ($self, $test) = @_;

  my $table = $self->getParamValue('table');
  
  my $dbRlsId = $self->getExtDbRlsId($self->getParamValue('extDbRlsSpec'));

  my $outputFile = $self->getParamValue('outputFile');

  my $defline = $self->getParamValue('defline');

  my $sql = "select $defLine,sequence
             from dots.$table
             where external_database_release_id = $dbRlsId";
 
  my $cmd="gusExtractSequences --outputFile $outputFile --idSQL \"$sql\" --verbose";


  
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
     ['genomeName', "", ""],
     ['seqType', "", ""],
     ['table', "", ""],
     ['identifier', "", ""],
     ['ncbiTaxId', "", ""],
     ['genomeExtDbRlsSpec', "", ""],
     ['outputFile', "", ""],
    );
  return @properties;
}

sub getDocumentation {
}
