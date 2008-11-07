package ApiCommonData::Load::WorkflowSteps::ExtractAssemblies;

@ISA = (GUS::Workflow::WorkflowStepInvoker);

use strict;
use GUS::Workflow::WorkflowStepInvoker;

sub run {
  my ($self, $test) = @_;

  my $taxonId = $self->getTaxonId($self->getParamValue('ncbiTaxId'));

  my $outputFile = $self->getParamValue('outputFile');

  my $sql = "select na_sequence_id,description,'('||number_of_contained_sequences||' sequences)','length='||length,sequence from dots.Assembly where taxon_id = $taxonId";
 
  my $cmd = "gusExtractSequences --outputFile $outputFile --verbose --idSQL \"$sql\"";

  if ($test){
      self->runCmd(0,'echo hello > $outputFile');
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
    );
  return @properties;
}

sub getParamDeclaration {
  my @properties = 
    (
     ['ncbiTaxonId',
      'outputFile',
     ]
    );
  return @properties;
}

sub getDocumentation {
}
