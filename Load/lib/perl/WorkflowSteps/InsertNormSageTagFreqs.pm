package ApiCommonData::Load::WorkflowSteps::InsertNormSageTagFreqs;

@ISA = (ApiCommonData::Load::WorkflowSteps::WorkflowStep);

use strict;
use ApiCommonData::Load::WorkflowSteps::WorkflowStep;


sub run {
  my ($self, $test, $undo) = @_;

  my $studyName = $self->getParamValue('studyName');

  my $localDataDir = $self->getLocalDataDir();

  $studyName =~ s/\s/_/g;

  $studyName =~ s/[\(\)]//g;

  my $inputDir = $self->getParamValue('inputDir')  ."/" . $studyName;
  
  my $configFile = "configFile";

  my $args = "--configFile '$configFile' --subclass_view RAD::DataTransformationResult";

  if($undo){
    $self->runCmd(0,"rm -rf $configFile");
  }else{

      if ($test) {
	  $self->testInputFile('inputDir', "$localDataDir/$inputDir");
      }
      opendir (DIR,"$localDataDir/$inputDir") || die "Can not open dir $localDataDir/$inputDir";

      my @files = grep { /\w*\.dat/ && -f "$localDataDir/$inputDir/$_" } readdir(DIR); 

      open(F,">$configFile");

      foreach my $dataFile (@files) {

	  my $cfgFile = $dataFile;

	  $cfgFile =~ s/\.dat/\.cfg/;
    
	  print F "$cfgFile\t$dataFile\n";
      }
     
      close F;
      
      $self->runPlugin($test, $undo, "ApiCommonData::Load::Plugin::InsertRadAnalysis", $args);
  }





}

sub getParamDeclaration {
  return (
	  'studyName',
	 );
}

sub getConfigDeclaration {
  return (
	  # [name, default, description]
	 );
}

