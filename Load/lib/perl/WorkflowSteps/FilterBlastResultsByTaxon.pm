package ApiCommonData::Load::WorkflowSteps::FilterBlastResultsByTaxon;

@ISA = (GUS::Workflow::WorkflowStepInvoker);

use strict;
use GUS::Workflow::WorkflowStepInvoker;


sub run {
  my ($self, $test) = @_;

  my $taxonList = $self->getParamValue('taxonHierarchy');

  $taxonList =~ s/\"//g if $taxonList;

  my $gi2taxidFileRelativeToDownloadDir = $self->getParamValue('gi2taxidFileRelativeToDownloadDir');

  my $gi2taxidFile = "$self->getGlobalConfig('downloadDir')/${gi2taxidFileRelativeToDownloadDir}" if $gi2taxidFileRelativeToDownloadDir;
 
  $self->runCmd(0,"gunzip -f ${gi2taxidFile}.gz") if (-e "${gi2taxidFile}.gz");

  my $inputFile = $self->getParamValue('inputFile');

  my $unfilteredOutputFile = $self->getParamValue('unfilteredOutputFile');

  my $filteredOutputFile = $self->getParamValue('filteredOutputFile');

  $self->runCmd(0,"mv $inputFile $unfilteredOutputFile") if $inputFile;

  my $cmd = "splitAndFilterBLASTX --taxon \"$taxonList\" --gi2taxidFile $gi2taxidFile --inputFile $unfilteredOutputFile --outputFile $filteredOutputFile";

  if ($test) {

      $self->runCmd(0,"echo hello > $filteredOutputFile");

  } else {

      $self->runCmd($test,$cmd);

  }

}

sub restart {
}

sub undo {

}

sub getConfigDeclaration {
  my @properties = 
    (
     # [name, default, description]
     ['downloadDir', "", ""],
    );
  return @properties;
}

sub getConfigDeclaration {
  my @properties = 
    (
     ['taxonHierarchy'],
     ['gi2taxidFileRelativeToDownloadDir'],
     ['inputFile'],
     ['unfilteredOutputFile'],
     ['filteredOutputFile'],
    );
  return @properties;
}

sub getDocumentation {
}
