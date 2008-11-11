package ApiCommonData::Load::WorkflowSteps::ExtractAnnotatedProteinsBySpecies;

@ISA = (ApiCommonData::Load::WorkflowSteps::WorkflowStep);

use strict;
use ApiCommonData::Load::WorkflowSteps::WorkflowStep;

sub run {
  my ($self, $test) = @_;

  my $genomeExtDbRlsSpec = $self->getParamValue('genomeExtDbRlsSpec');
  my $ncbiTaxonId = $self->getParamValue('ncbiTaxonId');
  my $outputFile = $self->getParamValue('outputFile');

  my $genomeDbRlsId = $self->getExtDbRlsId($genomeExtDbRlsSpec);
  my $taxonId = $self->getTaxonId($ncbiTaxonId);

  my $sql = "SELECT tx.source_id,g.product,
                    'length='||length(t.sequence),t.sequence
               FROM dots.NASequence x,
                    dots.transcript tx,
                    dots.nafeature f,
                    dots.genefeature g,
                    dots.translatedaafeature a,
                    dots.translatedaasequence t
              WHERE x.taxon_id = $taxonId
                AND x.external_database_release_id = $genomeDbRlsId
                AND tx.parent_id = g.na_feature_id
                AND x.na_sequence_id = f.na_sequence_id 
                AND f.na_feature_id = a.na_feature_id
                AND a.aa_sequence_id = t.aa_sequence_id
                AND a.na_feature_id = tx.na_feature_id";

  my $cmd = "gusExtractSequences --outputFile $outputFile --idSQL \"$sql\" --verbose";

  if ($test) {

      $self->runCmd(0,"echo test > $outputFile");

  } else {

      $self->runCmd($test,$cmd);

  }
}

sub getParamsDeclaration {
  return ('genomeExtDbRlsSpec',
	  'ncbiTaxonId',
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

