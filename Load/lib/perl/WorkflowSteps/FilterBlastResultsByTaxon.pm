package ApiCommonData::Load::WorkflowSteps::FilterBlastResultsByTaxon;

@ISA = (GUS::Workflow::WorkflowStepInvoker);

use strict;
use GUS::Workflow::WorkflowStepInvoker;


sub run {
  my ($self, $test) = @_;

  my $taxonList = $self->getParamValue('taxonHierarchy');

  $taxonList =~ s/\"//g;

  my $gi2taxidFileRelativeToDownloadDir = $self->getExtDbRlsId($self->getParamValue('gi2taxidFileRelativeToDownloadDir'));

  my $gi2taxidFile = "$self->getGlobalConfig('downloadDir')/${gi2taxidFileRelativeToDownloadDir}";
 
  my $inputFile = $self->getParamValue('inputFile');

  my $unfilteredOutputFile = $self->getParamValue('unfilteredOutputFile');

  my $filteredOutputFile = $self->getParamValue('filteredOutputFile');

  $self->runCmd(0,"mv $inputFile $unfilteredOutputFile");

  my $cmd = "splitAndFilterBLASTX --taxon \"$taxonList\" --gi2taxidFile $gi2taxidFile --inputFile $unfilteredOutputFile --outputFile $filteredOutputFile";

  if ($test) {

      $self->runCmd(0,"test > $filteredOutputFile");

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
     ['taxonHierarchy', "", ""],
     ['gi2taxidFileRelativeToDownloadDir', "", ""],
     ['inputFile', "", ""],
    );
  return @properties;
}

sub getDocumentation {
}
