package ApiCommonData::Load::WorkflowSteps::MakeAssemblySeqs;

@ISA = (ApiCommonData::Load::WorkflowSteps::WorkflowStep);

use strict;
use ApiCommonData::Load::WorkflowSteps::WorkflowStep;

sub run {
  my ($self, $test, $undo) = @_;

  my $parentNcbiTaxonId = $self->getParamValue('parentNcbiTaxonId');
  my $useTaxonHierarchy = $self->getParamValue('useTaxonHierarchy');
  my $predictedTranscriptsSql = $self->getParamValue('predictedTranscriptsSql');

  my $vectorFile = $self->getConfig('vectorFile');
  my $phrapDir = $self->getConfig('phrapDir');

  my $taxonId = $self->getTaxonIdFromNcbiTaxId($test,$parentNcbiTaxonId);
  my $taxonIdList = $self->getTaxonIdList($test, $taxonId, $useTaxonHierarchy);

  my $args = "--taxon_id_list '$taxonIdList' --repeatFile $vectorFile --phrapDir $phrapDir";

  $args .= " --idSQL \"$predictedTranscriptsSql\"" if ($predictedTranscriptsSql);

  $self->runPlugin($test, $undo, "DoTS::DotsBuild::Plugin::MakeAssemblySequences", $args);

}

sub getParamsDeclaration {
  return (
	  'parentNcbiTaxonId',
	  'useTaxonHierarchy',
	  'predictedTranscriptsSql',
	 );
}

sub getConfigDeclaration {
  return (
	  # [name, default, description]
	  ['vectorFile', "", ""],
	  ['phrapDir', "", ""],
	 );
}


