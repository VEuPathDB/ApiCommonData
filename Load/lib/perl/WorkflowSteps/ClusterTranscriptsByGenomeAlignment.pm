package ApiCommonData::Load::WorkflowSteps::ClusterTranscriptsByGenomeAlignment;

@ISA = (ApiCommonData::Load::WorkflowSteps::WorkflowStep);

use strict;
use ApiCommonData::Load::WorkflowSteps::WorkflowStep;


## to do
## API $self->getTaxonId($ncbiTaxId) 

sub run {
  my ($self, $test) = @_;

  my $outputFile = $self->getParamValue('outputFile');
  my $taxonId = $self->getTaxonId($self->getParamValue('parentNcbiTaxonId'));
  my $targetDbRlsId = $self->getExtDbRlsId( $self->getParamValue('genomeExtDbRlsSpec'));
  my $maxIntronSize = $self->getParamValue('maxIntronSize');

  my $args = "--taxon_id $taxonId --target_table_name ExternalNASequence --mixedESTs "
	. "--target_db_rel_id $targetDbRlsId --out $outputFile --sort 1 --distanceBetweenStarts $maxIntronSize";

  self->runPlugin($test, "DoTS::DotsBuild::Plugin::ClusterByGenome", $args);

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
     ['parentNcbiTaxonId',
     'outputFile',
     'maxIntronSize',
     'genomeExtDbRlsSpec'],
    );
  return @properties;
}


sub restart {
}

sub undo {

}

sub getDocumentation {
}
