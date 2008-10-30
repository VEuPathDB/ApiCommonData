package ApiCommonData::Load::WorkflowSteps::clusterTranscriptsByGenomeAlignment;

@ISA = (GUS::Workflow::WorkflowStepInvoker);

use strict;
use GUS::Workflow::WorkflowStepInvoker;


## to do
## API $self->getTaxonId($ncbiTaxId) 

sub run {
  my ($self, $test) = @_;

  my $outputFile = $self->getParamValue('outputFile');

  my $taxonId = $self->getTaxonId($self->getParamValue('parentNcbiTaxonId'));

  my $targetDbRlsId = $self->getExtDbRlsId( $self->getParamValue('genomeExtDbRlsSpec');

  my $targetTableName = $self->getParamValue('targetTableName');

  my $distanceBetweenStarts = $self->getParamValue('distanceBetweenStarts');

  my $args = "--taxon_id $taxonId --target_table_name  $targetTableName --mixedESTs "
	. "--target_db_rel_id $targetDbRlsId --out $outputFile --sort 1 --distanceBetweenStarts $distanceBetweenStarts";

  self->runPlugin( "DoTS::DotsBuild::Plugin::ClusterByGenome", $args);

}


sub restart {
}

sub undo {

}

sub getConfigDeclaration {
  my @properties = 
    (
     # [name, default, description]
     ['parentNcbiTaxonId', "", ""],
     ['outputFile', "", ""],
     ['distanceBetweenStarts', "", ""],
    );
  return @properties;
}

sub getDocumentation {
}
