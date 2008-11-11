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

  $self->runCmd(0,"cp $inputFile $unfilteredOutputFile");

  my $cmd = "splitAndFilterBLASTX --taxon \"$taxonList\" --gi2taxidFile $gi2taxidFile --inputFile $inputFile --outputFile $filteredOutputFile";

  if ($test) {
      $self->runCmd(0,"echo test > $filteredOutputFile");
  } else {
      $self->runCmd($test,$cmd);
  }
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

