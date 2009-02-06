package ApiCommonData::Load::WorkflowSteps::FormatDownloadFile;

@ISA = (ApiCommonData::Load::WorkflowSteps::WorkflowStep);
use strict;
use ApiCommonData::Load::WorkflowSteps::WorkflowStep;

sub run {
  my ($self, $test, $undo) = @_;

  # get parameters
  my $inputFile = $self->getParamValue('inputFile');
  my $outputDir = $self->getParamValue('outputDir');
  my $args = $self->getParamValue('args');
  my $formattedFileName = $self->getParamValue('formattedFileName');
  
  my $apiSiteFilesDir = $self->getGlobalConfig('apiSiteFilesDir');
  my $blastPath = $self->getConfig('wuBlastPath');

  my $cmd = "$blastPath/xdformat $args -o $apiSiteFilesDir/$outputDir/$formattedFileName $apiSiteFilesDir/$inputFile";

  
  if($test){

      $self->testInputFile('inputFile', "$apiSiteFilesDir/$inputFile");
      $self->testInputFile('outputDir', "$apiSiteFilesDir/$outputDir");
      $self->runCmd(0, "echo test > $apiSiteFilesDir/$outputDir/$formattedFileName.test");

  }elsif($undo) {

    $self->runCmd(0, "rm -f $apiSiteFilesDir/$outputDir/${formattedFileName}.x*");
  }
  else{

    if($args =~/\-p/){

      my $tempFile = "$apiSiteFilesDir/$inputFile.temp";

      $self->runCmd($test,"cat $apiSiteFilesDir/$inputFile | perl -pe 'unless (/^>/){s/J/X/g;}' > $tempFile");

      $self->runCmd($test,"$blastPath/xdformat $args -o $apiSiteFilesDir/$outputDir/$formattedFileName $tempFile");

      $self->runCmd($test,"rm -fr $tempFile");

    }else {
      $self->runCmd($test, $cmd);
    }
  }

}

sub getParamsDeclaration {
  return (
          'inputFile',
          'outputDir',
          'args',
          'formattedFileName',
         );
}

sub getConfigDeclaration {
  return (
         # [name, default, description]
         # ['', '', ''],
         );
}

