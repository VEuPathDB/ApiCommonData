package ApiCommonData::Load::WorkflowSteps::RunGffDump;

@ISA = (ApiCommonData::Load::WorkflowSteps::WorkflowStep);
use strict;
use ApiCommonData::Load::WorkflowSteps::WorkflowStep;


sub run {
  my ($self, $test) = @_;

  # get parameters
  my $downloadSiteDataDir = $self->getParamValue('downloadSiteDataDir');
  my $outputFile = $self->getParamValue('outputFile');
  my $organismName = $self->getParamValue('organismName');
  my $organismFullName = $self->getParamValue('organismFullName');
  my $projectDB = $self->getParamValue('projectDB');

  my $cmd = "gffDump  -model $projectDB  -organism \"$organismFullName\"  -dir $downloadSiteDataDir";
  if ($test) {
      $self->runCmd(0, "echo test > $downloadSiteDataDir/$outputFile");
  } else {
      $self->runCmd($test, $cmd);
  }

}

sub getParamsDeclaration {
  return (
          'outputFile',
          'organismName',
          'organismFullName',
          'projectDB',
	  'downloadSiteDataDir',
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
