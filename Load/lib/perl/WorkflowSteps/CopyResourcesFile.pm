package ApiCommonData::Load::WorkflowSteps::CopyResourcesFile;

@ISA = (ApiCommonData::Load::WorkflowSteps::WorkflowStep);
use strict;
use ApiCommonData::Load::WorkflowSteps::WorkflowStep;

sub run {
  my ($self, $test, $undo) = @_;

  # get parameters
  my $resourcesFile = $self->getParamValue('resourcesFile');
  my $toFile = $self->getParamValue('toFile');

  # get global properties
  my $downloadDir = $self->getGlobalConfig('downloadDir');

  my $localDataDir = $self->getLocalDataDir();

  $self->runCmd(0, "gunzip $downloadDir/$resourcesFile.gz") if (-e "$downloadDir/$resourcesFile.gz");

  if ($test) {
      if ($resourcesFile =~/\*/){#if file name contains wild character 
	  my($directory, $filename) = $resourcesFile =~ m/(.*\/)(.*)$/;
	  $self->testInputFile('resourcesFile',"$filename","$downloadDir/$directory");	  
      }else{
	  $self->testInputFile('resourcesFile', "$downloadDir/$resourcesFile");
      }
      $self->runCmd(0,"echo test > $localDataDir/$toFile");
  }

  if ($undo) {
      $self->runCmd(0, "rm -f $localDataDir/$toFile");
  } else {
      $self->runCmd($test, "cp $downloadDir/$resourcesFile $localDataDir/$toFile");
  }
}

sub getParamsDeclaration {
  return (
          'resourcesFile',
          'toFile',
         );
}

sub getConfigDeclaration {
  return (
         # [name, default, description]
         # ['', '', ''],
         );
}


