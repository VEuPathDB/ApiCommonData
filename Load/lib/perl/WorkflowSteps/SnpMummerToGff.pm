package ApiCommonData::Load::WorkflowSteps::SnpMummerToGff;

@ISA = (ApiCommonData::Load::WorkflowSteps::WorkflowStep);
use strict;
use ApiCommonData::Load::WorkflowSteps::WorkflowStep;

sub run {
  my ($self, $test, $undo) = @_;

  # get parameters
  my $inputFile = $self->getParamValue('inputFile');
  my $gffFile = $self->getParamValue('gffFile');
  my $outputFile = $self->getParamValue('outputFile');
  my $strain = $self->getParamValue('strain');

  my $localDataDir = $self->getLocalDataDir();

  my $cmd = "snpFastaMUMmerGff --gff_file $localDataDir/$gffFile --mummer_file $localDataDir/$inputFile --output_file $localDataDir/$outputFile --reference_strain $strain --gff_format gff2 --skip_multiple_matches --error_log step.err";
  if ($test) {
    $self->testInputFile('inputFile', "$localDataDir/$inputFile");
    $self->testInputFile('gffFile', "$localDataDir/$gffFile");
    $self->runCmd(0, "echo test > $localDataDir/$outputFile");
  }

  if ($undo) {
    $self->runCmd(0, "rm -f $localDataDir/$outputFile");
  } else {
    $self->runCmd($test, $cmd);
  }

}

sub getParamsDeclaration {
  return (
          'inputFile',
          'gffFile',
          'outputFile',
          'strain',
         );
}

sub getConfigDeclaration {
  return (
         # [name, default, description]
         # ['', '', ''],
         );
}


