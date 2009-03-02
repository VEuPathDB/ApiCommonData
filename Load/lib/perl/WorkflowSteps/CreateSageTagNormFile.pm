package ApiCommonData::Load::WorkflowSteps::CreateSageTagNormFile;

@ISA = (ApiCommonData::Load::WorkflowSteps::WorkflowStep);

use strict;
use ApiCommonData::Load::WorkflowSteps::WorkflowStep;


sub run {
  my ($self, $test, $undo) = @_;

  my $studyName = $self->getParamValue('studyName');

  my $paramValue = $self->getParamValue('paramValue');

  my $outputDir = $self->getParamValue('outputDir');

  my $localDataDir = $self->getLocalDataDir();
      
  my $args = "--paramValue $paramValue --studyName '$studyName' --fileDir $localDataDir/$outputDir";

  if ($test) {
    $self->runCmd(0,"echo test > $localDataDir/$outputDir/test.out");
  }

  $self->runPlugin($test, $undo, "ApiCommonData::Load::Plugin::CreateSageTagNormalizationFiles", $args);

}

sub getParamDeclaration {
  return (
	  'inputFile',
	 );
}

sub getConfigDeclaration {
  return (
	  # [name, default, description]
	 );
}

