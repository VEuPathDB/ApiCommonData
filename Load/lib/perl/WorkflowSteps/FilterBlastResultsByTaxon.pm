package ApiCommonData::Load::WorkflowSteps::FilterBlastResultsByTaxon;

@ISA = (ApiCommonData::Load::WorkflowSteps::WorkflowStep);

use strict;
use ApiCommonData::Load::WorkflowSteps::WorkflowStep;


sub run {
  my ($self, $test) = @_;

  my $taxonList = $self->getParamValue('taxonHierarchy');
  my $inputFile = $self->getParamValue('inputFile');
  my $unfilteredOutputFile = $self->getParamValue('unfilteredOutputFile');
  my $filteredOutputFile = $self->getParamValue('filteredOutputFile');
  my $gi2taxidFileRelativeToDownloadDir = $self->getParamValue('gi2taxidFileRelativeToDownloadDir');

  my $downloadDir = $self->getGlobalConfig('downloadDir');

  $taxonList =~ s/\"//g if $taxonList;

  my $gi2taxidFile = "$downloadDir/$gi2taxidFileRelativeToDownloadDir";

  my $localDataDir = $self->getLocalDataDir();

  $self->runCmd(0,"cp $localDataDir/$inputFile $localDataDir/$unfilteredOutputFile");

  my $cmd = "splitAndFilterBLASTX --taxon \"$taxonList\" --gi2taxidFile $gi2taxidFile --inputFile $localDataDir/$inputFile --outputFile $localDataDir/$filteredOutputFile";

  if ($test) {
    $self->testInputFile('inputFile', "$localDataDir/$inputFile");
    $self->runCmd(0,"echo test > $localDataDir/$filteredOutputFile");
  }
  $self->runCmd($test,$cmd);
}

sub getParamsDeclaration {
  return (
	  'taxonHierarchy',
	  'gi2taxidFileRelativeToDownloadDir',
	  'inputFile',
	  'unfilteredOutputFile',
	  'filteredOutputFile',
	 );
}

sub getConfigDeclaration {
  return (
	  # [name, default, description]
	  ['downloadDir', "", ""],
	 );
}

sub getDocumentation {
}

sub restart {
}

sub undo {

}

