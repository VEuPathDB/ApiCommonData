package ApiCommonData::Load::WorkflowSteps::RunfullRecordDump;

@ISA = (ApiCommonData::Load::WorkflowSteps::WorkflowStep);
use strict;
use ApiCommonData::Load::WorkflowSteps::WorkflowStep;


sub run {
  my ($self, $test, $undo) = @_;

  # get parameters
  my $downloadSiteDataDir = $self->getParamValue('downloadSiteDataDir');
  my $organismFullName = $self->getParamValue('organismFullName');
  my $projectDB = $self->getParamValue('projectDB');
  my $recordType = $self->getParamValue('recordType');
  my $outputGeneFile = $self->getParamValue('outputGeneFile');
  my $outputSeqFile = $self->getParamValue('outputSeqFile');

  my $apiSiteFilesDir = $self->getGlobalConfig('apiSiteFilesDir');

  my $cmd ="fullRecordDump  -model $projectDB  -organism \"$organismFullName\"  -type \"$recordType\"  -dir $apiSiteFilesDir/$downloadSiteDataDir";

  if ($test) {
    $self->runCmd(0, "echo test > $apiSiteFilesDir/$downloadSiteDataDir/$outputGeneFile");
    $self->runCmd(0, "echo test > $apiSiteFilesDir/$downloadSiteDataDir/$outputSeqFile");
  }elsif($undo) {
    $self->runCmd(0, "rm -f $apiSiteFilesDir/$downloadSiteDataDir/$outputGeneFile");
    $self->runCmd(0, "rm -f $apiSiteFilesDir/$downloadSiteDataDir/$outputSeqFile");
  }
  else{
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


