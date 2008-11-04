package ApiCommonData::Load::WorkflowSteps::PutUnalignedTranscriptsIntoOneCluster;

@ISA = (GUS::Workflow::WorkflowStepInvoker);

use strict;
use GUS::Workflow::WorkflowStepInvoker;


## to do
## API $self->getTaxonId($ncbiTaxId) 
## API $self->getTaxonIdList($taxonId,$taxonHierarchy)


sub run {
  my ($self, $test) = @_;

  my $outputFile = $self->getParamValue('outputFile');

  my $inputFile = $self->getParamValue('inputFile');

  my $queryTaxonId = $self->getTaxonId($self->getParamValue('queryNcbiTaxonId'));

  my $subjectTaxonId = $self->getTaxonId($self->getParamValue('subjectNcbiTaxonId'));

  my $taxonIdList = $self->getTaxonIdList($queryTaxonId,$self->getParamValue('useTaxonHierarchy'));
  
  my $repeatMaskErrFile = $self->getParamValue('repeatMaskErrFile');

  my $cmd = "getSourceIds --inputFile $inputFile --outputFile $outputFile --blockFile $repeatMaskErrFile";

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
     ['inputFile', "", ""],
     ['outputFile', "", ""],
     ['queryNcbiTaxonId', "", ""],
     ['subjectNcbiTaxonId', "", ""],
     ['useTaxonHierarchy', "", ""],
     ['repeatMaskErrFile', "", ""],
    );
  return @properties;
}

sub getDocumentation {
}
