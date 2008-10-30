package ApiCommonData::Load::WorkflowSteps::MakeCandidateAssemblySeqs;

@ISA = (GUS::Workflow::WorkflowStepInvoker);

use strict;
use GUS::Workflow::WorkflowStepInvoker;


## to do
## API $self->getTaxonId($ncbiTaxId) 
## API $self->getTaxonIdList($taxonId,$taxonHierarchy)


sub run {
  my ($self, $test) = @_;

  my $outputFile = $self->getParamValue('outputFileOrDir');

  my $queryTaxonId = $self->getTaxonId($self->getParamValue('queryNcbiTaxonId'));

  my $targetTaxonId = $self->getTaxonId($self->getParamValue('targetNcbiTaxonId'));

  my $taxonIdList = $self->getTaxonIdList($queryTaxonId,$self->getParamValue('useTaxonHierarchy'));
  
  my $blockDir = $self->getParamValue('blockDir');

  my $cmd = "getSourceIds --outputFile $outputFile --blockFile $blockFile --clusterDir $clusterDir";

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
