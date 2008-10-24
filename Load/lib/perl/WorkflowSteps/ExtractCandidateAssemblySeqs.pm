package ApiCommonData::Load::WorkflowSteps::ExtractCandidateAssemblySeqs;

@ISA = (GUS::Workflow::WorkflowStepInvoker);

use strict;
use GUS::Workflow::WorkflowStepInvoker;


## to do
## API $self->getTaxonId($ncbiTaxId) 
## API $self->getTaxonIdList($taxonId,$taxonHierarchy)
## define genomeDataDir

sub run {
  my ($self, $test) = @_;

  my $taxonId = $self->getTaxonId($self->getParamValue('parentNcbiTaxonId'));

  my $taxonIdList = $self->getTaxonIdList(taxonId,$self->getParamValue('useTaxonHierarchy'));
  
  my $outputFile = $self->getParamValue('outputFile');

  my $args = "--taxon_id_list '$taxonIdList' --outputfile $outputFile --extractonly";

  $args .= " --idSQL \"$sql\"" if($sql);

  self->runPlugin( "DoTS::DotsBuild::Plugin::ExtractAndBlockAssemblySequences", $args);

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
     ['useTaxonHierarchy', "", ""],
     ['outputFile', "", ""],
    );
  return @properties;
}

sub getDocumentation {
}
