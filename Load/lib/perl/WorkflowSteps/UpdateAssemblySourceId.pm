package ApiCommonData::Load::WorkflowSteps::UpdateAssemblySourceId;

@ISA = (ApiCommonData::Load::WorkflowSteps::WorkflowStep);

use strict;
use ApiCommonData::Load::WorkflowSteps::WorkflowStep;

sub run {

  my ($self, $test,$undo) = @_;

  my $ncbiTaxonId = $self->getParamValue('ncbiTaxonId');
  my $organismTwoLetterAbbrev = $self->getParamValue('organismTwoLetterAbbrev');

  my $taxonId = $self->getTaxonIdFromNcbiTaxId($test, $ncbiTaxonId);

  my $args = "--prefix '${organismTwoLetterAbbrev}DT.' --suffix '.tmp' --taxonId $taxonId";

  $self->runPlugin($test, $undo,"ApiCommonData::Load::Plugin::UpdateAssemblySourceId",$args);
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


