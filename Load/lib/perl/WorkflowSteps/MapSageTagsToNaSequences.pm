package ApiCommonData::Load::WorkflowSteps::MapSageTagsToNaSequences;

@ISA = (ApiCommonData::Load::WorkflowSteps::WorkflowStep);
use strict;
use ApiCommonData::Load::WorkflowSteps::WorkflowStep;

sub run {
  my ($self, $test, $undo) = @_;

  # get parameters
  my $genomicSeqsFile = $self->getParamValue('genomicSeqsFile');
  my $sageTagFile = $self->getParamValue('sageTagFile');
  my $outputFile = $self->getParamValue('outputFile');

  my $localDataDir = $self->getLocalDataDir();

  my $cmd = "tagToSeq.pl $genomicSeqsFile $sageTagFile 2>> $outputFile";
  if ($test) {
    $self->testInputFile('genomicSeqsFile', "$localDataDir/$genomicSeqsFile");
    $self->testInputFile('sageTagFile', "$localDataDir/$sageTagFile");
    $self->runCmd(0, "cat test > $localDataDir/$outputFile");
  }

  if ($undo) {
    $self->runCmd(0, "rm -f $localDataDir/$outputFile");
  } else {
    $self->runCmd($test, $cmd);
  }

}

sub getParamsDeclaration {
  return (
          'genomicSeqsFile',
          'outputFile',
          'sageTagFile',
         );
}

sub getConfigDeclaration {
  return (
         # [name, default, description]
         # ['', '', ''],
         );
}


