package ApiCommonData::Load::WorkflowSteps::ExtractAssemblySeqs;

@ISA = (ApiCommonData::Load::WorkflowSteps::WorkflowStep);

use strict;
use ApiCommonData::Load::WorkflowSteps::WorkflowStep;

sub run {
  my ($self, $test) = @_;

  my $parentNcbiTaxonId = $self->getParamValue('parentNcbiTaxonId');
  my $useTaxonHierarchy = $self->getParamValue('useTaxonHierarchy');
  my $outputFile = $self->getParamValue('outputFile');

  my $taxonId = $self->getTaxonId($parentNcbiTaxonId);
  my $taxonIdList = $self->getTaxonIdList($taxonId, $useTaxonHierarchy);

  my $args = "--taxon_id_list '$taxonIdList' --outputfile $outputFile --extractonly";

  self->runPlugin( $test, "DoTS::DotsBuild::Plugin::ExtractAndBlockAssemblySequences", $args);

}

sub getParamsDeclaration {
  return (
	  'parentNcbiTaxonId',
	  'useTaxonHierarchy',
	  'outputFile',
	 );
}

sub getConfigDeclaration {
  return (
	  # [name, default, description]
	 );
}

sub getDocumentation {
}

sub restart {
}

sub undo {

}

