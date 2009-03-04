package ApiCommonData::Load::WorkflowSteps::ExtractSageTags;

@ISA = (ApiCommonData::Load::WorkflowSteps::WorkflowStep);

use strict;
use ApiCommonData::Load::WorkflowSteps::WorkflowStep;

sub run {
  my ($self, $test, $undo) = @_;

  my $sageTagExtDbRlsSpec = $self->getParamValue('sageTagExtDbRlsSpec');
  my $outputFile = $self->getParamValue('outputFile');
  my $prependSeq = $self->getParamValue('prependSeq');

  my ($sageTagExtDbName,$sageTagExtDbRlsVer) = $self->getExtDbInfo($test,$sageTagExtDbRlsSpec);

  my $sql = "select s.composite_element_id, '$prependSeq' || s.tag as tag
             from rad.sagetag s,rad.arraydesign a
             where a.name = '$sageTagExtDbName'
             and a.version = $sageTagExtDbRlsVer
             and a.array_design_id = s.array_design_id";

  my $localDataDir = $self->getLocalDataDir();

    if ($test) {
      $self->runCmd(0,"echo test > $localDataDir/$outputFile");
    }

    if ($undo) {
      $self->runCmd(0, "rm -f $localDataDir/$outputFile");
    } else {
      $self->runCmd($test,"gusExtractSequences --outputFile $localDataDir/$outputFile --idSQL \"$sql\" --verbose");
    }
}
  
sub getParamsDeclaration {
  return (
	  'sageTagExtDbRlsSpec',
	  'outputFile',
	  'prependSeq',
	 );
}

sub getConfigDeclaration {
  return (
	  # [name, default, description]
	 );
}


