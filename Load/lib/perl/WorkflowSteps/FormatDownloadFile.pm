package ApiCommonData::Load::WorkflowSteps::FormatDownloadFile;

@ISA = (ApiCommonData::Load::WorkflowSteps::WorkflowStep);
use strict;
use ApiCommonData::Load::WorkflowSteps::WorkflowStep;

sub run {
  my ($self, $test) = @_;

  # get parameters
  my $inputFile = $self->getParamValue('inputFile');
  my $outputDir = $self->getParamValue('outputDir');
  my $args = $self->getParamValue('args');
  my $formattedFileName = $self->getParamValue('formattedFileName');
  
  my $apiSiteFilesDir = $self->getGlobalConfig('apiSiteFilesDir');
  my $blastPath = $self->getGlobalConfig('wuBlastPath');

  my $cmd = "$blastPath/xdformat $args -o $apiSiteFilesDir/$outputDir/$formattedFileName $inputFile";

  
  if($test){

      $self->runCmd(0, "echo test > $apiSiteFilesDir/$outputDir/$formattedFileName.test");

  }else{
      
      if($args =~/\-p/){

	  my $tempFile = "$inputFile.temp";

	  $self->runCmd($test,"cat $inputFile | perl -pe 'unless (/^>/){s/J/X/g;}' > $tempFile");

	  $self->runCmd($test,"$blastPath/xdformat $args -o $outputDir/$formattedFileName $tempFile");

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

sub restart {
}

sub undo {

}

sub getDocumentation {
}
