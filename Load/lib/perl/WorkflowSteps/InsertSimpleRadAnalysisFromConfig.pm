package ApiCommonData::Load::WorkflowSteps::InsertSimpleRadAnalysisFromConfig;

@ISA = (ApiCommonData::Load::WorkflowSteps::WorkflowStep);

use strict;
use ApiCommonData::Load::WorkflowSteps::WorkflowStep;


sub run {
  my ($self, $test, $undo) = @_;

  my $analysisWorkingDir = $self->getParamValue('analysisWorkingDir');

  my $configFile = "$analysisWorkingDir/config.txt";
      
  my $args = "--inputDir $analysisWorkingDir --configFile $configFile --analysisResultView DataTransformationResult  --naFeatureView ArrayElementFeature";

  if ($test) {
    $self->testInputFile('analysisWorkingDir', "$analysisWorkingDir");
  }

  $self->runPlugin($test, $undo, "ApiCommonData::Load::Plugin::InsertAnalysisResult", $args);

}

sub getParamDeclaration {
  return (
	  'analysisWorkingDir',
	 );
}

sub getConfigDeclaration {
  return (
	  # [name, default, description]
	 );
}

