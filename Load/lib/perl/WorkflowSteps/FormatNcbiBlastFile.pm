 package ApiCommonData::Load::WorkflowSteps::FormatNcbiBlastFile;

@ISA = (ApiCommonData::Load::WorkflowSteps::WorkflowStep);

use strict;
use ApiCommonData::Load::WorkflowSteps::WorkflowStep;
use File::Basename;

sub run {
  my ($self, $test, $undo) = @_;

  my $inputFile = $self->getParamValue('inputFile');
  my $outputBlastDbDir = $self->getParamValue('outputBlastDbDir');
  my $formatterArgs = $self->getParamValue('formatterArgs');


  my $ncbiBlastPath = $self->getConfig('ncbiBlastPath');

  my $localDataDir = $self->getLocalDataDir();

  my ($filename, $relativeDir) = fileparse($inputFile);

  my $fileToFormat = "$localDataDir/$inputFile";

  if ($outputBlastDbDir ne $relativeDir) {
    $fileToFormat = "$localDataDir/$outputBlastDbDir/$filename";
  }

  if ($undo) {
    if ($outputBlastDbDir ne $relativeDir) {
      $self->runCmd(0,"rm -f $fileToFormat");
    }
    $self->runCmd(0, "rm -f ${fileToFormat}.p*");
  } else {
      if ($outputBlastDbDir ne $relativeDir) {
	  $self->testInputFile('inputFile', "$localDataDir/$inputFile");
	  $self->runCmd(0,"ln -s $localDataDir/$inputFile $fileToFormat");
      }
      if ($test) {
	  $self->runCmd(0,"echo test > $localDataDir/$outputBlastDbDir/format.pin");
      }else {
	  $self->runCmd($test,"$ncbiBlastPath/formatdb -i $fileToFormat -p $formatterArgs");
      }
  }
}

sub getParamsDeclaration {
  return ('inputFile',
	  'formatterArgs'
	 );
}

sub getConfigDeclaration {
  return (
	  # [name, default, description]
	  ['ncbiBlastPath', "", ""],
	 );
}


