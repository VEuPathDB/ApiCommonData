package ApiCommonData::Load::WorkflowSteps::SnpGffToFasta;

@ISA = (ApiCommonData::Load::WorkflowSteps::WorkflowStep);
use strict;
use ApiCommonData::Load::WorkflowSteps::WorkflowStep;

sub run {
  my ($self, $test, $undo) = @_;

  # get parameters
  my $inputFile = $self->getParamValue('inputFile');
  my $outputFile = $self->getParamValue('outputFile');
  my $strain = $self->getParamValue('strain');

  my $localDataDir = $self->getLocalDataDir();

  my $cmd = "snpFastaMUMmerGff --gff_file $localDataDir/$inputFile --reference_strain $strain --output_file $localDataDir/$outputFile --make_fasta_file_only --gff_format gff2";

  if ($test) {
    $self->testInputFile('inputFile', "$localDataDir/$inputFile");
    $self->runCmd(0, "cat test > $localDataDir/$outputFile");
  }

  if ($undo) {
    $self->runCmd(0, "rm -f $localDataDir/*${outputFile}");
  } else {
    $self->runCmd($test, $cmd);
  }

}

sub getParamsDeclaration {
  return (
          'inputFile',
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


