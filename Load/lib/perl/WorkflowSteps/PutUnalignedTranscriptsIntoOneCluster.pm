package ApiCommonData::Load::WorkflowSteps::PutUnalignedTranscriptsIntoOneCluster;

@ISA = (ApiCommonData::Load::WorkflowSteps::WorkflowStep);

use strict;
use ApiCommonData::Load::WorkflowSteps::WorkflowStep;

sub run {
  my ($self, $test, $undo) = @_;

  my $allClustersOutputFile = $self->getParamValue('allClustersOutputFile');
  my $alignedClustersFile = $self->getParamValue('alignedClustersFile');
  my $repeatMaskErrFile = $self->getParamValue('repeatMaskErrFile');
  my $useTaxonHierarchy = $self->getParamValue('useTaxonHierarchy');
  my $parentNcbiTaxonId = $self->getParamValue('parentNcbiTaxonId');
  my $targetNcbiTaxId = $self->getParamValue('targetNcbiTaxId');

  my $localDataDir = $self->getLocalDataDir();
  
  my $taxonId = $self->getTaxonIdFromNcbiTaxId($test,$parentNcbiTaxonId);
  my $taxonIdList = $self->getTaxonIdList($test, $taxonId, $useTaxonHierarchy);
  my $targetTaxonId = $self->getTaxonIdFromNcbiTaxId($test,$targetNcbiTaxId);

  my $cmd = "getUnalignedAssemSeqIds --alignedClustersFile $localDataDir/$alignedClustersFile --outputFile $localDataDir/$allClustersOutputFile --repeatMaskErrFile $localDataDir/$repeatMaskErrFile --taxonIdList $taxonIdList --targetTaxonId $targetTaxonId";

  if ($test) {
    $self->testInputFile('alignedClustersFile', "$localDataDir/$alignedClustersFile");
    $self->testInputFile('repeatMaskErrFile', "$localDataDir/$repeatMaskErrFile");
    $self->runCmd(0, "echo test > $localDataDir/$allClustersOutputFile");
  }
  $self->runCmd($test, $cmd);
}


sub getParamsDeclaration {
  return (
     'alignedClustersFile',
     'allClustersOutputFile',
     'repeatMaskErrFile',
    );
}

sub getConfigDeclaration {
  return (
	  # [name, default, description]
	 );
}


