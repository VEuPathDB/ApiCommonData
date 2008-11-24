package ApiCommonData::Load::WorkflowSteps::MakeBlastTaskInputDir;

@ISA = (ApiCommonData::Load::WorkflowSteps::WorkflowStep);

use strict;
use ApiCommonData::Load::WorkflowSteps::WorkflowStep;

sub run {
  my ($self, $test) = @_;

  # get parameter values
  my $taskInputDir = $self->getParamValue("taskInputDir");
  my $queryFile = $self->getParamValue("queryFile");
  my $subjectFile = $self->getParamValue("subjectFile");
  my $blastArgs = $self->getParamValue("blastArgs");
  my $idRegex = $self->getParamValue("idRegex");
  my $blastType = $self->getParamValue("blastType");
  my $vendor = $self->getParamValue("vendor");

  my $taskSize = $self->getConfig('taskSize');
  my $wuBlastBinPathCluster = $self->getConfig('wuBlastBinPathCluster');
  my $ncbiBlastBinPathCluster = $self->getConfig('ncbiBlastBinPathCluster');

  my $blastBinPathCluster = ($vendor eq 'ncbi')?
    $ncbiBlastBinPathCluster : $wuBlastBinPathCluster;

  my $dbType = ($blastType =~ m/blastn|tblastx/i) ? 'n' : 'p';

  # make controller.prop file
  $self->makeControllerPropFile($taskInputDir, 2, $taskSize,
				       "DJob::DistribJobTasks::BlastMatrixTask");

  # make task.prop file
  my $computeClusterDataDir = $self->getComputeClusterDataDir();
  my $localDataDir = $self->getLocalDataDir();

  my $ccBlastParamsFile = "$computeClusterDataDir/$taskInputDir/blastParams";
  my $localBlastParamsFile = "$localDataDir/$taskInputDir/blastParams";
  my $vendorString = $vendor? "blastVendor=$vendor" : "";

  my $taskPropFile = "$localDataDir/$taskInputDir/task.prop";
  open(F, $taskPropFile) || die "Can't open task prop file '$taskPropFile' for writing";

  print F
"blastBinDir=$blastBinPathCluster
dbFilePath=$computeClusterDataDir/$subjectFile
inputFilePath=$computeClusterDataDir/$queryFile
dbType=$dbType
regex='$idRegex'
blastProgram=$blastType
blastParamsFile=$ccBlastParamsFile
$vendorString
";
  close(F);

  # make blastParams file
  open(F, $localBlastParamsFile) || die "Can't open blast params file '$localBlastParamsFile' for writing";;
  print F "$blastArgs\n";
  close(F);
  #&runCmd($test, "chmod -R g+w $localDataDir/similarity/$queryName-$subjectName");
}

sub getParamsDeclaration {
  return ('taskInputDir',
	  'queryFile',
	  'subjectFile',
	  'blastArgs',
	  'idRegex',
	  'blastType',
	  'vendor',
	 );
}

sub getConfigDeclaration {
  return (
	  # [name, default, description]
	  ['taskSize', "", ""],
	  ['wuBlastBinPathCluster', "", ""],
	  ['ncbiBlastBinPathCluster', "", ""],
	 );
}

sub restart {
}

sub undo {

}

sub getDocumentation {
}
