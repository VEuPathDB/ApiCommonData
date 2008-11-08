package ApiCommonData::Load::WorkflowSteps::MakeBlastTaskInputDir;

@ISA = (ApiCommonData::Load::WorkflowSteps::WorkflowStep);

use ApiCommonData::Load::WorkflowSteps::WorkflowStep;

sub run {
  my ($self) = @_;

  # get parameter values
  my $taskInputDir = $self->getParamValue("taskInputDir");
  my $queryFile = $self->getParamValue("queryFile");
  my $subjectFile = $self->getParamValue("subjectFile");
  my $blastArgs = $self->getParamValue("blastArgs");
  my $idRegex = $self->getParamValue("idRegex");
  my $blastType = $self->getParamValue("blastType");
  my $vendor = $self->getParamValue("vendor");

  my $bsTaskSize = $self->getConfig('blastsimilarity.taskSize');
  my $blastBinPathCluster = $self->getConfig('wuBlastBinPathCluster');
  $blastBinPathCluster = $self->getConfig('ncbiBlastBinPathCluster') if ($vendor eq 'ncbi');
  my $dbType = ($blastType =~ m/blastn|tblastx/i) ? 'n' : 'p';

  # make controller.prop file
  $self->makeClusterControllerPropFile($taskInputDir, 2, $taskSize, $nodePath, 
				       "DJob::DistribJobTasks::BlastMatrixTask",
				       $nodeClass);

  # make task.prop file
  my $computeClusterDataDir = $self->getComputClusterDataDir();
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

sub restart {
}

sub undo {

}

sub getConfigDeclaration {
  my @properties = 
    (
     # [name, default, description]
     ['', "", ""],
     ['', "", ""],
     ['', "", ""],
     ['', "", ""],
     ['', "", ""],
     ['', "", ""],
     ['', "", ""],
     ['' "", ""],
    );
  return @properties;
}

sub getDocumentation {
}
