package ApiCommonData::Load::WorkflowSteps::ExtractAssemblySeqs;

@ISA = (ApiCommonData::Load::WorkflowSteps::WorkflowStep);

use strict;
use ApiCommonData::Load::WorkflowSteps::WorkflowStep;

sub run {
  my ($self, $test, $undo) = @_;

  my $parentNcbiTaxonId = $self->getParamValue('parentNcbiTaxonId');
  my $useTaxonHierarchy = $self->getParamValue('useTaxonHierarchy');
  my $outputFile = $self->getParamValue('outputFile');

  my $taxonId = $self->getTaxonIdFromNcbiTaxId($test,$parentNcbiTaxonId);
  my $taxonIdList = $self->getTaxonIdList($test, $taxonId, $useTaxonHierarchy);

  my $localDataDir = $self->getLocalDataDir();

  my $args = "--taxon_id_list '$taxonIdList' --outputfile $localDataDir/$outputFile --extractonly";

  if ($test) {
      $self->runCmd(0,"echo test > $localDataDir/$outputFile");
  }

  if ($undo) {
    $self->runCmd(0, "rm -f $localDataDir/$outputFile");
  } else {
    $self->runPlugin($test, $undo, "DoTS::DotsBuild::Plugin::ExtractAndBlockAssemblySequences", $args);
  }

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


