package ApiCommonData::Load::WorkflowSteps::ExtractAssemblies;

@ISA = (GUS::Workflow::WorkflowStepInvoker);

use strict;
use GUS::Workflow::WorkflowStepInvoker;


## to do
## API $self->getTaxonId($ncbiTaxId) 

sub run {
  my ($self, $test) = @_;

  my $taxonId = $self->getTaxonId($self->getParamValue('ncbiTaxId'));

  my $outputFile = $self->getParamValue('outputFileOrDir');

  my $organismName = $self->getParamValue('organismName');

  my $sql = "select na_sequence_id,'[$organismName]',description,'('||number_of_contained_sequences||' sequences)','length='||length,sequence from dots.Assembly where taxon_id = $taxonId";
 
  my $cmd = "gusExtractSequences --outputFile $outputFile --verbose --idSQL \"$sql\"";

  if ($test){
      self->runCmd(0,'test > $outputFile');
  }else{
      self->runCmd($test,$cmd);      
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
     ['parentNcbiTaxonId', "", ""],
     ['useTaxonHierarchy', "", ""],
     ['predictedTranscriptsSql', "", ""],
    );
  return @properties;
}

sub getDocumentation {
}
