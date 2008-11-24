package ApiCommonData::Load::WorkflowSteps::ClusterTranscriptsByGenomeAlignment;

@ISA = (ApiCommonData::Load::WorkflowSteps::WorkflowStep);

use strict;
use ApiCommonData::Load::WorkflowSteps::WorkflowStep;

sub run {
  my ($self, $test) = @_;

  my $outputFile = $self->getParamValue('outputFile');
  my $ncbiTaxonId = $self->getParamValue('parentNcbiTaxonId');
  my $genomeExtDbRlsSpec = $self->getParamValue('genomeExtDbRlsSpec');
  my $maxIntronSize = $self->getParamValue('maxIntronSize');

  my $taxonId = $self->getTaxonIdFromNcbiTaxonId($ncbiTaxonId);
  my $targetDbRlsId = $self->getExtDbRlsId($test, $genomeExtDbRlsSpec);

  my $localDataDir = $self->getLocalDataDir();

  my $args = "--taxon_id $taxonId --target_table_name ExternalNASequence --mixedESTs --target_db_rel_id $targetDbRlsId --out $localDataDir/$outputFile --sort 1 --distanceBetweenStarts $maxIntronSize";

  self->runPlugin($test, "DoTS::DotsBuild::Plugin::ClusterByGenome", $args);

}

sub getParamDeclaration {
  my @properties =
    ('parentNcbiTaxonId',
     'outputFile',
     'maxIntronSize',
     'genomeExtDbRlsSpec',
    );
  return @properties;
}

sub getConfigDeclaration {
  my @properties =
    (
     # [name, default, description]
    );
  return @properties;
}

sub restart {
}

sub undo {

}

sub getDocumentation {
}
