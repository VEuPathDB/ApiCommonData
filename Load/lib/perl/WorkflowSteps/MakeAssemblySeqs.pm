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

  my $taxonId = $self->getTaxonId($self->getParamValue('parentNcbiTaxonId'));

  my $taxonIdList = $self->getTaxonIdList($taxonId,$self->getParamValue('useTaxonHierarchy'));
  
  my $sql = $self->getParamValue('predictedTranscriptsSql');

  my $repeatFile = $self->getConfig('vectorFile');

  my $phrapDir = $self->getConfig('phrapDir');

  my $args = "--taxon_id_list '$taxonIdList' --repeatFile $repeatFile --phrapDir $phrapDir";

  $args .= " --idSQL \"$sql\"" if($sql);

  self->runPlugin( "DoTS::DotsBuild::Plugin::MakeAssemblySequences", $args);

}


sub restart {
}

sub undo {

}

sub getConfigDeclaration {
  my @properties = 
    (
     # [name, default, description]
     ['vectorFile', "", ""],
     ['phrapDir', "", ""],
    );
  return @properties;
}

sub getParamDeclaration {
  my @properties = 
    (
     # [name, default, description]
     ['parentNcbiTaxonId'],
     ['useTaxonHierarchy'],
     ['predictedTranscriptsSql'],
    );
  return @properties;
}

sub getDocumentation {
}
