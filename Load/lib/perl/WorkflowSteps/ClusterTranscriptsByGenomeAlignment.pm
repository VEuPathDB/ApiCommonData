package ApiCommonData::Load::WorkflowSteps::ClusterTranscriptsByGenomeAlignment;

@ISA = (ApiCommonData::Load::WorkflowSteps::WorkflowStep);

use strict;
use ApiCommonData::Load::WorkflowSteps::WorkflowStep;

sub run {
  my ($self, $test, $undo) = @_;

  my $outputFile = $self->getParamValue('outputFile');
  my $ncbiTaxonId = $self->getParamValue('parentNcbiTaxonId');
  my $genomeExtDbRlsSpec = $self->getParamValue('genomeExtDbRlsSpec');
  my $maxIntronSize = $self->getParamValue('maxIntronSize');

  my $taxonId = $self->getTaxonIdFromNcbiTaxId($test,$ncbiTaxonId);
  my $targetDbRlsId = $self->getExtDbRlsId($test, $genomeExtDbRlsSpec);

  my $localDataDir = $self->getLocalDataDir();

  my $args = "--taxon_id $taxonId --target_table_name ExternalNASequence --mixedESTs --target_db_rel_id $targetDbRlsId --out $localDataDir/$outputFile --sort 1 --distanceBetweenStarts $maxIntronSize";

  if ($test) {
    $self->runCmd(0,"echo test > $localDataDir/$outputFile");
  }

  #plugin does not modify db, only makes output file

  if ($undo) {
      $self->runCmd(0, "rm -f $localDataDir/$outputFile");
  } else {
    $self->runPlugin($test, "DoTS::DotsBuild::Plugin::ClusterByGenome", $args);
  }

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
return (
     # [name, default, description]
       );
}

