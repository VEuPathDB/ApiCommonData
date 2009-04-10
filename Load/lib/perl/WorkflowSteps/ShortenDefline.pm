package ApiCommonData::Load::WorkflowSteps::ShortenDefline;

@ISA = (ApiCommonData::Load::WorkflowSteps::WorkflowStep);
use strict;
use ApiCommonData::Load::WorkflowSteps::WorkflowStep;

sub run {
  my ($self, $test, $undo) = @_;

  # get parameters
  my $inputFile = $self->getParamValue('inputFile');
  my $outputFile = $self->getParamValue('outputFile');
  my $mappingFileRelativeToDownloadDir = $self->getParamValue('mappingFileRelativeToDownloadDir');

  my $downloadDir = $self->getGlobalConfig('downloadDir');

  my $mappingFile = "$downloadDir/$mappingFileRelativeToDownloadDir";

  my $localDataDir = $self->getLocalDataDir();

  if ($undo) {
    $self->runCmd(0, "rm -f $localDataDir/$outputFile");
  }else {
      if ($test) {
	  $self->testInputFile('inputFile', "$localDataDir/$inputFile");
	  $self->runCmd(0, "echo test > $localDataDir/$outputFile");
      }else{
	  $self->runCmd($test, "shortenDefLine --inputFile $localDataDir/$inputFile --outputFile $localDataDir/$outputFile --taxonIdMappingFile '$mappingFile'");
      }
  }
}

sub getParamsDeclaration {
  return (
          'inputFile',
          'outputFile',
         );
}

sub getConfigDeclaration {
  return (
         # [name, default, description]
         # ['', '', ''],
         );
}


