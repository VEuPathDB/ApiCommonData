package ApiCommonData::Load::WorkflowSteps::UpdateAssemblySourceId;

@ISA = (ApiCommonData::Load::WorkflowSteps::WorkflowStep);

use strict;
use ApiCommonData::Load::WorkflowSteps::WorkflowStep;

sub run {

  my ($self, $test,$undo) = @_;

  my $ncbiTaxonId = $self->getParamValue('ncbiTaxonId');
  my $organismTwoLetterAbbrev = $self->getParamValue('organismTwoLetterAbbrev');

  my $taxonId = $self->getTaxonIdFromNcbiTaxId($test, $ncbiTaxonId);

  my $cmd = "updateAssSourceIdFromPK --prefix '${organismTwoLetterAbbrev}DT.' --suffix '.tmp' --TaxonId $taxonId";

  if ($undo){
  }else{
      $self->runCmd($test, $cmd);      
  }
}

sub getParamDeclaration {
  return (
     'ncbiTaxonId',
     'organismTwoLetterAbbrev',
    );
}

sub getConfigDeclaration {
  return
    (
     # [name, default, description]
    );
}


