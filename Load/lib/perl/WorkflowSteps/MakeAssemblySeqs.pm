package ApiCommonData::Load::WorkflowSteps::MakeAssemblySeqs;

@ISA = (ApiCommonData::Load::WorkflowSteps::WorkflowStep);

use strict;
use ApiCommonData::Load::WorkflowSteps::WorkflowStep;


## to do
## API $self->getTaxonId($ncbiTaxId) 
## API $self->getTaxonIdList($taxonId,$taxonHierarchy)
## define genomeDataDir

sub run {
  my ($self, $test) = @_;

  my $parentNcbiTaxonId = $self->getParamValue('parentNcbiTaxonId');
  my $useTaxonHierarchy = $self->getParamValue('useTaxonHierarchy');
  my $predictedTranscriptsSql = $self->getParamValue('predictedTranscriptsSql');

  my $repeatFile = $self->getConfig('vectorFile');
  my $phrapDir = $self->getConfig('phrapDir');

  my $taxonId = $self->getTaxonId($parentNcbiTaxonId);
  my $taxonIdList = $self->getTaxonIdList($taxonId, $useTaxonHierarchy);

  my $args = "--taxon_id_list '$taxonIdList' --repeatFile $repeatFile --phrapDir $phrapDir";

  $args .= " --idSQL \"$predictedTranscriptsSql\"" if ($predictedTranscriptsSql);

  self->runPlugin($test, "DoTS::DotsBuild::Plugin::MakeAssemblySequences", $args);

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

sub restart {
}

sub undo {

}

sub getDocumentation {
}
