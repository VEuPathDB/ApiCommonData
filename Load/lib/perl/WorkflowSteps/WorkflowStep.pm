package ApiCommonData::Load::WorkflowSteps::WorkflowStep;

########################################
## Super class for ApiDB workflow steps
########################################

@ISA = (GUS::Workflow::WorkflowStepInvoker);

use strict;
use Carp;

use GUS::Workflow::WorkflowStepInvoker;

sub getLocalDataDir {
    my ($self) = @_;
    my $workflowHome = $self->getWorkflowHomeDir();
    return "$workflowHome/data";
}

sub getComputeClusterHomeDir {
    my ($self) = @_;
    my $clusterBase = $self->getGlobalConfig('clusterBaseDir');
    my $projectName = $self->getWorkflowConfig('name');
    my $projectVersion = $self->getWorkflowConfig('version');
    return "$clusterBase/$projectName/$projectVersion";
}

sub getComputeClusterDataDir {
    my ($self) = @_;
    my $home = $self->getComputeClusterHomeDir();
    return "$home/data";
}

sub getComputeClusterTaskLogsDir {
    my ($self) = @_;
    my $home = $self->getComputeClusterHomeDir();
    return "$home/taskLogs";
}

sub makeClusterControllerPropFile {
  my ($self, $taskInputDir, $slotsPerNode, $taskSize, $taskClass) = @_;

  my $nodePath = $self->getGlobalConfig('nodePath');
  my $nodeClass = $self->getGlobalConfig('nodeClass');

  # tweak inputs
  my $masterDir = $taskInputDir;
  $masterDir =~ s/input/master/;
  $nodeClass = 'DJob::DistribJob::BprocNode' unless $nodeClass;

  # get configuration values
  my $nodePath = $self->getGlobalConfig('nodePath');
  my $nodeClass = $self->getGlobalConfig('nodeClass');

  # construct dir paths
  my $localDataDir = $self->getLocalDataDir();
  my $computeClusterDataDir = $self->getComputeClusterDataDir();

  # print out the file
  my $controllerPropFile = "$localDataDir/$taskInputDir/controller.prop";
  open(F, ">$controllerPropFile")
      || $self->error("Can't open controller prop file '$controllerPropFile' for writing");
  print F 
"masterdir=$computeClusterDataDir/$masterDir
inputdir=$computeClusterDataDir/$taskInputDir
nodedir=$nodePath
slotspernode=$slotsPerNode
subtasksize=$taskSize
taskclass=$taskClass
nodeclass=$nodeClass
restart=no
";
    close(F);
}

sub testInputFile {
  my ($self, $paramName, $fileName) = @_;

  $self->error("Input file '$fileName' for param $paramName in step '$self->{name}' does not exist") unless -e $fileName;
}

# avoid using this subroutine!
# it is provided for backward compatibility.  plugins and commands that
# are called from the workflow should take an extDbRlsSpec as an argument,
# not an internal id
sub getExtDbRlsId {
  my ($self, $test, $extDbRlsSpec) = @_;

  my ($extDbName, $extDbRlsVer) = $self->getExtDbInfo($test,$extDbRlsSpec);

  my $sql = "select external_database_release_id from sres.externaldatabaserelease d, sres.externaldatabase x where x.name = '${extDbName}' and x.external_database_id = d.external_database_id and d.version = '${extDbRlsVer}'";

  my $cmd = "getValueFromTable --idSQL \"$sql\"";
  my $extDbRlsId = $self->runCmd($test, $cmd);

  if ($test) {
    return "UNKNOWN_EXT_DB_RLS_ID";
  } else {
    return  $extDbRlsId;
  }
}

sub getExtDbInfo {
    my ($self,$test, $extDbRlsSpec) = @_;

    if ($test) {
      return ("UNKNOWN_DbName","UNKNOWN_DbVer");
    } elsif ($extDbRlsSpec =~ /(.+)\|(.+)/) {
      my $extDbName = $1;
      my $extDbRlsVer = $2;
      return ($extDbName, $extDbRlsVer);
    } else {
      $self->error("Database specifier '$extDbRlsSpec' is not in 'name|version' format");
    }
}

sub getTableId {
  my ($self, $tableName) = @_;
  my $sql = "select table_id from core.tableinfo where name = '$tableName'";

  my $cmd = "getValueFromTable --idSQL \"$sql\"";
  my $tableId = $self->runCmd(0, $cmd);
  return  $tableId;
}

sub getTaxonIdFromNcbiTaxId {
  my ($self, $test, $taxId) = @_;

  my $sql = "select taxon_id from sres.taxon where ncbi_tax_id = $taxId";

  my $cmd = "getValueFromTable --idSQL \"$sql\"";

  my $taxonId = $self->runCmd($test, $cmd);

  if ($test) {
    return "UNKNOWN_TAXON_ID";
  } else {
    return  $taxonId;
  }
}

sub getTaxonIdList {
  my ($self, $test, $taxonId, $hierarchy) = @_;

  if ($hierarchy) {
    my $idList = $self->runCmd($test, "getSubTaxaList --taxon_id $taxonId");
    if ($test) {
      return "UNKNOWN_TAXON_ID_LIST";
    } else {
      chomp($idList);
      return  $idList;
    }
  } else {
    return $taxonId;
  }
}


sub getInputFiles{
  my ($self, $test, $fileOrDir, $seqFileExtension) = @_;
  my @inputFiles;

  if (-d $fileOrDir) {
    opendir(DIR, $fileOrDir) || die "Can't open directory '$fileOrDir'";
    my @noDotFiles = grep { $_ ne '.' && $_ ne '..' } readdir(DIR);
    @inputFiles = map { "$fileOrDir/$_" } @noDotFiles;
    @inputFiles = grep(/.*\.$seqFileExtension$/, @inputFiles) if $seqFileExtension;
  } else {
    $inputFiles[0] = $fileOrDir;
  }
  return @inputFiles;
}

1;

