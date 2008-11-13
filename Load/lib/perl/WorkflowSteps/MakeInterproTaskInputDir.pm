package ApiCommonData::Load::WorkflowSteps::MakeInterproTaskInputDir;

@ISA = (ApiCommonData::Load::WorkflowSteps::WorkflowStep);
use strict;
use ApiCommonData::Load::WorkflowSteps::WorkflowStep;

TEMPLATE
sub run {
  my ($self, $test) = @_;

  # get parameters
  my $taskInputDir = $self->getParamValue('taskInputDir');
  my $proteinsFile = $self->getParamValue('proteinsFile');

  # get properties
  my $taskSize = $self->getGlobalConfig('taskSize');

  # make controller.prop file
  $self->makeClusterControllerPropFile($taskInputDir, 2, $taskSize,
				       "DJob::DistribJobTasks::BlastMatrixTask");

  # make task.prop file
  my $computeClusterDataDir = $self->getComputeClusterDataDir();
  my $localDataDir = $self->getLocalDataDir();

  my $dbFilePath = "$computeClusterDataDir/$subjectFile";
  my $inputFilePath = "$computeClusterDataDir/$queryFile";
  my $ccBlastParamsFile = "$computeClusterDataDir/$taskInputDir/blastParams";
  my $vendorString = $vendor? "blastVendor=$vendor" : "";

  my $taskPropFile = "$localDataDir/$taskInputDir/task.prop";
  open(F, $taskPropFile) || die "Can't open task prop file '$taskPropFile' for writing";

  print F
"blastBinDir=$blastBinPathCluster
dbFilePath=$dbFilePath
inputFilePath=$inputFilePath
dbType=$dbType
regex='$idRegex'
blastProgram=$blastType
blastParamsFile=$ccBlastParamsFile
$vendorString
";
  close(F);

  # make blastParams file
  my $localBlastParamsFile = "$localDataDir/$taskInputDir/blastParams";
  open(F, $localBlastParamsFile) || die "Can't open blast params file '$localBlastParamsFile' for writing";;
  print F "$blastArgs\n";
  close(F);
  #&runCmd("chmod -R g+w $localDataDir/similarity/$queryName-$subjectName");
}

sub getParamsDeclaration {
  return (
          'taskInputDir',
          'proteinsFile',
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
