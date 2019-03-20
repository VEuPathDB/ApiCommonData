#!/usr/bin/perl

package ApiCommonData::Load::MakeTaskDirs;


##############################################################################
# Subroutines for creating directories used to control DistribJob Tasks
#
# Supported tasks (for now) are:
#  RepeatMaskTask, BlastSimilarityTask, BlastMatrixTask
#
# The directories are created on the local machine with the expectation that 
# they will be copied to the liniac server.  They use $serverPath and
# $nodePath to describe the root paths on the server and nodes.
#
# The main work done is the formatting of the controller.prop and task.prop
# files required by DistribJob Tasks
# 
# Directories created look like this:
# $localPath/$pipelineName/TASK/$datasetName/input/
#   controller.prop
#   task.prop
#
##############################################################################

require Exporter;
@ISA = qw(Exporter);
@EXPORT = qw(makeRMDir makeGenomeDir makeGenomeDirForGfClient makeGenomeReleaseXml makeMatrixDir makeSimilarityDir makeControllerPropFile makePfamDir makePsipredDir makeTRNAscanDir makeIprscanDir makeMsaDir);

use strict;
use Carp;
use CBIL::Util::Utils;

sub _createDir {
  my ($dir) = @_;
  return if (-e $dir);
  &runCmd("mkdir $dir");
  &runCmd("chmod -R g+w $dir");
}

sub makeRMDir {
    my ($datasetName, $localDataDir, $clusterDataDir,
	$nodePath,$taskSize, $rmOptions, $dangleMax, $rmPath, $nodeClass, $numNodes) = @_;
    $numNodes ||= 1;
    &_createDir("$localDataDir/repeatmask");
    my $inputDir = "$localDataDir/repeatmask/$datasetName/input";
    my $serverBase = "$clusterDataDir/repeatmask/$datasetName";
    &runCmd("mkdir -p $inputDir");
    &makeControllerPropFile($inputDir, $serverBase, $numNodes, $taskSize,
			    $nodePath,
			    "DJob::DistribJobTasks::RepeatMaskerTask",
			    $nodeClass);
    my $seqFileName = "$clusterDataDir/seqfiles/$datasetName.fsa"; 
    &makeRMTaskPropFile($inputDir, $seqFileName, $rmOptions, $rmPath,$dangleMax);
    &runCmd("chmod -R g+w $localDataDir/repeatmask/$datasetName");
}

sub makeMsaDir {
  my ($localDataDir, $clusterDataDir, $taskSize, $musclePath, $nodeClass,$nodePath ) = @_;
  my $inputDir = "$localDataDir/msa/input";
  my $serverBase = "$clusterDataDir/msa";
  my $slotsPerNode = 1;

  &_createDir("$localDataDir/msa");
  &runCmd("mkdir -p $inputDir");

  &makeControllerPropFile($inputDir, $serverBase, $slotsPerNode, $taskSize,
			    $nodePath,
			    "DJob::DistribJobTasks::MsaTask",
			    $nodeClass);
  my $groupsPath = "$clusterDataDir/seqfiles/groups";

  &makeMsaTaskPropFile($inputDir, $musclePath, $groupsPath);

}

sub makeGenomeDir {
    my ($queryName, $targetName, $localDataDir, $clusterDataDir,
	$nodePath, $taskSize, $gaOptions, $gaBinPath, $genomeFile, $nodeClass) = @_;
    my $inputDir = "$localDataDir/genome/$queryName-$targetName/input";
    my $serverBase = "$clusterDataDir/genome/$queryName-$targetName";
    &_createDir("$localDataDir/genome");

    my @targetFiles;
    &runCmd("mkdir -p $inputDir");
    &makeControllerPropFile($inputDir, $serverBase, 2, $taskSize,
			    $nodePath,
			    "DJob::DistribJobTasks::GenomeAlignTask", $nodeClass);
    my $seqFileName = "$clusterDataDir/repeatmask/$queryName/master/mainresult/blocked.seq";
    my $serverInputDir = "$serverBase/input";
    &makeGenomeTaskPropFile($inputDir, $serverInputDir, $seqFileName,
			    $gaOptions, $gaBinPath);
    my $oocFile; # = $serverGDir . '/11.ooc';
    &makeGenomeParamsPropFile($inputDir . '/params.prop', $oocFile);

    push @targetFiles, "$clusterDataDir/seqfiles/$genomeFile.fsa";
    &makeGenomeTargetListFile($inputDir . '/target.lst', @targetFiles);

    &runCmd("chmod -R g+w $localDataDir/genome/$queryName-$targetName");
}

sub makeGenomeDirForGfClient {
    my ($queryName, $targetName, $localDataDir, $clusterDataDir,
	$nodePath, $taskSize, $maxIntron, $gaBinPath, $nodeClass, $nodePort, $numNodes,$noRepMask) = @_;
    my $inputDir = "$localDataDir/genome/$queryName-$targetName/input";
    my $serverBase = "$clusterDataDir/genome/$queryName-$targetName";
    my $targetDirPath = "$clusterDataDir/seqfiles/$targetName/nib";
    &_createDir("$localDataDir/genome");

    &runCmd("mkdir -p $inputDir");
    &makeControllerPropFile($inputDir, $serverBase, $numNodes, $taskSize,
			    $nodePath,
			    "DJob::DistribJobTasks::GenomeAlignWithGfClientTask", $nodeClass);
    my $seqFileName = "$localDataDir/repeatmask/$queryName/master/mainresult/blocked.seq";
    my $serverInputDir = "$serverBase/input";
    &makeGenomeTaskPropFileForGfClient($inputDir, $targetDirPath,$nodePort, $queryName,
			    $maxIntron, $gaBinPath, $clusterDataDir,$noRepMask);

    &makeGenomeTargetListFileForGfClient($inputDir . '/target.lst', $localDataDir, $targetName,$clusterDataDir);

    &runCmd("chmod -R g+w $localDataDir/genome/$queryName-$targetName");
}

sub makeGenomeReleaseXml {
  my ($xml, $ext_db_id, $rls_date, $version, $url) = @_;

  open(F, ">$xml")
    || die "Can't open $xml for writing";
  print F
    "<SRES::ExternalDatabaseRelease>
   <external_database_id>$ext_db_id</external_database_id>
   <release_date>$rls_date</release_date>
   <version>$version</version>
   <download_url>$url</download_url>
 </SRES::ExternalDatabaseRelease>
 ";
  close(F);
}

sub makeMatrixDir {
    my ($queryName, $subjectName, $localDataDir, $clusterDataDir,
	$nodePath, $taskSize, $blastBinPath, $nodeClass) = @_;
    
    my $inputDir = "$localDataDir/matrix/$queryName-$subjectName/input";
    my $serverBase = "$clusterDataDir/matrix/$queryName-$subjectName"; 

    &_createDir("$localDataDir/matrix");
    &runCmd("mkdir -p $inputDir");
    &makeControllerPropFile($inputDir, $serverBase, 2, $taskSize, 
			    $nodePath, 
			    "DJob::DistribJobTasks::BlastMatrixTask", $nodeClass);
    my $dbFileName = "$clusterDataDir/repeatmask/$subjectName/master/mainresult/blocked.seq"; 
    my $seqFileName = "$clusterDataDir/repeatmask/$queryName/master/mainresult/blocked.seq"; 
    &makeBMTaskPropFile($inputDir, $blastBinPath, $seqFileName, $dbFileName);
    &runCmd("chmod -R g+w $localDataDir/matrix/$queryName-$subjectName");
}

sub makeSimilarityDir {
    my ($queryName, $subjectName, $localDataDir, $clusterDataDir,
	$nodePath, $taskSize, $blastBinPath, $dbName, $dbPath, $queryFileName,
	$regex, $blast, $blastParams, $nodeClass,$dbType,$vendor,$printSimSeqs) = @_;

    my $inputDir = "$localDataDir/similarity/$queryName-$subjectName/input";
    my $serverBase = "$clusterDataDir/similarity/$queryName-$subjectName";
    &_createDir("$localDataDir/similarity");
    my $blastParamsFile = "$inputDir/blastParams";

    &runCmd("mkdir -p $inputDir");
    &makeControllerPropFile($inputDir, $serverBase, 1, $taskSize, 
			    $nodePath, "DJob::DistribJobTasks::BlastSimilarityTask", $nodeClass);
    my $dbFileName = "$dbPath/$dbName"; 
    my $seqFileName = "$clusterDataDir/seqfiles/$queryFileName";
    &makeBSTaskPropFile($inputDir, $blastBinPath, $seqFileName, $dbFileName,
			$regex, $blast, "blastParams",$dbType,$vendor,$printSimSeqs);

    open(F, ">$blastParamsFile");
    print F "$blastParams\n";
    close(F);
    &runCmd("chmod -R g+w $localDataDir/similarity/$queryName-$subjectName");
}

sub makePfamDir {
  my ($queryName, $subjectName, $localDataDir, $clusterDataDir,
      $nodePath, $taskSize, $pfamBinPath,
      $queryFileName, $fileDir, $subjectFileName,$nodeClass) = @_;

  my $inputDir = "$localDataDir/pfam/$queryName-$subjectName/input";
  my $serverBase = "$clusterDataDir/pfam/$queryName-$subjectName";

  &_createDir("$localDataDir/pfam");
  &runCmd("mkdir -p $inputDir");
  &makeControllerPropFile($inputDir, $serverBase, 2, $taskSize, 
			    $nodePath, "DJob::DistribJobTasks::HMMpfamTask", $nodeClass);

  my $subjectFilePath = "${fileDir}/$subjectFileName";
  my $queryFilePath = "${fileDir}/$queryFileName";
  &makePfamTaskPropFile($inputDir, $queryFilePath,$subjectFilePath,$pfamBinPath);
    &runCmd("chmod -R g+w $localDataDir/pfam/$queryName-$subjectName");
}

sub makeTRNAscanDir {
  my ($subject, $localDataDir, $clusterDataDir,
      $nodePath, $taskSize,
      $trnascanPath, $model,
      $fileDir,$subjectFileName,$nodeClass) = @_;

  my $inputDir = "$localDataDir/trnascan/$subject/input";
  my $serverBase = "$clusterDataDir/trnascan/$subject";

  &_createDir("$localDataDir/trnascan");
  &runCmd("mkdir -p $inputDir");
  &makeControllerPropFile($inputDir, $serverBase, 2, $taskSize,
			  $nodePath, "DJob::DistribJobTasks::tRNAscanTask", $nodeClass);

  my $subjectFilePath = "${fileDir}/$subjectFileName";
  &makeTRNAscanTaskPropFile($inputDir,$subjectFilePath, $trnascanPath, $model );
    &runCmd("chmod -R g+w $localDataDir/trnascan/$subject");
}

sub makePsipredDir {
  my ($queryName, $subjectName, $localDataDir, $clusterDataDir,
      $nodePath, $taskSize, $psipredPath,$queryFile, $fileDir,
      $subjectFile,$nodeClass, $ncbiBinPath) = @_;

  my $inputDir = "$localDataDir/psipred/$queryName-$subjectName/input";

  my $serverBase = "$clusterDataDir/psipred/$queryName-$subjectName";

  &_createDir("$localDataDir/psipred");
  &runCmd("mkdir -p $inputDir");

  &makeControllerPropFile($inputDir, $serverBase, 2, $taskSize,$nodePath, "DJob::DistribJobTasks::PsipredTask", $nodeClass);

  my $subjectFilePath = "$clusterDataDir/psipred/$subjectFile";

  my $queryFilePath = "$clusterDataDir/seqfiles/$queryFile";

  &makePsipredTaskPropFile($inputDir, $queryFilePath,$subjectFilePath,$psipredPath,$ncbiBinPath);

  &runCmd("chmod -R g+w $localDataDir/psipred/$queryName-$subjectName");
}

sub makeIprscanDir {
  my ($subject, $localDataDir, $clusterDataDir,
      $nodePath,  $taskSize, $nodeClass,
      $fileDir, $subjectFileName, $seqtype,
      $appl, $crc, $email) = @_;

  # my $subject = $subjectFileName;

  my $inputDir = "$localDataDir/iprscan/$subject/input";
  my $serverBase = "$clusterDataDir/iprscan/$subject";

  &_createDir("$localDataDir/iprscan");
  &runCmd ("mkdir -p $inputDir");

  my $numSlotsPerNode = 2;
  &makeControllerPropFile ($inputDir, $serverBase, $numSlotsPerNode, 
			   $taskSize, $nodePath, 
			   "DJob::DistribJobTasks::IprscanTask", $nodeClass);

  my $seqfile = "$fileDir/$subjectFileName";
  my $output_file = $subject . "_iprscan_out.xml";
  &makeIprscanTaskPropFile ($inputDir, $seqfile, $output_file, $seqtype, $appl, $crc, $email);
  &runCmd("chmod -R g+w $localDataDir/iprscan/$subject");

}

sub makeControllerPropFile {
    my ($inputDir, $baseDir, $slotsPerNode, 
			$taskSize, $nodePath, $taskClass, $nodeClass) = @_;
    
    $nodeClass = 'DJob::DistribJob::BprocNode' unless $nodeClass;
    
    open(F, ">$inputDir/controller.prop") 
	|| die "Can't open $inputDir/controller.prop for writing";

    print F 
"masterdir=$baseDir/master
inputdir=$baseDir/input
nodeWorkingDirsHome=$nodePath
slotspernode=$slotsPerNode
subtasksize=$taskSize
taskclass=$taskClass
nodeclass=$nodeClass
";
    close(F);
}

sub makeRMTaskPropFile {
    my ($inputDir, $seqFileBasename, $rmOptions, $rmPath, $dangleMax) = @_;

    open(F, ">$inputDir/task.prop") 
	|| die "Can't open $inputDir/task.prop for writing";

    print F 
"rmPath=$rmPath
inputFilePath=$seqFileBasename
trimDangling=y
rmOptions=$rmOptions
dangleMax=$dangleMax
";
    close(F);
}


sub makeGenomeTaskPropFile {
    my ($inputDir, $serverInputDir, $seqFileName, $gaOptions, $gaBinPath) = @_;

    my $targetListFile = "$inputDir/target.lst";
    my $serverTargetListFile = "$serverInputDir/target.lst";

    open(F, ">$inputDir/task.prop")
	|| die "Can't open $inputDir/task.prop for writing";
    print F
"gaBinPath=$gaBinPath
targetListPath=$serverTargetListFile
queryPath=$seqFileName
";
    close(F);
}

sub makeGenomeTaskPropFileForGfClient {
    my ($inputDir, $targetDirPath, $nodePort, $query, $maxIntron, $gaBinPath, $clusterDataDir,$noRepMask) = @_;

    my $queryFile = $noRepMask ? "$clusterDataDir/repeatmask/$query/master/mainresult/blocked.seq" : "$clusterDataDir/seqfiles/${query}.fsa";

    open(F, ">$inputDir/task.prop")
	|| die "Can't open $inputDir/task.prop for writing";
    print F
"gaBinPath=$gaBinPath
targetDirPath=$targetDirPath
queryPath=$queryFile
nodePort=$nodePort
maxIntron=$maxIntron
";
    close(F);
}

sub makeMsaTaskPropFile {
  my ($inputDir, $musclePath, $groupsPath) = @_;

  open(F, ">$inputDir/task.prop")
	|| die "Can't open $inputDir/task.prop for writing";
    print F
"muscleBinDir=$musclePath
inputFileDir=$groupsPath
";
    close(F);
}


sub makeGenomeTargetListFile {
    my ($targetListFile, @targetFiles) = @_;

    open(F, ">$targetListFile") || die "Can't open $targetListFile for writing";

    foreach (@targetFiles) { print F $_ . "\n"; }
    close(F);
}

sub makeGenomeTargetListFileForGfClient {
    my ($targetListFile, $localDataDir, $targetName,$clusterDataDir) = @_; 

    open(F, ">$targetListFile") || die "Can't open $targetListFile for writing";

    my $genomeDir = "$localDataDir/seqfiles/$targetName";

    opendir(D,$genomeDir) || die "Can't open directory, $genomeDir";

    while(my $file = readdir(D)) { next() if ($file =~ /^\./);print F "$clusterDataDir/seqfiles/$targetName/$file\n"; }

    closedir(D);
    close(F);
}

sub makeGenomeParamsPropFile {
    my ($paramsPath, $oocFile) = @_;
    my $occParam = "ooc=$oocFile" if $oocFile;
    open(F, ">$paramsPath") || die "Can't open $paramsPath for writing";
    print F
"mask=lower
$occParam
";
    close(F);
}

sub makeBMTaskPropFile {
    my ($inputDir, $blastBinDir, $seqFilePath,  $dbFileName) = @_;

    open(F, ">$inputDir/task.prop") 
	|| die "Can't open $inputDir/task.prop for writing";

    print F 
"blastBinDir=$blastBinDir
dbFilePath=$dbFileName
inputFilePath=$seqFilePath
";
    close(F);
}

sub makePsipredTaskPropFile {
  my ($inputDir, $queryFilePath,$subjectFilePath, $psipredPath, $ncbiBinPath) = @_;

  open(F, ">$inputDir/task.prop") 
    || die "Can't open $inputDir/task.prop for writing";

  print F 
"psipredDir=$psipredPath
dbFilePath=$subjectFilePath
inputFilePath=$queryFilePath
ncbiBinDir=$ncbiBinPath
";
    close(F);
}

sub makeTRNAscanTaskPropFile {
  my ($inputDir,$subjectFilePath, $trnascanPath, $model ) = @_;

  open(F, ">$inputDir/task.prop") 
    || die "Can't open $inputDir/task.prop for writing";

  print F 
"tRNAscanDir=$trnascanPath
inputFilePath=$subjectFilePath
trainingOption=$model
";
    close(F);
}

sub  makePfamTaskPropFile {
  my ($inputDir, $queryFilePath, $subjectFilePath, $pfamBinPath) = @_;

   open(F, ">$inputDir/task.prop") 
    || die "Can't open $inputDir/task.prop for writing";

  print F 
"hmmpfamDir=$pfamBinPath
dbFilePath=$subjectFilePath
inputFilePath=$queryFilePath
";
    close(F);
}

sub makeBSTaskPropFile {
    my ($inputDir, $blastBinDir, $seqFilePath,  $dbFileName, 
	$regex, $blast, $blastParamsFile,$dbType,$vendor,$printSimSeqs) = @_;

    my $simSeqs = $printSimSeqs ? "printSimSeqsFile=yes" : "";

    open(F, ">$inputDir/task.prop") 
	|| die "Can't open $inputDir/task.prop for writing";

    print F 
"dbFilePath=$dbFileName
inputFilePath=$seqFilePath
dbType=$dbType
regex='$regex'
blastProgram=$blast
blastParamsFile=$blastParamsFile
$simSeqs
";
    close(F);

   if ($vendor) {
      open(F, ">>$inputDir/task.prop") 
	|| die "Can't open $inputDir/task.prop for appending";
      print F
"blastVendor=$vendor";
      close(F);
    }

}

sub makeIprscanTaskPropFile {
	my ($inputDir, $seqfile, $outputfile, 
			$seqtype, $appls, $crc, $email) = @_;

	open (TASKPROP, "> $inputDir/task.prop")
		or die "Can't open $inputDir/task.prop for writing: $!\n";

	print TASKPROP "seqfile=$seqfile\n"
					. "outputfile=$outputfile\n"
					. "seqtype=$seqtype\n"
					. "appl=$appls\n"
					. "email=$email\n";
	$crc and print TASKPROP "crc=$crc\n";
	close TASKPROP;
}

