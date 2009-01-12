package ApiCommonData::Load::WorkflowSteps::RunfullRecordDump;

@ISA = (ApiCommonData::Load::WorkflowSteps::WorkflowStep);
use strict;
use ApiCommonData::Load::WorkflowSteps::WorkflowStep;


sub run {
  my ($self, $test) = @_;

  # get parameters
  my $downloadSiteDataDir = $self->getParamValue('downloadSiteDataDir');
  my $organismFullName = $self->getParamValue('organismFullName');
  my $projectDB = $self->getParamValue('projectDB');
  my $recordType = $self->getParamValue('recordType');
  my $outputGeneFile = $self->getParamValue('outputGeneFile');
  my $outputSeqFile = $self->getParamValue('outputSeqFile');
  my $cmd ="fullRecordDump  -model $projectDB  -organism \"$organismFullName\"  -type \"$recordType\"  -dir $downloadSiteDataDir";
  
  if ($test) {
      $self->runCmd(0, "echo test > $downloadSiteDataDir/$outputGeneFile");
      $self->runCmd(0, "echo test > $downloadSiteDataDir/$outputSeqFile");
  }else{
  
      $self->runCmd($test, $cmd);
  }

}

sub getParamsDeclaration {
  return (
          'downloadSiteDataDir',
          'recordType',
          'organismFullName',
          'projectDB',
	  'outputGeneFile',
	  'outputSeqFile',
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
