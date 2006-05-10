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
@EXPORT = qw(makeRMDir makeGenomeDir makeGenomeReleaseXml makeMatrixDir makeSimilarityDir makeControllerPropFile makePfamDir makePsipredDir makeTRNAscanDir);

use strict;
use Carp;
use CBIL::Util::Utils;

sub makeRMDir {
    my ($datasetName, $pipelineName, $localPath, $serverPath, $nodePath, 
	$taskSize, $rmOptions, $dangleMax, $rmPath, $nodeClass) = @_;
    
    my $localBase = "$localPath/$pipelineName/repeatmask/$datasetName";
    my $serverBase = "$serverPath/$pipelineName/repeatmask/$datasetName"; 
    my $inputDir = "$localBase/input";
    &runCmd("mkdir -p $inputDir");
    &makeControllerPropFile($inputDir, $serverBase, 2, $taskSize, 
			    $nodePath, 
			    "DJob::DistribJobTasks::RepeatMaskerTask", $nodeClass);
    my $seqFileName = "$serverPath/$pipelineName/seqfiles/$datasetName.fsa"; 
    &makeRMTaskPropFile($inputDir, $seqFileName, $rmOptions, $rmPath,$dangleMax);
}

sub makeGenomeDir {
    my ($queryName, $targetName, $pipelineName, $localPath, $serverPath,
	$nodePath, $taskSize, $gaOptions, $gaBinPath, $genomeFile, $nodeClass) = @_;
    my $localBase = "$localPath/$pipelineName/genome/$queryName-$targetName";
    my $serverBase = "$serverPath/$pipelineName/genome/$queryName-$targetName";
    my $inputDir = "$localBase/input";
    my @targetFiles;
    &runCmd("mkdir -p $inputDir");
    &makeControllerPropFile($inputDir, $serverBase, 2, $taskSize, 
			    $nodePath, 
			    "DJob::DistribJobTasks::GenomeAlignTask", $nodeClass);
    my $seqFileName = "$serverPath/$pipelineName/repeatmask/$queryName/master/mainresult/blocked.seq";
    my $serverInputDir = "$serverBase/input";
    &makeGenomeTaskPropFile($inputDir, $serverInputDir, $seqFileName, $gaOptions, $gaBinPath);
    
    my $oocFile; # = $serverGDir . '/11.ooc';
    &makeGenomeParamsPropFile($inputDir . '/params.prop', $oocFile);
    
    push @targetFiles, "$serverPath/$pipelineName/seqfiles/$genomeFile.fsa";
    &makeGenomeTargetListFile($inputDir . '/target.lst', @targetFiles);
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
    my ($queryName, $subjectName, $pipelineName, $localPath, $serverPath, 
	$nodePath, $taskSize, $blastBinPath, $nodeClass) = @_;
    
    my $localBase = "$localPath/$pipelineName/matrix/$queryName-$subjectName";
    my $serverBase = "$serverPath/$pipelineName/matrix/$queryName-$subjectName"; 
    my $inputDir = "$localBase/input";
    &runCmd("mkdir -p $inputDir");
    &makeControllerPropFile($inputDir, $serverBase, 2, $taskSize, 
			    $nodePath, 
			    "DJob::DistribJobTasks::BlastMatrixTask", $nodeClass);
    my $dbFileName = "$serverPath/$pipelineName/repeatmask/$subjectName/master/mainresult/blocked.seq"; 
    my $seqFileName = "$serverPath/$pipelineName/repeatmask/$queryName/master/mainresult/blocked.seq"; 
    &makeBMTaskPropFile($inputDir, $blastBinPath, $seqFileName, $dbFileName);
}

sub makeSimilarityDir {
    my ($queryName, $subjectName, $pipelineName, $localPath, $serverPath, 
	$nodePath, $taskSize, $blastBinPath,
	$dbName, $dbPath, $queryFileName, $regex, $blast, $blastParams, $nodeClass,$dbType) = @_;
    
    my $localBase = "$localPath/$pipelineName/similarity/$queryName-$subjectName";
    my $serverBase = "$serverPath/$pipelineName/similarity/$queryName-$subjectName";
    my $inputDir = "$localBase/input";
    my $blastParamsFile = "$inputDir/blastParams";

    &runCmd("mkdir -p $inputDir");
    &makeControllerPropFile($inputDir, $serverBase, 1, $taskSize, 
			    $nodePath, "DJob::DistribJobTasks::BlastSimilarityTask", $nodeClass);
    my $dbFileName = "$dbPath/$dbName"; 
    my $seqFileName = "$serverPath/$pipelineName/seqfiles/$queryFileName";
    &makeBSTaskPropFile($inputDir, $blastBinPath, $seqFileName, $dbFileName, 
			$regex, $blast, "blastParams",$dbType);

    open(F, ">$blastParamsFile");
    print F "$blastParams\n";
    close(F);
}

sub makePfamDir {
  my ($queryName, $subjectName, $pipelineName, $localPath, $serverPath, 
      $nodePath, $taskSize, $pfamBinPath,
      $queryFileName, $fileDir,$subjectFileName,$nodeClass) = @_;

  my $localBase = "$localPath/$pipelineName/pfam/$queryName-$subjectName";
  my $serverBase = "$serverPath/$pipelineName/pfam/$queryName-$subjectName";
  my $inputDir = "$localBase/input";

  &runCmd("mkdir -p $inputDir");
  &makeControllerPropFile($inputDir, $serverBase, 2, $taskSize, 
			    $nodePath, "DJob::DistribJobTasks::HMMpfamTask", $nodeClass);

  my $subjectFilePath = "${fileDir}/$subjectFileName";
  my $queryFilePath = "${fileDir}/$queryFileName";
  &makePfamTaskPropFile($inputDir, $queryFilePath,$subjectFilePath,$pfamBinPath);
}

sub makeTRNAscanDir {
  my ($subject, $pipelineName, $localPath,
      $serverPath, $nodePath, $taskSize,
      $trnascanPath, $model,
      $fileDir,$subjectFileName,$nodeClass) = @_;

  my $localBase = "$localPath/$pipelineName/trnascan/$subject";
  my $serverBase = "$serverPath/$pipelineName/trnascan/$subject";
  my $inputDir = "$localBase/input";

  &runCmd("mkdir -p $inputDir");
  &makeControllerPropFile($inputDir, $serverBase, 2, $taskSize,
			    $nodePath, "DJob::DistribJobTasks::tRNAscanTask", $nodeClass);

  my $subjectFilePath = "${fileDir}/$subjectFileName";
  &makeTRNAscanTaskPropFile($inputDir,$subjectFilePath, $trnascanPath, $model );
}

sub makePsipredDir {
  my ($queryName, $subjectName, $pipelineName, $localPath, $serverPath,
      $nodePath, $taskSize, $psipredPath,$queryFile, $fileDir,$subjectFile,$nodeClass) = @_;

  my $localBase = "$localPath/$pipelineName/psipred/$queryName-$subjectName";

  my $serverBase = "$serverPath/$pipelineName/psipred/$queryName-$subjectName";

  my $inputDir = "$localBase/input";

  &runCmd("mkdir -p $inputDir");

  &makeControllerPropFile($inputDir, $serverBase, 2, $taskSize,$nodePath, "DJob::DistribJobTasks::PsipredTask", $nodeClass);

  my $subjectFilePath = "$serverPath/$pipelineName/psipred/$subjectFile";

  my $queryFilePath = "$serverPath/$pipelineName/seqfiles/$queryFile";

  &makePsipredTaskPropFile($inputDir, $queryFilePath,$subjectFilePath,$psipredPath);

}

sub makeControllerPropFile {
    my ($inputDir, $baseDir, $slotsPerNode, $taskSize, $nodePath, 
	$taskClass, $nodeClass) = @_;
    
    $nodeClass = 'DJob::DistribJob::BprocNode' unless $nodeClass;
    
    open(F, ">$inputDir/controller.prop") 
	|| die "Can't open $inputDir/controller.prop for writing";

    print F 
"masterdir=$baseDir/master
inputdir=$baseDir/input
nodedir=$nodePath
slotspernode=$slotsPerNode
subtasksize=$taskSize
taskclass=$taskClass
nodeclass=$nodeClass
restart=no
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

sub makeGenomeTargetListFile {
    my ($targetListFile, @targetFiles) = @_;

    open(F, ">$targetListFile") || die "Can't open $targetListFile for writing";

    foreach (@targetFiles) { print F $_ . "\n"; }
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
  my ($inputDir, $queryFilePath,$subjectFilePath, $psipredPath) = @_;

  open(F, ">$inputDir/task.prop") 
    || die "Can't open $inputDir/task.prop for writing";

  print F 
"psipredDir=$psipredPath
dbFilePath=$subjectFilePath
inputFilePath=$queryFilePath
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
	$regex, $blast, $blastParamsFile,$dbType) = @_;

    open(F, ">$inputDir/task.prop") 
	|| die "Can't open $inputDir/task.prop for writing";

    print F 
"blastBinDir=$blastBinDir
dbFilePath=$dbFileName
inputFilePath=$seqFilePath
dbType=$dbType
regex='$regex'
blastProgram=$blast
blastParamsFile=$blastParamsFile
";
    close(F);
}
