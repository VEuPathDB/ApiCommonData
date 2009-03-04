package ApiCommonData::Load::WorkflowSteps::InsertNormSageTagFreqs;

@ISA = (ApiCommonData::Load::WorkflowSteps::WorkflowStep);

use strict;
use ApiCommonData::Load::WorkflowSteps::WorkflowStep;


sub run {
  my ($self, $test, $undo) = @_;

  my $inputDir = $self->getParamValue('inputDir');

  my $localDataDir = $self->getLocalDataDir();

  opendir (DIR,"$localDataDir/$inputDir");

  my @files = grep { /\w*\.dat/ && -f "$localDataDir/$inputDir/$_" } readdir(DIR); 

  foreach my $dataFile (@files) {

    my $cfgFile = $dataFile;

    $cfgFile =~ s/\.dat/\.cfg/;

    my $args = "--cfg_file '$localDataDir/$inputDir/$cfgFile' --data_file '$localDataDir/$inputDir/$dataFile' --subclass_view RAD::DataTransformationResult";

  $self->runPlugin($test, $undo, "ApiCommonData::Load::Plugin::CreateSageTagNormalizationFiles", $args);

  }
   

  if ($test) {
    $self->testInputFile('inputDir', "$localDataDir/$inputDir");
  }



}

sub getParamDeclaration {
  return (
	  'inputDir',
	 );
}

sub getConfigDeclaration {
  return (
	  # [name, default, description]
	 );
}

