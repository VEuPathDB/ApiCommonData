use strict;

use Bio::SeqIO;
use CBIL::Util::PropertySet;
use GUS::Pipeline::NfsCluster;
use GUS::Pipeline::SshCluster;
use GUS::Pipeline::Manager;
use ApiCommonData::Load::MakeTaskDirs;

use File::Basename;

chomp(my $pipelineScript = `basename $0`);

## NOTE: at the bottom of this file are the old "steps specific property
## declarations.  we intend to incorporate them into the steps that need them


sub init {
  my ($propertiesFile, $inputOptionalArgs, $allSpecies, $taxId) = @_;

  $| = 1;
  umask 002;

  my $optionalArgs = {printXML => 0,
		      skipCleanup => 0};

  &usage unless -e $propertiesFile;
  if ($inputOptionalArgs){
    &usage unless scalar(@$inputOptionalArgs <= scalar(keys(%$optionalArgs)));
    foreach my $optionalArg (@$inputOptionalArgs) {
      &usage unless $optionalArg =~ /\-(\w+)/;
      my $arg = $1;
      &usage unless defined($optionalArgs->{$arg});
      $optionalArgs->{$arg} = 1;
    }
  }

  # [name, default (or null if reqd), comment]
  my @properties = 
    (
     # universal analysis pipeline properties

     ["release",   "",  "release number (eg 5.2)"],
     ["projectDir",   "",  "path to the project's directory tree"],
     ["clusterServer", "",  "full name of cluster server"],
     ["gusConfigFile",  "",  "gus configuration file"],
     ["nodePath",             "",  "full path of scratch dir on cluster node"],
     ["nodeClass", "","cluster management protocol"],
     ["clusterProjectDir", "",  "path to the project's dir tree on cluster"],
     ["stopBefore",   "none",  "the step to stop before.  uses the signal name"],
     ["commit", "", "fill in"],
     ["testNextPlugin", "", "fill in"],
     ["projectName", "", " project name from projectinfo.name"],
    );

  # get necessary properties
  my $propertySet  = CBIL::Util::PropertySet->new($propertiesFile, \@properties, 1);
  my $myPipelineName = $propertySet->getProp('myPipelineName');
  my $projectDir = $propertySet->getProp('projectDir');
  my $clusterProjectDir = $propertySet->getProp('clusterProjectDir');
  my $release = $propertySet->getProp('release');

  my $analysisPipelineDir = "$projectDir/$release/analysis_pipeline/";
  my $myPipelineDir = "$analysisPipelineDir/$myPipelineName";

  my $cluster;
  if ($propertySet->getProp('clusterServer') ne "none") {
    $cluster = GUS::Pipeline::SshCluster->new($propertySet->getProp('clusterServer'),
					      $propertySet->getProp('clusterUser') );
  } else {
    $cluster = GUS::Pipeline::NfsCluster->new();
  }

  my $mgr = GUS::Pipeline::Manager->new($myPipelineDir, $propertySet,
					$propertiesFile, $cluster,
					$propertySet->getProp('testNextPlugin'),
					$optionalArgs->{printXML},
					$optionalArgs->{skipCleanup},
				       );

  # set up global variables
  $mgr->{propertiesFile} = $propertiesFile;
  $mgr->{myPipelineDir} = $myPipelineDir;
  $mgr->{myPipelineName} = $myPipelineName;
  $mgr->{dataDir} = "$analysisPipelineDir/primary/data";
  $mgr->{clusterDataDir} = "$clusterProjectDir/$release/analysis_pipeline/primary/data";

  &createDataDir($mgr,$allSpecies,$mgr->{dataDir});

  &makeUserProjectGroup($mgr);

  if ($mgr->{myPipelineName} eq "primary") {
 	&copyPipelineDirToComputeCluster($mgr);
  }

  my $taxonHsh = &getTaxonIdFromTaxId($mgr,$taxId);

  $mgr->{taxonHsh} = $taxonHsh;

  return ($mgr, $projectDir, $release);
}

sub initToxoAnalysis {
  my ($propertyFile, $optionalArgs) = @_;

  my $allSpecies = 'Tgondii';

  my $taxId = ["Tgondii:5811","TgondiiApicoplast:5811","TgondiiGT1:507601","TgondiiVEG:432359","TgondiiRH:383379","TgondiiME49:508771"];

  my ($mgr, $projectDir, $release)
    = &init($propertyFile, $optionalArgs,$allSpecies, $taxId);

  return ($mgr, $projectDir, $release, $allSpecies);
}

sub initPlasmoAnalysis {
  my ($propertyFile, $optionalArgs) = @_;

  my $allSpecies = 'Pfalciparum,Pyoelii,Pvivax,Pberghei,Pchabaudi';

  my $taxId = ["Pfalciparum:36329","PfalciparumPlastid:36329","PfalciparumMito:36329","Pyoelii:352914","Pvivax:5855","PvivaxMito:126793","Pberghei:5823","Pchabaudi:31271","Pknowlesi:5851"];

  my ($mgr, $projectDir, $release)
    = &init($propertyFile, $optionalArgs, $allSpecies, $taxId);

  return ($mgr, $projectDir, $release, $allSpecies);
}

sub initCryptoAnalysis {
  my ($propertyFile, $optionalArgs) = @_;

  my $allSpecies = 'Cparvum,Chominis,Cmuris';

  my $taxId = ["Cparvum:5807","Chominis:353151","Cmuris:5808"];

  my ($mgr, $projectDir, $release)
    = &init($propertyFile, $optionalArgs,$allSpecies, $taxId);

  return ($mgr, $projectDir, $release, $allSpecies);
}


sub initTrypAnalysis{
  my ($propertyFile, $optionalArgs) = @_;

  my $allSpecies = 'Tbrucei,Tcruzi,Lbraziliensis,Linfantum,Lmajor';

  my $taxId = ["Tbrucei:185431","Tcruzi:353153","Lbraziliensis:420245","Linfantum:435258","Lmajor:347515"];

  my ($mgr, $projectDir, $release)
    = &init($propertyFile, $optionalArgs,$allSpecies, $taxId);

  return ($mgr, $projectDir, $release, $allSpecies);
}

sub initOrphAnalysis{
  my ($propertyFile, $optionalArgs) = @_;

  my $allSpecies = 'Tannulata,Tparva';

  my $taxId = ["Tannulata:353154","Tparva:333668"];

  my ($mgr, $projectDir, $release)
    = &init($propertyFile, $optionalArgs,$allSpecies, $taxId);

  return ($mgr, $projectDir, $release, $allSpecies);
}

sub initMicroAnalysis {
  my ($propertyFile, $optionalArgs) = @_;

  my $allSpecies = "Ebieneusi,Eintestinalis,Ecuniculi";

  my $taxId = ["Ebieneusi:481877","Eintestinalis:58839","Ecuniculi:284813"];

  my ($mgr, $projectDir, $release)
    = &init($propertyFile, $optionalArgs,$allSpecies, $taxId);

  return ($mgr, $projectDir, $release, $allSpecies);
}

sub initAmoebAnalysis {
  my ($propertyFile, $optionalArgs) = @_;

  my $allSpecies = "Edispar,Einvadens,Ehistolytica";

  my $taxId = ["Edispar:370354","Einvadens:370355","Ehistolytica:294381"];

  my ($mgr, $projectDir, $release)
    = &init($propertyFile, $optionalArgs,$allSpecies, $taxId);

  return ($mgr, $projectDir, $release, $allSpecies);
}

sub UpdateGusTableWithXml {
  my ($mgr,$file,$table) = @_;
  my $signal = "Load${table}WithXml";

  my $args = "--filename $file";

  $mgr->runPlugin($signal,
		  "GUS::Supported::Plugin::LoadGusXml", $args,
		  "Loading rows in $table from xml file");
}


sub dumpNaSequence {
  my ($mgr, $mercatorDir, $shortName, $extDbSpec,$virtualExtDbSpec) = @_;

  my $signal = "dumpSequence-$shortName";

  my $sql = '';
  return if $mgr->startStep("Dumping NASequence [$shortName]..", $signal);
  unless(-e $mercatorDir) {
    $mgr->runCmd("mkdir -p $mgr->{dataDir}/$mercatorDir");
    $mgr->runCmd("chmod -R g+w $mgr->{dataDir}/$mercatorDir");
  }

  my $outputFile = "$mgr->{dataDir}/$mercatorDir/$shortName.fsa";

  my ($extDbRls,$virtualExtDbRls);

  my @extDbSpecList = split (/,/,$extDbSpec);

  foreach my $extDb (@extDbSpecList){
      my ($dbName,$dbRlsVer)= split (/\|/,$extDb);
      $extDbRls .=&getDbRlsId($mgr,$dbName,$dbRlsVer);
  }    
  $extDbRls =~ s/(,)$//g;

  if($virtualExtDbSpec) {
        my @virtualExtDbSpecList = split (/,/,$virtualExtDbSpec);

	foreach my $extVirtualDb (@virtualExtDbSpecList){
        my ($virtualDbName,$virtualDbRlsVer)= split (/\|/,$extVirtualDb);
        $virtualExtDbRls .=&getDbRlsId($mgr,$virtualDbName,$virtualDbRlsVer);
   }    
	$virtualExtDbRls =~ s/(,)$//g;
	$sql = "select source_id, sequence from Dots.VIRTUALSEQUENCE vs,  SRes.EXTERNALDATABASE e, SRes.EXTERNALDATABASERELEASE r  where e.external_database_id = r.external_database_id and vs.external_database_release_id = r.external_database_release_id and r.external_database_release_id in($virtualExtDbRls)";

	$mgr->runCmd("dumpSequencesFromTable.pl --outputfile $outputFile --idSQL \"$sql\"");
  }
 
      


  $sql = "select source_id, sequence from Dots.EXTERNALNASEQUENCE es, SRes.EXTERNALDATABASE e, SRes.EXTERNALDATABASERELEASE r  where e.external_database_id = r.external_database_id and es.external_database_release_id = r.external_database_release_id and r.external_database_release_id in '$extDbRls' and es.na_sequence_id NOT IN (select sp.piece_na_sequence_id from dots.SEQUENCEPIECE sp, dots.VIRTUALSEQUENCE vs, Sres.EXTERNALDATABASE e, Sres.EXTERNALDATABASERELEASE r  where vs.na_sequence_id = sp.virtual_na_sequence_id AND vs.external_database_release_id = r.external_database_release_id AND r.external_database_id = e.external_database_id AND r.external_database_release_id in '$virtualExtDbRls')";
  $mgr->runCmd("dumpSequencesFromTable.pl --outputfile $outputFile --idSQL \"$sql\"");
  $mgr->endStep($signal);
}


sub initAmitoAnalysis {
  my ($propertyFile, $optionalArgs) = @_;

  my $allSpecies = 'Glamblia,Tvaginalis';

  my $taxId = ["Glamblia:184922","Tvaginalis:412133"];

  my ($mgr, $projectDir, $release)
    = &init($propertyFile, $optionalArgs, $allSpecies, $taxId);

  return ($mgr, $projectDir, $release, $allSpecies);
}


sub initGiardiaAnalysis {
  my ($propertyFile, $optionalArgs) = @_;

  my $allSpecies = 'Glamblia';

  my $taxId = ["Glamblia:184922"];

  my ($mgr, $projectDir, $release)
    = &init($propertyFile, $optionalArgs, $allSpecies, $taxId);

  return ($mgr, $projectDir, $release, $allSpecies);
}

sub initOrthomclAnalysis {
  my ($propertyFile, $optionalArgs) = @_;

  my $allSpecies = 'BAE_all';

  my $taxId = [];

  my ($mgr, $projectDir, $release)
    = &init($propertyFile, $optionalArgs, $allSpecies, $taxId);

  return ($mgr, $projectDir, $release, $allSpecies);
}

sub createDataDir {
  my ($mgr,$allSpecies, $dataDir) = @_;

  my $propertySet = $mgr->{propertySet};
  my $signal = "createDir";

  return if $mgr->startStep("Creating dir structure", $signal);

  &_createDir($mgr, $dataDir);

  my @dataSubDirs = ('seqfiles', 'misc', 'downloadSite', 'blastSite', 'isolateVocabulary',
		     'sage', 'analysis', 'similarity', 'assembly', 'cluster', 'microarray','mercator');

  foreach my $subDir (@dataSubDirs) {
    &_createDir($mgr, "$dataDir/$subDir");
  }

  my @Species = split(/,/,$allSpecies);

  my @assemblySubDirs = ('Initial', 'Intermed', 'Initial/big', 'Initial/small',
			 'Initial/reassemble', 'Intermed/big',
			 'Intermed/small', 'Intermed/reassemble');

  foreach my $species (@Species) {
    foreach my $subDir (@assemblySubDirs) {
      &_createDir($mgr, "$dataDir/assembly/${species}${subDir}");
    }
  }

  foreach my $species (@Species) {
    &_createDir($mgr, "$dataDir/cluster/${species}Initial");
    &_createDir($mgr, "$dataDir/cluster/${species}Intermed");
  }

 $mgr->endStep($signal);
}


sub sqlLoader {
  my ($mgr, $ctrl) = @_;

  my $propertySet = $mgr->{propertySet};

  my $shortName = basename($ctrl);
  my $signal = "bulkLoad-$shortName";
  my $log = $ctrl. ".log";

  return if $mgr->startStep("Bulk Loading $ctrl", $signal);

  my $gus_config_file = $propertySet->getProp('gusConfigFile');

  my @properties = ();
  my $gusconfig = CBIL::Util::PropertySet->new($gus_config_file, \@properties, 1);

  my $u = $gusconfig->{props}->{databaseLogin};
  my $pw = $gusconfig->{props}->{databasePassword};
  my ($dbi,$oracle,$db) = split(':', $gusconfig->{props}->{dbiDsn});

  $mgr->runCmd("sqlldr $u/$pw\@$db control=$ctrl log=$log");

  $mgr->endStep($signal);
}



sub _createDir {
  my ($mgr, $dir) = @_;
  return if (-e $dir);
  $mgr->runCmd("mkdir -p $dir");
  $mgr->runCmd("chmod -R g+w $dir");
}

sub makeBrcSeqXmlFile {
    my ($mgr, $extDbName, $extDbRlsVer, $gffFile, $brcSubmit, $curators, $outFile, $dbName, $downloadedFrom, $submitGenbank, $organism) = @_;

    my $dataDir = $mgr->{dataDir};

    my $brcDir = "brcXmlFiles";

    my $signal = "makeBrcSeqXmlFile_${outFile}";

    return if $mgr->startStep("Making BRC XML File ${outFile}", $signal);

    &_createDir($mgr, "$dataDir/$brcDir");

    $mgr->runCmd("makeBrcSeqXmlFile --extDbName '$extDbName' --extDbRlsVer '$extDbRlsVer' --gffFile $gffFile --brcSubmits $brcSubmit --curators '$curators' --dbName '$dbName' --downloadedFrom '$downloadedFrom' $submitGenbank --organism '$organism'> $dataDir/$brcDir/$outFile");

    $mgr->endStep($signal);
}

sub makeBrcGOAssociationFile {
    my ($mgr, $extDbName, $extDbRlsVer, $outFile,  $Prefix, $dbName) = @_;

    my $dataDir = $mgr->{dataDir};

    my $brcDir = "brcGOAssociationFiles";

    my $signal = "makeBrcGOAssociationFile_${outFile}";

    return if $mgr->startStep("Making BRC GO Association File ${outFile}", $signal);

    &_createDir($mgr, "$dataDir/$brcDir");

    $mgr->runCmd("makeBrcGOAssociationFile --extDbName '$extDbName' --extDbRlsVer '$extDbRlsVer' --Prefix '$Prefix' --dbName '$dbName' > $dataDir/$brcDir/$outFile");

    $mgr->endStep($signal);
}

sub createBlastMatrixDir {
  my ($mgr, $species, $queryFile, $subjectFile) = @_;

  my $propertySet = $mgr->{propertySet};
  my $signal = "create${queryFile}-${subjectFile}MatrixDir";

  return if $mgr->startStep("Creating ${queryFile}-${subjectFile} dir", $signal);

  my $dataDir = $mgr->{dataDir};
  my $clusterDataDir = $mgr->{clusterDataDir};
  my $nodePath = $propertySet->getProp('nodePath');
  my $nodeClass = $propertySet->getProp('nodeClass');
  my $bmTaskSize = $propertySet->getProp('blastmatrix.taskSize');
  my $wuBlastBinPathCluster = $propertySet->getProp('wuBlastBinPathCluster');

  my $speciesFile = $species . $queryFile;
  &makeMatrixDir($speciesFile, $species.$subjectFile, $dataDir,$clusterDataDir,
		 $nodePath, $bmTaskSize, $wuBlastBinPathCluster, $nodeClass);

  $mgr->endStep($signal);
}

sub documentBlast {
  my ($mgr, $blastType, $query, $subject, $bsParams) = @_;

  my %descriptions =
    ( BLASTP => "WU-BLASTP is used to identify statistically significant protein sequence similarities found between protein sequence queries and protein sequence libraries",
      BLASTX => "WU-BLASTX is used to identify statistically significant DNA-protein sequence similarities found between DNA sequence queries and protein sequence libraries",
      BLASTN => "WU-BLASTN is used to identify statistically signficant DNA sequence similarities found between DNA sequence queries and DNA sequence libraries"
    );

  my $description = $descriptions{$blastType} || "No description available for $blastType";

  my $documentation =
    { name => "WU-$blastType ($query vs. $subject)",
      input => "$query and $subject",
      output => "$blastType alignments",
      descrip => $description,
      tools => [
		{ name => $blastType,
		  version => "2.0 [06-Apr-2005]",
		  params => $bsParams,
		  url => "http://blast.wustl.edu",
		  pubmedIds => "",
		  credits => "Warren R. Gish, Washington University, Saint Louis, Missouri"
		},
	       ]
    };
  $mgr->documentStep("blast", $documentation);
}

sub createSimilarityDir {
  my ($mgr,$queryFile,$subjectFile,$regex,$bsParams,$blastType,$vendor, $printSimSeqs) = @_;

  my $propertySet = $mgr->{propertySet};
  my $signal = "create" . ucfirst($queryFile) . "-" . ucfirst ($subjectFile) ."SimilarityDir";

  my $dbType = ($blastType =~ m/blastn|tblastx/i) ? 'n' : 'p';

  my $description="";


  return if $mgr->startStep("Creating ${queryFile}-${subjectFile} similarity dir", $signal);

  my $dataDir = $mgr->{dataDir};
  my $clusterDataDir = $mgr->{clusterDataDir};
  my $nodePath = $propertySet->getProp('nodePath');
  my $nodeClass = $propertySet->getProp('nodeClass');
  my $bsTaskSize = $propertySet->getProp('blastsimilarity.taskSize');
  my $blastBinPathCluster = $propertySet->getProp('wuBlastBinPathCluster');
  $blastBinPathCluster = $propertySet->getProp('ncbiBlastBinPathCluster') if ($vendor eq 'ncbi');

  &makeSimilarityDir($queryFile, $subjectFile, $dataDir, $clusterDataDir,
		     $nodePath, $bsTaskSize,
		     $blastBinPathCluster,
		     "${subjectFile}.fsa", "$clusterDataDir/seqfiles", "${queryFile}.fsa", $regex, $blastType, $bsParams, $nodeClass,$dbType,$vendor,$printSimSeqs);

  $mgr->endStep($signal);
}

sub createPfamDir {
  my ($mgr,$queryFile,$subjectFile) = @_;

  my $propertySet = $mgr->{propertySet};

  my $query = $queryFile;

  my $subject = $subjectFile;

  $query =~ s/\.\w+//g;
  $subject =~ s/\.\w+//g;

  my $signal = "make$query" . ucfirst($subject) . "SubDir";

  return if $mgr->startStep("Creating ${query}-$subject pfam dir", $signal);

  my $dataDir = $mgr->{'dataDir'};
  my $clusterDataDir = $mgr->{'clusterDataDir'};
  my $nodePath = $propertySet->getProp('nodePath');
  my $nodeClass = $propertySet->getProp('nodeClass');
  my $pfamTaskSize = $propertySet->getProp('pfam.taskSize');
  my $pfamPath = $propertySet->getProp('pfam.path');

  $mgr->runCmd("mkdir -p $dataDir/pfam/$query-$subject");

  &makePfamDir($query, $subject, $dataDir, $clusterDataDir,
	       $nodePath, $pfamTaskSize,
	       $pfamPath,
	       $queryFile,"$clusterDataDir/seqfiles",$subjectFile,$nodeClass);

  $mgr->endStep($signal);
}

sub createTRNAscanDir {
  my ($mgr,$subjectFile,$model) = @_;

  my $propertySet = $mgr->{propertySet};

  my $subject = $subjectFile;

  $subject =~ s/\.\w+\b//;

  my $signal = "make${subject}TRNAscanDir";

  return if $mgr->startStep("Creating $subject tRNAscan subdir", $signal);

  my $dataDir = $mgr->{'dataDir'};
  my $clusterDataDir = $mgr->{'clusterDataDir'};
  my $nodePath = $propertySet->getProp('nodePath');
  my $nodeClass = $propertySet->getProp('nodeClass');
  my $trnascanTaskSize = $propertySet->getProp('trnascan.taskSize');
  my $trnascanPath = $propertySet->getProp('trnascan.clusterpath');

  $mgr->runCmd("mkdir -p $dataDir/trnascan/$subject");

  &makeTRNAscanDir($subject, $dataDir, $clusterDataDir,
		   $nodePath, $trnascanTaskSize,
		   $trnascanPath,$model,
		   "$clusterDataDir/seqfiles",$subjectFile,$nodeClass);

  $mgr->endStep($signal);
}

sub createMuscleDir {
  my ($mgr) = @_;

  my $propertySet = $mgr->{propertySet};

  my $signal = "makeMuscleDir";

  return if $mgr->startStep("Creating muscle input dir", $signal);

  my $dataDir = $mgr->{'dataDir'};
  my $clusterDataDir = $mgr->{'clusterDataDir'};
  my $nodePath = $propertySet->getProp('nodePath');
  my $nodeClass = $propertySet->getProp('nodeClass');
  my $muscleTaskSize = $propertySet->getProp('muscle.taskSize');
  my $muscleBinDir = $propertySet->getProp('muscleBinDir');

  #$mgr->runCmd("mkdir -p $dataDir/msa");

  &makeMsaDir($dataDir, $clusterDataDir,
		   $muscleTaskSize,$muscleBinDir,
		   $nodeClass,$nodePath);

  $mgr->endStep($signal);
}


sub rnaScanToGff2 {
  my ($mgr,$dir) = @_;

  my $signal = "tRNA${dir}GFF";

  return if $mgr->startStep("Creating $dir tRNAscan gff2 file", $signal);

  my $inFile = "$mgr->{'dataDir'}/trnascan/${dir}/master/mainresult/trnascan.out";

  my $outFile = "$mgr->{'dataDir'}/trnascan/${dir}/master/mainresult/trnascan.gff2";

  $mgr->runCmd("makeGFF2File -infile $inFile -outfile $outFile");

  $mgr->endStep($signal);
}

sub loadTRNAscan {
  my ($mgr,$scanDbName,$scanDbVer,$genomeDbName,$genomeDbVer,$soVer,$name,$table) = @_;

  my $signal = "tRNAScan$name";

  my $dataFile = "$mgr->{'dataDir'}/trnascan/$name/master/mainresult/trnascan.out";

  my $args = "--data_file $dataFile --scanDbName '$scanDbName' --scanDbVer '$scanDbVer' --genomeDbName '$genomeDbName' --genomeDbVer '$genomeDbVer' --soVersion '$soVer'";

  $args .=" --seqTable '$table'" if $table;

  $mgr->runPlugin($signal,
		  "ApiCommonData::Load::Plugin::LoadTRNAScan", $args,
		  "Loading tRNAscan results for $name");
}

sub loadAnticodons {
  my ($mgr,$genomeDbName,$genomeDbVer,$file) = @_;

  my $propertySet = $mgr->{propertySet};

  my $signal = "${file}Anticodons";

  my $projectDir = $propertySet->getProp('projectDir');

  $file = "${projectDir}/manualDelivery/anticodons/$file";

  my $args = "--data_file $file --genomeDbName '$genomeDbName' --genomeDbVer '$genomeDbVer'";

  $mgr->runPlugin($signal,
		  "ApiCommonData::Load::Plugin::InsertAntiCodon", $args,
		  "Loading anticodons into dots.RNAType");
}



sub parsedbEST {
  my ($mgr,$ncbiTaxId,$soVer,$restart,$taxonName) = @_;

  my @taxArr = split (/,/,$ncbiTaxId);

  my $propertySet = $mgr->{propertySet};

  my $connect = $propertySet->getProp('dbestConnect');

  my $login = $propertySet->getProp('dbestLogin');

  my $pswd = $propertySet->getProp('dbestPswd');

  my $restart = $restart ? "--restart_number $restart" : "";

  my $taxonId = &getTaxonId($mgr,$ncbiTaxId,$taxonName); #get taxon_id with taxId or taxon name

  my $taxonIdList = &getTaxonIdList($mgr,$taxonId,1); #get entire taxon_id tree

  my $args = "--extDbName dbEST --extDbRlsVer continuous --span 500 --taxon_id_list '$taxonIdList' --soVer $soVer --dbestConnect '$connect' --dbestLogin '$login' --dbestPswd '$pswd'  $restart";

  $mgr->runPlugin("loadDbEst", "GUS::Supported::Plugin::dbEST", $args,
		  "Loading dbEST files into GUS");
}


sub createPsipredDirWithFormattedDb {
  my ($mgr,$dbFile,$dbFileDir,$format) = @_;

  my $propertySet = $mgr->{propertySet};

  my $signal = "${dbFile}PsipredDir";

  return if $mgr->startStep("Creating psipred dir with filtered and formatted $dbFile", $signal); 

  $mgr->runCmd("mkdir -p $mgr->{'dataDir'}/psipred");

  $mgr->runCmd("ln -s  $mgr->{dataDir}/${dbFileDir}/$dbFile  $mgr->{dataDir}/psipred/${dbFile}Ln");

  my $ncbiBlastPath = $propertySet->getProp('ncbiBlastPath');

  my $psipredPath = $propertySet->getProp('psipredPath');

  $mgr->runCmd("${psipredPath}/pfilt $mgr->{dataDir}/psipred/${dbFile}Ln > $mgr->{dataDir}/psipred/${dbFile}Filt");

  if($format){
    $mgr->runCmd("${ncbiBlastPath}/formatdb -i $mgr->{dataDir}/psipred/${dbFile}Filt -p T");

  $mgr->runCmd("rm -f $mgr->{dataDir}/psipred/${dbFile}Filt");
  }

  $mgr->runCmd("rm -f $mgr->{dataDir}/psipred/${dbFile}Ln");

  $mgr->endStep($signal);

}

sub createPsipredSubdir {
  my ($mgr,$queryFile,$dbFile) = @_;

  my $propertySet = $mgr->{propertySet};

  my $signal = "make${queryFile}PsipredSubDir";

  $dbFile = "${dbFile}Filt";

  return if $mgr->startStep("Creating $queryFile subdir in the psipred dir", $signal);

  my $dataDir = $mgr->{'dataDir'};
  my $clusterDataDir = $mgr->{'clusterDataDir'};
  my $nodePath = $propertySet->getProp('nodePath');
  my $nodeClass = $propertySet->getProp('nodeClass');
  my $psipredTaskSize = $propertySet->getProp('psipred.taskSize');
  my $psipredPath = $propertySet->getProp('psipred.clusterpath');
  my $ncbiBinPath = $propertySet->getProp('psipred.ncbibin');

  &makePsipredDir($queryFile, $dbFile, $dataDir, $clusterDataDir,
		  $nodePath, $psipredTaskSize,
		  $psipredPath,
		  $queryFile,"$clusterDataDir/psipred",$dbFile,$nodeClass,$ncbiBinPath);

  $mgr->endStep($signal);
}

sub fixProteinIdsForPsipred{
    my ($mgr,$file,$fileDir) = @_;

    my $propertySet = $mgr->{propertySet};

    my $signal = "fix${file}ForPsipred";

    return if $mgr->startStep("Fixing protein IDs in $file for psipred", $signal);

    my $outputFile = $file;
    $outputFile =~ s/(\S+)\.(\S+)/$1/;
    $outputFile .= "Psipred.".$2;

    my $fix = 's/^(\S+)-(\d)/$1_$2/g';

    my $cmd = "cat $mgr->{dataDir}/${fileDir}/$file | perl -pe '$fix' > $mgr->{dataDir}/${fileDir}/${outputFile}";

  $mgr->runCmd($cmd);

  $mgr->endStep($signal);
}

sub fixPsipredFileNames{
    my ($mgr,$fileDir) = @_;

    my $propertySet = $mgr->{propertySet};

    my $signal = "fixPsipredFileNamesIn${fileDir}";

    return if $mgr->startStep("Fixing protein IDs in psipred result files for $fileDir", $signal);

    $mgr->runCmd("cp -r $mgr->{dataDir}/${fileDir}/master/mainresult $mgr->{dataDir}/${fileDir}/master/mainresultFromPsipred");

    my @files = &_getInputFiles("$mgr->{dataDir}/${fileDir}/master/mainresult");

    foreach my $file (@files){
      my $original = $file;
      $file =~ s/(\S+)_(\d)/$1-$2/g;
      $mgr->runCmd("mv $original $file");
    }

  $mgr->endStep($signal);
}
sub fixIndividualNaSeqFileNames{
    my ($mgr,$fileDir) = @_;

    my $propertySet = $mgr->{propertySet};

    my $signal = "fixIndividualNaSeqFileNamesIn${fileDir}";

    return if $mgr->startStep("Fixing file names in $fileDir", $signal);

    my @files = &_getInputFiles("$mgr->{dataDir}/${fileDir}");

    foreach my $file (@files){
      my $original = $file;
      $file =~ s/\.chr/\_chr/g;
      $mgr->runCmd("mv $original $file");
    }

  $mgr->endStep($signal);
}


sub startPsipredOnComputeCluster {
  my ($mgr,$query,$subject,$queue, $ppn) = @_;

  my $propertySet = $mgr->{propertySet};

  $subject = "${subject}Filt";

  my $signal = "start" . uc($query) . uc($subject);

  return if $mgr->startStep("Starting psipred of $query vs $subject on cluster", $signal);

  $mgr->endStep($signal);

  my $clusterCmdMsg = "runPsipred $mgr->{clusterDataDir} NUMBER_OF_NODES $query $subject $queue $ppn";
  my $clusterLogMsg = "monitor $mgr->{clusterDataDir}/logs/${query}-${subject}.log and xxxxx.xxxx.stdout";

  $mgr->exitToCluster($clusterCmdMsg, $clusterLogMsg, 1);
}

sub makeAlgInv {
  my ($mgr,$algName,$algDesc,$algImpVer,$algInvStart,$algInvEnd,$algResult,$signal) = @_;

  $algName =~ s/\s//g;
  $algName =~ s/\///g;

  my $signal = "$algName${signal}";

  $algResult =~ s/\s/_/g;

  my $args = "--AlgorithmName $algName --AlgorithmDescription $algDesc --AlgImpVersion $algImpVer  --AlgInvocStart $algInvStart --AlgInvocEnd $algInvEnd --AlgInvocResult $algResult";

  $mgr->runPlugin($signal,
		  "GUS::Community::Plugin::InsertMinimalAlgorithmInvocation",$args,
		  "Inserting minimal alg_inv_id for $signal $algName ");
}

sub loadSecondaryStructures {
  my ($mgr, $algName,$algImpVer,$algInvStart,$algInvEnd,$dir,$setPercent,$algInvResult) = @_;

  my $dirPath = "$mgr->{dataDir}/psipred/${dir}/master/mainresult";

  my $args = "--predAlgName $algName --predAlgImpVersion $algImpVer --predAlgInvStart $algInvStart --predAlgInvEnd $algInvEnd --directory $dirPath";

  if($algInvResult){
    $algInvResult =~ s/\s/_/g;
    $args .= " --predAlgInvResult $algInvResult";
  }

  $args .= " --setPercentages" if ($setPercent);

  $mgr->runPlugin("load${dir}SecondaryStructures",
		  "GUS::Supported::Plugin::InsertSecondaryStructure",$args,
                  "Inserting $dir secondary structures from psipred");

}


sub documentHMMPfam {
  my ($mgr,$version) = @_;
  my $description = "Searches HMMs from the PFAM database for significantly similar sequences in the input protein sequence.";
  my $documentation =    { name => "HMMPfam",
                         input => "fasta file of protein sequences and PFAM database",
			   output => "file containing the score and E-value indicating confidence that a query 
                                      sequence contains one or more domains belonging to a domain family",
			   descrip => $description,
                           tools => [{ name => "HMMPfam",
				       version => $version,
				       params => "--A 0 --acc --cut_ga",
				       url => "http://hmmer.wustl.edu",
				       pubmedIds => "",
				       credits => "R. Durbin, S. Eddy, A. Krogh, and G. Mitchison,
                                                  Biological sequence analysis: probabilistic models of proteins and nucleic acids,
                                                  Cambridge University Press, 1998.
                                                  http://hmmer.wustl.edu/"}]};
 $mgr->documentStep("HMMPfAM", $documentation);
}

sub documentPsipred {
  my ($mgr,$version) = @_;

  my $description = "Psipred predicts secondary structure using a neural network analysis of PSI-BLAST output";
  my $documentation =    { name => "psipred",
			   input => "fasta file of protein sequences and a filtered and formatted protein database",
			   output => "file containing a residue by residue prediction of helix, strand, xand coil accompanied by
                                     confidence level",
                           descrip => $description,
                           tools => [{ name => "psipred",
                                       version => $version,
                                       params => "default",
                                       url => "http://bioinf.cs.ucl.ac.uk/psipred/",
                                       pubmedIds => "10493868",
                                       credits => ""}]};
  $mgr->documentStep("psipred", $documentation);
}


sub createRepeatMaskDir {
  my ($mgr, $species, $file, $addOpt, $taskSizeOpt, $repeatMaskSubdir) = @_;

  my $propertySet = $mgr->{propertySet};
  my $signal = "make$species" . ucfirst($file) . "SubDir";

  return if $mgr->startStep("Creating $file repeatmask dir", $signal);

  my $dataDir = $mgr->{'dataDir'};
  my $clusterDataDir = $mgr->{'clusterDataDir'};
  if($repeatMaskSubdir){

    $dataDir .= "/$repeatMaskSubdir";
    $clusterDataDir .= "/$repeatMaskSubdir";
    &_createDir($mgr,$dataDir);
 
  }
  my $nodePath = $propertySet->getProp('nodePath');
  my $nodeClass = $propertySet->getProp('nodeClass');
  my $rmPath = $propertySet->getProp('repeatmask.path');
  my $rmOptions = $propertySet->getProp('repeatmask.options');
  my $dangleMax = $propertySet->getProp('repeatmask.dangleMax');


  my $rmTaskSize = $taskSizeOpt ? $taskSizeOpt : $propertySet->getProp('repeatmask.taskSize');

  $rmOptions .= " $addOpt" if($addOpt);

  my $speciesFile = $species . $file;
  &makeRMDir($speciesFile, $dataDir, $clusterDataDir,
	     $nodePath, $rmTaskSize, $rmOptions, $dangleMax, $rmPath, 
	     $nodeClass);

  $mgr->endStep($signal);
}

sub createRepeatMaskDir_new {
  my ($mgr, $file, $numNodes, $addOpt, $taskSizeOpt, $repeatMaskSubdir) = @_;

  my $propertySet = $mgr->{propertySet};
  my $signal = "make" . ucfirst($file) . "RMDir";

  return if $mgr->startStep("Creating $file repeatmask dir", $signal);

  my $dataDir = $mgr->{'dataDir'};
  my $clusterDataDir = $mgr->{'clusterDataDir'};

  if($repeatMaskSubdir){

    $dataDir .= "/$repeatMaskSubdir";
    $clusterDataDir .= "/$repeatMaskSubdir";
    &_createDir($mgr,$dataDir);
 
  }

  my $nodePath = $propertySet->getProp('nodePath');
  my $nodeClass = $propertySet->getProp('nodeClass');
  my $rmTaskSize = $taskSizeOpt ? $taskSizeOpt : $propertySet->getProp('repeatmask.taskSize');
  my $rmPath = $propertySet->getProp('repeatmask.path');
  my $rmOptions = $propertySet->getProp('repeatmask.options');
  my $dangleMax = $propertySet->getProp('repeatmask.dangleMax');
  my $trimDangling = $propertySet->getProp('repeatmask.trimDangling');

  $rmOptions .= " $addOpt" if($addOpt);

  &makeRMDir($file, $dataDir, $clusterDataDir,
	     $nodePath, $rmTaskSize, $rmOptions, $dangleMax, $rmPath, $nodeClass, $numNodes, $trimDangling);

  $mgr->endStep($signal);
}

sub createGenomeDir {
  my ($mgr, $species, $query, $genome) = @_;
  my $signal = "create$species" . ucfirst($query) . "-" . ucfirst($genome) . "GenomeDir";
  return if $mgr->startStep("Creating ${query}-${genome} genome dir", $signal);

  my $propertySet = $mgr->{propertySet};

  my $dataDir = $mgr->{dataDir};
  my $clusterDataDir = $mgr->{clusterDataDir};
  my $nodePath = $propertySet->getProp('nodePath');
  my $nodeClass = $propertySet->getProp('nodeClass');
  my $gaTaskSize = $propertySet->getProp('genome.taskSize');
  my $gaPath = $propertySet->getProp('genome.path');
  my $gaOptions = $propertySet->getProp('genome.options');
  my $genomeVer = $propertySet->getProp('genome.version');
  my $clusterServer = $propertySet->getProp('clusterServer');
  my $extGDir = $propertySet->getProp('externalDbDir') . '/' . $genomeVer;
  my $srvGDir = $propertySet->getProp('serverExternalDbDir');
  my $genus = $propertySet->getProp('genusNickname');

  $extGDir .= "/$genus/$species";
  $srvGDir .= "/$genus/$species";
  my $speciesQuery = $species . $query;
  my $genomeFile = $species . $genome;
  &makeGenomeDir($speciesQuery, $genome, $dataDir, $clusterDataDir,
    $nodePath, $gaTaskSize, $gaOptions, $gaPath, $genomeFile, $nodeClass);

  $mgr->endStep($signal);
}

sub createGenomeDirForGfClient {
  my ($mgr, $query, $genomeDir,$maxIntron, $numNodes,$noRepMask) = @_;

  my $signal = "create" . ucfirst($query) . "-" . ucfirst($genomeDir) . "GenomeDir";
  return if $mgr->startStep("Creating ${query}-${genomeDir} genome dir", $signal);

  my $propertySet = $mgr->{propertySet};
  my $dataDir = $mgr->{dataDir};
  my $clusterDataDir = $mgr->{clusterDataDir};

  my $nodePath = $propertySet->getProp('nodePath');
  my $nodeClass = $propertySet->getProp('nodeClass');
  my $gaTaskSize = $propertySet->getProp('genome.taskSize');
  my $gaPath = $propertySet->getProp('genome.path');
  my $clusterServer = $propertySet->getProp('clusterServer');
  my $nodePort = $propertySet->getProp('nodePort');

  &makeGenomeDirForGfClient($query, $genomeDir, $dataDir, $clusterDataDir,
    $nodePath, $gaTaskSize, $maxIntron, $gaPath, $nodeClass, $nodePort, $numNodes, $noRepMask);
  $mgr->endStep($signal);
}

sub copyPipelineDirToComputeCluster {
  my ($mgr) = @_;

  my $propertySet = $mgr->{propertySet};

  my $projectDir = $propertySet->getProp('projectDir');
  my $release = $propertySet->getProp('release');
  my $clusterProjectDir = $propertySet->getProp('clusterProjectDir');
  my $clusterReleaseDir = "$clusterProjectDir/$release";
  my $releaseDir = "$projectDir/$release";
  my $signal = "dir2cluster";

  return if $mgr->startStep("Copying analysis_pipeline from $releaseDir to $clusterReleaseDir on clusterServer", $signal);

  #system("ssh -2 consign.pmacs.upenn.edu '/bin/bash -login -c | mkdir -p ($clusterReleaseDir/analysis_pipeline/primary/)'");
  $mgr->{cluster}->copyTo("$projectDir", "$release/analysis_pipeline/primary","$clusterProjectDir");

  #system("ssh -2 consign.pmacs.upenn.edu '/bin/bash -login -c | ln -s $clusterReleaseDir/analysis_pipeline/primary/logs $clusterReleaseDir/analysis_pipeline/primary/data'");

  $mgr->{cluster}->runCmdOnCluster("ln -s $clusterReleaseDir/analysis_pipeline/primary/logs $clusterReleaseDir/analysis_pipeline/primary/data");

  $mgr->endStep($signal);
}
sub moveDownloadFile {
  my ($mgr,$file,$dir) = @_;

  my $propertySet = $mgr->{propertySet};

  my $signal = $file;

  $signal =~ s/\///g;

  $signal = "move" . ucfirst($signal);

 return if $mgr->startStep("Moving $file to $dir", $signal);

  my $projectDir = $propertySet->getProp('projectDir');

  my $release = $propertySet->getProp('release');

  $file = "$projectDir/$release/resources_pipeline/primary/downloads/$file";

  if (! -e $file) { die "$file doesn't exist\n";}

  if ($file =~ /\.gz/) {
    $mgr->runCmd("gunzip -f $file");

    $file =~ s/\.gz//;
  }

  $mgr->runCmd("mkdir -p $mgr->{dataDir}/$dir");

  $mgr->runCmd("mv $file $mgr->{dataDir}/$dir");

  $mgr->endStep($signal);
}

sub moveSeqFile {
  my ($mgr,$file,$dir) = @_;

  my $propertySet = $mgr->{propertySet};

  my $signal = $file;

  $signal =~ s/\///g;

  $signal = "move" . ucfirst($signal);

  return if $mgr->startStep("Moving $file to $dir", $signal);

  my $projectDir = $propertySet->getProp('projectDir');

  my $release = $propertySet->getProp('release');

  my $seqFile = "$mgr->{dataDir}/seqfiles/$file";

  if (! -e $seqFile) { die "$seqFile doesn't exist\n";}

  if ($seqFile =~ /\.gz/) {
    $mgr->runCmd("gunzip -f $seqFile");

    $seqFile =~ s/\.gz//;
  }

  $mgr->runCmd("mkdir -p $mgr->{dataDir}/$dir");

  $mgr->runCmd("mv $seqFile $mgr->{dataDir}/$dir");

  $mgr->endStep($signal);
}

sub renameFile {
  my ($mgr,$fileName,$newName,$dir) = @_;

  my $propertySet = $mgr->{propertySet};

  my $signal = $dir . $fileName;

  $signal =~ s/\///g;

  $signal = "rename" . ucfirst($signal);

  return if $mgr->startStep("Renaming $fileName to $newName in $dir", $signal);

  if (! -e "$mgr->{dataDir}/$dir/$fileName") { die "$fileName doesn't exist\n";};

  $mgr->runCmd("mv  $mgr->{dataDir}/$dir/$fileName $mgr->{dataDir}/$dir/$newName");

  $mgr->endStep($signal);
}

sub copy {
  my ($mgr, $from, $to, $dir, $compress) = @_;
  my $propertySet = $mgr->{propertySet};

  $to =~ s/\/$//;
  $to =~ /([\w|\.]+)$/;

  my $signal = $1;
  $signal = "copy_${from}_To_$1";
  $signal =~ s/\//:/g; 

  return if $mgr->startStep("Copying $from to $to", $signal);

  $mgr->runCmd("mkdir -p $dir") if $dir;
  unless ($from !~ m/\*/ && -e $from) { die "$from doesn't exist\n";};

  $mgr->runCmd("cp -ar  $from $to");
  $mgr->runCmd("gzip $to") if $compress;
  $mgr->endStep($signal);
}

sub copyProteomeFile {
  my ($mgr) = @_;
  my $propertySet = $mgr->{propertySet};

  my $signal = "Copying_proteome";
  return if $mgr->startStep("Copying proteome to seqfiles", $signal);

  my $file = $propertySet->getProp('proteomePath');

  unless (-e $file){die "$file does not exist\n";}

  $mgr->runCmd("cp -a  $file $mgr->{dataDir}/seqfiles/Proteome.fsa");

  $mgr->endStep($signal);
}

sub copyOrthoMCLProteinsFile {
  my ($mgr) = @_;
  my $propertySet = $mgr->{propertySet};

  my $signal = "Copying_orthoMCL_proteins_file";

  return if $mgr->startStep("Copying orthoMCL proteins file to seqfiles", $signal);

  my $file = $propertySet->getProp('orthoProteinsFile');

  unless (-e $file){die "$file does not exist\n";}

  $mgr->runCmd("cp -a  $file $mgr->{dataDir}/seqfiles/ProteinSeqs.fsa");

  $mgr->endStep($signal);
}

sub copyDirectory {
  my ($mgr, $from, $to, $dir) = @_;
  my $propertySet = $mgr->{propertySet};

  $to =~ s/\/$//;
  $to =~ /([\w|\.]+)$/;

  my $signal = $1;
  $signal = "copy_${from}_To_$signal";
  $signal =~ s/\//:/g; 

  return if $mgr->startStep("Copying $from to $to", $signal);

  $mgr->runCmd("mkdir -p $dir") if $dir;
  unless (-e $from) { die "$from doesn't exist\n";};

  $mgr->runCmd("cp -ar  $from $to");
  $mgr->endStep();
}

sub shortenDefLine{
  my ($mgr, $inputFile, $dir) = @_;

  my $outputFile = $inputFile.".fsa";

  my $signal = "shortenNrDefLines";

  return if $mgr->startStep("Shortening DefLines for $inputFile", $signal);

  $mgr->runCmd("shortenDefLine --inputFile $mgr->{dataDir}/$dir/$inputFile --outputFile $mgr->{dataDir}/$dir/$outputFile");
  $mgr->endStep($signal);
}

sub findProteinXRefs {
  my ($mgr, $proteinFile, $nrFile, $nrRegex, $protRegex) = @_;

  my $signal = $proteinFile;
  $signal =~ s/\.\w+$//;
  $signal = "${signal}DbXRefs";

  return if $mgr->startStep("Finding nr cross-refs for $proteinFile", $signal);

  $proteinFile = "$mgr->{dataDir}/seqfiles/$proteinFile";

  $nrFile = "$mgr->{dataDir}/seqfiles/$nrFile";

  my $logFile = "$mgr->{myPipelineDir}/logs/${signal}.log";

  my $outputFile = "$mgr->{dataDir}/misc/${signal}Output";

  my $args = "--proteinFile '$proteinFile' --nrFile '$nrFile' --outputFile '$outputFile' --sourceIdRegex \"$nrRegex\" --protDeflnRegex \"$protRegex\" ";

  $mgr->runCmd("dbXRefBySeqIdentity $args 2>> $logFile");

  $mgr->endStep($signal);
}

sub loadDbXRefs {
  my ($mgr, $proteinFile, $dbList, $NrdbVer) = @_;

  my $outputFile = $proteinFile;
  $outputFile =~ s/\.\w+$//;
  $outputFile = "${outputFile}DbXRefsOutput";


  my $signal = "load$outputFile";

  return if $mgr->startStep("Loading $outputFile", $signal);

  $mgr->runCmd("filterDbXRefOutput --file $mgr->{dataDir}/misc/$outputFile 2>> $mgr->{myPipelineDir}/logs/filter${outputFile}.log");

  my @db = split(/,/, $dbList);

  foreach my $db (@db) {
    my $dbType = $db =~ /gb|emb|dbj/ ? "gb" : $db;

    my $dbName = "NRDB_${dbType}_dbXRefBySeqIdentity";

    unless (-e "$mgr->{dataDir}/misc/${outputFile}_$db"){
      my $log = "$mgr->{myPipelineDir}/logs/load${outputFile}_$db.err";

      open(LOG,">>$log") or die "Can't open log file $log. Reason: $!\n";
      print LOG "$mgr->{dataDir}/misc/${outputFile}_$db does not exist. Skipping...\n";
      close(LOG);

      next;
    }

    &createExtDbAndDbRls($mgr,$dbName,$NrdbVer);

    my $args = "--extDbName $dbName --extDbReleaseNumber $NrdbVer --DbRefMappingFile '$mgr->{dataDir}/misc/${outputFile}_$db' --columnSpec \"secondary_identifier,primary_identifier\"";

    my $subSignal = "load${outputFile}_$db";

    $mgr->runPlugin ($subSignal,
		     "ApiCommonData::Load::Plugin::InsertDBxRefs", "$args",
		     "Loading results of dbXRefBySeqIdentity in ${outputFile}_$db");

    $mgr->runCmd("rm -f $mgr->{dataDir}/misc/${outputFile}_$db");
  }

  $mgr->endStep($signal);
}

sub _getInputFiles{
  my ($fileOrDir, $seqFileExtension) = @_;
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

sub loadEpitopes{
  my ($mgr, $inputDir, $species, $epiExtDbSpecs, $seqExtDbSpecs, $fileExtension, $speciesKey) = @_;

  my $signal = "loadEpitopes${species}";

  return if $mgr->startStep("Loading $inputDir", $signal);

  my @inputFiles;
  @inputFiles = &_getInputFiles($inputDir, $fileExtension);

  foreach my $file (@inputFiles){

    my $args = " --inputFile $file --extDbRelSpec '$epiExtDbSpecs' --seqExtDbRelSpec '$seqExtDbSpecs'";

    my $baseFileName = $file;
    $baseFileName =~ /\/(IEDBExport\S+)\./;
    $baseFileName = $1;
    my $subSignal = "loadEpitopes${baseFileName}$speciesKey";
    $mgr->runPlugin ($subSignal,
		     "ApiCommonData::Load::Plugin::InsertEpitopeFeature",
		     "$args","Loading Epitopes from $file");
  }

  $mgr->endStep($signal);
}

sub createEpitopeMapFiles {
  my ($mgr, $inputDir, $blastDir, $subjectDir, $speciesKey) = @_;

  my $signal = "createEpitopeMapFiles$inputDir$speciesKey";

  return if $mgr->startStep("Creating Epitope files from $inputDir", $signal);

  my $ncbiBlastPath = $mgr->{propertySet}->getProp('ncbiBlastPath');

  $inputDir = "$mgr->{dataDir}/iedb/$inputDir";

  my $queryDir = "$mgr->{dataDir}/iedb/fsa";

  my $outputDir = "$mgr->{dataDir}/iedb/results";

  my $logFile = "$mgr->{myPipelineDir}/logs/${signal}.log";

  my $cmd = "createEpitopeMappingFile --ncbiBlastPath $ncbiBlastPath --inputDir $inputDir --queryDir $queryDir --outputDir $outputDir --blastDatabase $blastDir --subjectPath $subjectDir";
  $cmd .= " --speciesKey $speciesKey" if ($speciesKey);
  $cmd .= " 2>> $logFile";

  $mgr->runCmd($cmd);

  $mgr->endStep($signal);

}


sub extractNaSeq {
  my ($mgr,$dbName,$dbRlsVer,$name,$seqType,$table,$identifier,$ncbiTaxId,$altSql,$taxonHierarchy,$taxonName,$soTermIdsOrNames) = @_;

  my $type = ucfirst($seqType);

  my @dbNames = map{"'$_'"} split (/,/,$dbName);

  my $dbName = join(",", @dbNames);

  my @dbVers = map{"'$_'"} split (/,/,$dbRlsVer);

  my $dbVer = join(",", @dbVers);

  my $signal = "extract${name}$type";

  return if $mgr->startStep("Extracting $name $seqType from GUS", $signal);

  my $outFile = "$mgr->{dataDir}/seqfiles/${name}${type}.fsa";
  my $logFile = "$mgr->{myPipelineDir}/logs/${signal}.log";

  my $sql = <<"EOF";
     SELECT 
        x.$identifier,
        x.description,
        'length='||x.length,
        x.sequence
        FROM dots.$table x, 
             sres.externaldatabase d, 
             sres.externaldatabaserelease dr
        WHERE x.external_database_release_id = dr.external_database_release_id 
              AND dr.external_database_id = d.external_database_id
              AND d.name in ($dbName) 
              AND dr.version in ($dbVer)
EOF

  my $taxonId = &getTaxonId($mgr,$ncbiTaxId,$taxonName) if $ncbiTaxId;

  $taxonId = &getTaxonIdList($mgr,$taxonId,$taxonHierarchy) if $taxonHierarchy;

  $sql .= " and taxon_id in ($taxonId)" if $taxonId;

  my $soIds = &getSoId($mgr,$soTermIdsOrNames);;

   $sql .= " and so_id in ($soIds)" if $soIds;
  

  $sql = $altSql if $altSql;

  my $cmd = "gusExtractSequences --outputFile $outFile --idSQL \"$sql\" --verbose 2>> $logFile";

  $mgr->runCmd($cmd);

  $mgr->endStep($signal);
}

sub extractAnnotatedAndPredictedTranscriptSeq {
  my ($mgr,$dbName,$dbRlsVer,$name,$seqType,$transcriptTable,$primarySeqTable,$identifier) = @_;

  my $type = ucfirst($seqType);

  my $signal = "extract${name}$type";

  return if $mgr->startStep("Extracting $name $seqType from GUS", $signal);

  my $dbRlsId = &getDbRlsId($mgr,$dbName,$dbRlsVer);

  my $outFile = "$mgr->{dataDir}/seqfiles/${name}${type}.fsa";
  my $logFile = "$mgr->{myPipelineDir}/logs/${signal}.log";

  my $sql = my $sql = "select t.$identifier, ss.description,
            'length='||ss.length,ss.sequence
             from DoTS.SplicedNASequence ss,
                  DoTS.$primarySeqTable ns,
                  DoTS.GeneFeature g,
                  DoTs.$transcriptTable t
             where ns.external_database_release_id = $dbRlsId
             and ns.na_sequence_id = g.na_sequence_id
             and g.na_feature_id = t.parent_id
             and t.na_sequence_id = ss.na_sequence_id";

  my $cmd = "gusExtractSequences --outputFile $outFile --idSQL \"$sql\" --verbose 2>> $logFile";

  $mgr->runCmd($cmd);

  $mgr->endStep($signal);
}

sub makeDoTSAssemblyDownloadFile {
  my ($mgr, $species, $name, $ncbiTaxId, $project) = @_;

  my $sql = <<"EOF";
  SELECT  a.source_id
                ||' | organism='||
          replace(tn.name, ' ', '_')
                ||' | number of sequences='||
          a.number_of_contained_sequences
                ||' | length='||
          a.length as defline,
          a.sequence
       FROM dots.assembly a,
            sres.taxonname tn,
            sres.taxon t
      WHERE t.ncbi_tax_id = $ncbiTaxId
        AND t.taxon_id = tn.taxon_id
        AND tn.name_class = 'scientific name'
        AND t.taxon_id = a.taxon_id
     
EOF

    my $fileName = $species . ucfirst($name);

    makeDownloadFile($mgr, $species, $fileName, $sql,$project);

}


sub makeESTDownloadFile {
  my ($mgr, $species, $name, $ncbiTaxId, $dbName, $dbVer, $taxonHierarchy,$project,$taxonName) = @_;

  my $taxonId =  &getTaxonId($mgr,$ncbiTaxId,$taxonName);

  my $taxonIdList = &getTaxonIdList($mgr,$taxonId,$taxonHierarchy);

  my $sql = <<"EOF";
    SELECT x.source_id
           ||' | organism='||
           replace(tn.name, ' ', '_')
           ||' | length='||
           x.length as defline,
           x.sequence
           FROM dots.externalnasequence x,
                sres.taxonname tn,
                sres.taxon t,
                sres.sequenceontology so,
                sres.externaldatabase ed,
                sres.externaldatabaserelease edr
           WHERE t.taxon_id in ($taxonIdList)
            AND t.taxon_id = tn.taxon_id
            AND tn.name_class = 'scientific name'
            AND t.taxon_id = x.taxon_id
            AND x.sequence_ontology_id = so.sequence_ontology_id
            AND so.term_name = '$name'
            AND x.external_database_release_id = edr. external_database_release_id
            AND edr.version = '$dbVer'
            AND edr.external_database_id = ed.external_database_id
            AND ed.name = '$dbName'
EOF

    my $fileName = $species . ucfirst($name);

    makeDownloadFile($mgr, $species, $fileName, $sql,$project);

}

sub makeGSSDownloadFile {
  my ($mgr, $species, $name, $soTerm,$ncbiTaxIdList, $dbName, $dbVer, $project) = @_;

  my $sql = <<"EOF";
    SELECT x.source_id
           ||' | organism='||
           replace(tn.name, ' ', '_')
           ||' | libraryName='||
           l.dbest_name
           ||' | length='||
           x.length as defline,
           x.sequence
           FROM dots.externalnasequence x,
                sres.taxonname tn,
                sres.taxon t,
                sres.sequenceontology so,
                sres.externaldatabase ed,
                sres.externaldatabaserelease edr,
                dots.library l,
                dots.est e
           WHERE t.ncbi_tax_id in ($ncbiTaxIdList)
            AND t.taxon_id = tn.taxon_id
            AND tn.name_class = 'scientific name'
            AND t.taxon_id = x.taxon_id
            AND x.sequence_ontology_id = so.sequence_ontology_id
            AND so.term_name = '$soTerm'
            AND l.library_id = e.library_id
            AND e.na_sequence_id = x.na_sequence_id
            AND x.external_database_release_id = edr. external_database_release_id
            AND edr.version = '$dbVer'
            AND edr.external_database_id = ed.external_database_id
            AND ed.name = '$dbName'
EOF

    my $fileName = $species . ucfirst($name);

    makeDownloadFile($mgr, $species, $fileName, $sql,$project);

}


sub makeAllESTDownloadFile {
  my ($mgr, $species, $name, $project) = @_;

  my $sql = <<"EOF";
    SELECT x.source_id
           ||' | organism='||
           replace(tn.name, ' ', '_')
           ||' | length='||
           x.length as defline,
           x.sequence
           FROM dots.externalnasequence x,
                sres.taxonname tn,
                sres.taxon t,
                sres.sequenceontology so
           WHERE t.taxon_id = tn.taxon_id
            AND tn.name_class = 'scientific name'
            AND t.taxon_id = x.taxon_id
            AND x.sequence_ontology_id = so.sequence_ontology_id
            AND so.term_name = '$name'
EOF

    my $fileName = $species . ucfirst($name);

    makeDownloadFile($mgr, $species, $fileName, $sql,$project);

}



sub makeTranscriptDownloadFile {
    my ($mgr, $species, $name, $extDb, $extDbVer,$seqTable,$dataSource,$genomeExtDb, $genomeExtDbVer,$project) = @_;

    my $signal = "${name}DownloadFile";

    return if $mgr->startStep("Preparing to extract  $name sequences from GUS", $signal);

    my $sql = <<"EOF";
     SELECT '$dataSource'
                ||'|'||
            gf.source_id
                ||' | organism='||
            replace(tn.name, ' ', '_')
                ||' | product='||
            gf.product
                ||' | location='||
            enas.source_id
                ||':'||
            nl.start_min
                ||'-'||
            nl.end_max
                ||'('||
            decode(nl.is_reversed, 1, '-', '+')
                ||') | length='||
            snas.length
            as defline,
            snas.sequence
           FROM dots.ExternalNASequence enas,
                dots.genefeature gf,
                dots.transcript t,
                dots.splicednasequence snas,
                sres.taxonname tn,
                sres.externaldatabase ed,
                sres.externaldatabaserelease edr,
                sres.sequenceontology so,
                dots.nalocation nl
      WHERE gf.na_feature_id = t.parent_id
        AND t.na_sequence_id = snas.na_sequence_id
        AND snas.external_database_release_id = edr.external_database_release_id
        AND gf.na_sequence_id = enas.na_sequence_id
        AND gf.sequence_ontology_id = so.sequence_ontology_id
        AND so.term_name != 'repeat_region'
        AND snas.taxon_id = tn.taxon_id
        AND tn.name_class = 'scientific name'
        AND edr.external_database_id = ed.external_database_id
        AND ed.name = '$extDb' AND edr.version = '$extDbVer'
        AND gf.na_feature_id = nl.na_feature_id
EOF

    if ($genomeExtDb && $genomeExtDbVer) {
      my $genomeDbRls = getDbRlsId($mgr,$genomeExtDb,$genomeExtDbVer);
      $sql .= " and enas.external_database_release_id = $genomeDbRls";
    }

    makeDownloadFile($mgr, $species, $name, $sql,$project);
}


sub makeTranscriptDownloadFileTransformed {
  my ($mgr, $species, $name, $extDbNames, $extDbVers,$dataSource,$project,$deprecated, $ncbiTaxId, $taxonName,$tmpDir,$soTermIdsOrNames) = @_;

  my $signal = "${name}DownloadFile";

  return if $mgr->startStep("Preparing to extract  $name sequences from GUS", $signal);
  
  my $taxonId =  &getTaxonId($mgr,$ncbiTaxId,$taxonName) if ($ncbiTaxId || $taxonName);
  my $soIds =  &getSoId($mgr,$soTermIdsOrNames) if $soTermIdsOrNames;
  
  my @dbNames = map{"'$_'"} split (/,/,$extDbNames);

  my $dbName = join(",", @dbNames);

  my @dbVers = map{"'$_'"} split (/,/,$extDbVers);

  my $dbVer = join(",", @dbVers);

  my $sql = <<"EOF";
     SELECT '$dataSource'
                ||'|'||
            gf.source_id
                || decode(gf.is_deprecated, 1, ' | deprecated=true', '')
                || decode(gf.is_pseudo, 1, ' | is_pseudo=true', '')
                ||' | organism='||
            replace( gf.organism, ' ', '_')
                ||' | product='||
            gf.product
                ||' | location='||
            fl.sequence_source_id
                ||':'||
            fl.start_min
                ||'-'||
            fl.end_max
                ||'('||
            decode(fl.is_reversed, 1, '-', '+')
                ||') | length='||
            snas.length
            as defline,
            snas.sequence
           FROM ApidbTuning.GeneAttributes gf,
                dots.transcript t,
                dots.splicednasequence snas,
	        sres.taxonname tn,
                ApidbTuning.FeatureLocation fl,
                dots.nasequence ns
      WHERE gf.na_feature_id = t.parent_id
        AND gf.na_sequence_id = ns.na_sequence_id
        AND t.na_sequence_id = snas.na_sequence_id
        AND snas.taxon_id = tn.taxon_id
        AND tn.name_class = 'scientific name'
        AND gf.na_feature_id = fl.na_feature_id
        AND gf.so_term_name != 'repeat_region'
        AND gf.external_db_name in ($dbName)
        AND gf.external_db_version in ($dbVer)
        AND fl.is_top_level = 1
        AND gf.is_deprecated = $deprecated
EOF

  $sql .= " and snas.taxon_id in ($taxonId)" if $taxonId;
  $sql .= " and ns.sequence_ontology_id in ($soIds)" if $soIds;

  makeDownloadFile($mgr, $species, $name, $sql,$project,$tmpDir);
}







sub makeRGTranscriptDownloadFile {
  my ($mgr, $species, $name, $extDb, $extDbVer,$seqTable,$dataSource,$dataType,$genomeExtDb, $genomeExtDbVer,$project) = @_;
    
  my $signal = "${name}DownloadFile";

  return if $mgr->startStep("Preparing to extract  $name sequences from GUS", $signal);

  my $sql = <<"EOF";
     SELECT '$dataSource'
                ||'|'||
            gf.source_id
                ||' | organism='||
            replace(tn.name, ' ', '_')
                ||' | product='||
            gf.product
                ||' | location='||
            enas.source_id
                ||':'||
            nl.start_min
                ||'-'||
            nl.end_max
                ||'('||
            decode(nl.is_reversed, 1, '-', '+')
                ||') | length='||
            snas.length
            as defline,
            snas.sequence
           FROM dots.ExternalNASequence enas,
                dots.genefeature gf,
                dots.transcript t,
                dots.splicednasequence snas,
                sres.taxonname tn,
                sres.externaldatabase ed,
                sres.externaldatabaserelease edr,
                sres.sequenceontology so,
                dots.nalocation nl
      WHERE gf.na_feature_id = t.parent_id
        AND t.na_sequence_id = snas.na_sequence_id
        AND snas.external_database_release_id = edr.external_database_release_id
        AND gf.na_sequence_id = enas.na_sequence_id
        AND gf.sequence_ontology_id = so.sequence_ontology_id
        AND so.term_name = 'repeat_region'
        AND snas.taxon_id = tn.taxon_id
        AND tn.name_class = 'scientific name'
        AND edr.external_database_id = ed.external_database_id
        AND ed.name = '$extDb' AND edr.version = '$extDbVer'
        AND gf.na_feature_id = nl.na_feature_id
EOF

  if ($genomeExtDb && $genomeExtDbVer) {
    my $genomeDbRls = getDbRlsId($mgr,$genomeExtDb,$genomeExtDbVer);
    $sql .= " and enas.external_database_release_id = $genomeDbRls";
  }

  makeDownloadFile($mgr, $species, $name, $sql,$project);
}

sub makeInterproDownloadFile {
  my ($mgr, $species, $name, $genomeExtDb, $genomeExtDbVer, $interproExtDb, $interproExtDbVer, $projectDB, $strain,$ncbiTaxId, $taxonName, $soTermIdsOrNames) = @_;

  my $signal = "${species}${name}DownloadFile";
  $signal = "${strain}${name}DownloadFile" if $strain;

  return if $mgr->startStep("Extracting $species Interpro results from GUS", $signal);

  my $propertySet = $mgr->{propertySet};
  my $release = $propertySet->getProp('projectRelease');

  my $siteFileDir = $propertySet->getProp('siteFileDir');

  my $taxonId =  &getTaxonId($mgr,$ncbiTaxId,$taxonName) if ($ncbiTaxId || $taxonName);
  my $soIds = &getSoId($mgr,$soTermIdsOrNames) if ($soTermIdsOrNames);

  my @dbNames = map{"'$_'"} split (/,/,$genomeExtDb);

  my $dbName = join(",", @dbNames);

  my @dbVers = map{"'$_'"} split (/,/,$genomeExtDbVer);

  my $dbVer = join(",", @dbVers);

  my $dlDir = "$siteFileDir/downloadSite/$projectDB/release-$release/$species";

  $mgr->runCmd("mkdir -p $dlDir");

  die "Failed to create $dlDir.\n"  unless (-e $dlDir);

  my $outFile = "$dlDir/${species}${name}_$projectDB-${release}.txt";

  $outFile = "$dlDir/${strain}${name}_$projectDB-${release}.txt" if $strain;

  (-e $outFile) and die "'$outFile' already exists. Remove it before running this step.\n";

  my $logFile = "$mgr->{myPipelineDir}/logs/${signal}.log";

  my $sql = <<"EOF";
  SELECT gf.source_id
           || chr(9) ||
         xd1.name
           || chr(9) ||
         dr.primary_identifier
           || chr(9) ||
         dr.secondary_identifier
           || chr(9) ||
         al.start_min
           || chr(9) ||
         al.end_min
           || chr(9) ||
         to_char(df.e_value,'9.9EEEE')
  FROM
    dots.aalocation al,
    sres.externaldatabaserelease xdr1,
    sres.externaldatabase xd1,
    sres.externaldatabaserelease xdr2,
    sres.externaldatabase xd2,
    sres.externaldatabaserelease xdr3,
    sres.externaldatabase xd3,
    sres.dbref dr,
    dots.DbRefAAFeature draf, 
    dots.domainfeature df, 
    dots.genefeature gf,
    dots.transcript t, 
    dots.translatedaafeature taf,
    sres.taxonname tn,
    dots.translatedaasequence tas,
    dots.nasequence ns 
  WHERE
   gf.external_database_release_id = xdr2.external_database_release_id 
     AND xdr2.version in ($dbVer) 
     AND xdr2.external_database_id = xd2.external_database_id 
     AND xd2.name in ($dbName)
     AND gf.na_feature_id = t.parent_id 
     AND gf.na_sequence_id = ns.na_sequence_id
     AND t.na_feature_id = taf.na_feature_id 
     AND taf.aa_sequence_id = tas.aa_sequence_id 
     AND tas.aa_sequence_id = df.aa_sequence_id 
     AND tas.taxon_id = tn.taxon_id
     AND tn.name_class = 'scientific name'
     AND df.aa_feature_id = draf.aa_feature_id  
     AND draf.db_ref_id = dr.db_ref_id 
     AND dr.external_database_release_id = xdr1.external_database_release_id 
     AND xdr1.external_database_id = xd1.external_database_id 
     AND df.aa_feature_id = al.aa_feature_id 
     AND df.external_database_release_id = xdr3.external_database_release_id 
     AND xdr3.version = '$interproExtDbVer' 
     AND xdr3.external_database_id = xd3.external_database_id 
     AND xd3.name = '$interproExtDb'
EOF
  $sql .= " and tas.taxon_id in ($taxonId)" if $taxonId;

  $sql .= " and ns.sequence_ontology_id in ($soIds)" if $soIds;

   if ($projectDB =~ /ortho/i) {

     $outFile = "$dlDir/iprscan_$projectDB-${release}.txt";

     $sql = <<"EOF";
     SELECT xas.secondary_identifier
           || chr(9) ||
         xd.name
           || chr(9) ||
         dr.primary_identifier
           || chr(9) ||
         dr.secondary_identifier
           || chr(9) ||
         al.start_min
           || chr(9) ||
         al.end_min
           || chr(9) ||
         to_char(df.e_value,'9.9EEEE')
  FROM
    dots.aalocation al,
    sres.externaldatabaserelease xdr,
    sres.externaldatabase xd,
    sres.dbref dr,
    dots.DbRefAAFeature draf,
    dots.domainfeature df,
    dots.externalaasequence xas
  WHERE
     xas.aa_sequence_id = df.aa_sequence_id
     AND df.aa_feature_id = al.aa_feature_id
     AND df.aa_feature_id = draf.aa_feature_id
     AND draf.db_ref_id = dr.db_ref_id
     AND df.external_database_release_id = xdr.external_database_release_id
     AND xdr.external_database_id = xd.external_database_id
     AND xdr.version = '$interproExtDbVer'
     AND xd.name = '$interproExtDb'
EOF
   }

  my $cmd = "makeFileWithSql --outFile $outFile --sql \"$sql\" 2>> $logFile";

  $mgr->runCmd($cmd);

  #$mgr->runCmd("gzip $outFile");

  $mgr->endStep($signal);
}

sub makeOrthoResourceFile {
  my ($mgr) = @_;

  my $signal = "orthoResourceFile";

  return if $mgr->startStep("Creating file of ortho resources for download site", $signal);

  my $propertySet = $mgr->{propertySet};
  my $release = $propertySet->getProp('projectRelease');
  my $projectDB = $propertySet->getProp('projectDB');

  my $project = ucfirst($projectDB);

  my $siteFileDir = $propertySet->getProp('siteFileDir');

  my $dlDir = "$siteFileDir/downloadSite/$project/release-$release";

  $mgr->runCmd("mkdir -p $dlDir");

  die "Failed to create $dlDir.\n"  unless (-e $dlDir);

  my $outFile = "${dlDir}/data_sources_OrthoMCL-${release}.txt";

  my $logFile = "$mgr->{myPipelineDir}/logs/${signal}.log";

  my $sql = <<"EOF";
     SELECT
          ot.three_letter_abbrev
                || chr(9) ||
          t.ncbi_tax_id
                || chr(9) ||
          ot.name
                || chr(9) ||
          r.resource_url
     FROM
        apidb.orthomcltaxon ot,
        sres.taxon t, 
        apidb.orthomclresource r
    WHERE
        ot.is_species = 1
        AND ot.orthomcl_taxon_id = r.orthomcl_taxon_id
        AND ot.taxon_id = t.taxon_id
EOF

  my $cmd = "makeFileWithSql --outFile $outFile --sql \"$sql\" 2>> $logFile";

  $mgr->runCmd($cmd);

  $mgr->runCmd("gzip $outFile");

  $mgr->endStep($signal);
}

sub makeCdsDownloadFile {
  my ($mgr, $species, $name, $extDb, $extDbVer) = @_;

  my $sql = <<"EOF";
    SELECT  replace(tn.name, ' ', '_')
                ||'|'||
            enas.source_id
                ||'|'||
            gf.source_id
                ||'|'||
            'Annotation'
                ||'|'||
            'GenBank'
                ||'|'||
            '(protein coding) ' || gf.product as defline,
            SUBSTR(snas.sequence, 
              taaf.translation_start,
              taaf.translation_stop)
       FROM dots.externalnasequence enas,
            dots.genefeature gf,
            dots.transcript t,
            dots.SplicedNaSequence snas,
            dots.translatedaafeature taaf,
            sres.taxonname tn,
            sres.sequenceontology so,
            sres.externaldatabase ed,
            sres.externaldatabaserelease edr
      WHERE gf.na_feature_id = t.parent_id
        AND t.na_sequence_id = snas.na_sequence_id
        AND t.na_feature_id = taaf.na_feature_id
        AND snas.SEQUENCE_ONTOLOGY_ID = so.sequence_ontology_id
        AND so.term_name = 'processed_transcript'
        AND snas.external_database_release_id = edr.external_database_release_id
        AND gf.na_sequence_id = enas.na_sequence_id 
        AND snas.taxon_id = tn.taxon_id
        AND tn.name_class = 'scientific name'
        AND edr.external_database_id = ed.external_database_id
        AND ed.name = '$extDb' AND edr.version = '$extDbVer'
EOF

  makeDownloadFile($mgr, $species, $name, $sql);

}

sub makeDerivedCdsDownloadFile {
  my ($mgr, $species, $name, $extDb, $extDbVer,$seqTable,$dataSource, $project) = @_;

  my $sql = <<"EOF";
     SELECT '$dataSource'
                ||'|'||
            gf.source_id
                ||' | organism='||
            replace(tn.name, ' ', '_')
                ||' | product='||
            gf.product
                ||' | location='||
            enas.source_id
                ||':'||
            (nl.start_min + taaf.translation_start - 1)
                ||'-'||
            (nl.end_max - (snas.length - taaf.translation_stop))
                ||'('||
            decode(nl.is_reversed, 1, '-', '+')
                ||') | length='||
            (taaf.translation_stop - taaf.translation_start + 1)
            as defline,
           SUBSTR(snas.sequence,
                  taaf.translation_start,
                  taaf.translation_stop - taaf.translation_start + 1)
           FROM dots.ExternalNASequence enas,
                dots.genefeature gf,
                dots.transcript t,
                dots.splicednasequence snas,
                sres.taxonname tn,
                sres.externaldatabase ed,
                sres.externaldatabaserelease edr,
                sres.sequenceontology so,
                dots.nalocation nl,
                dots.translatedaafeature taaf
      WHERE gf.na_feature_id = t.parent_id
        AND t.na_sequence_id = snas.na_sequence_id
        AND snas.external_database_release_id = edr.external_database_release_id
        AND gf.na_sequence_id = enas.na_sequence_id
        AND gf.sequence_ontology_id = so.sequence_ontology_id
        AND so.term_name != 'repeat_region'
        AND so.term_name = 'protein_coding'
        AND snas.taxon_id = tn.taxon_id
        AND tn.name_class = 'scientific name'
        AND edr.external_database_id = ed.external_database_id
        AND ed.name = '$extDb' AND edr.version = '$extDbVer'
        AND gf.na_feature_id = nl.na_feature_id
        AND t.na_feature_id = taaf.na_feature_id
EOF

  makeDownloadFile($mgr, $species, $name, $sql,$project);

}


sub makeDerivedCdsDownloadFileTransformed {
  my ($mgr, $species, $name, $extDbNames, $extDbVers,$dataSource, $project, $deprecated,$ncbiTaxId, $taxonName,$tmpDir,$soTermIdsOrNames) = @_;

  my $signal = "${name}DownloadFile";

  return if $mgr->startStep("Preparing to extract  $name sequences from GUS", $signal);

  my $taxonId =  &getTaxonId($mgr,$ncbiTaxId,$taxonName) if ($ncbiTaxId || $taxonName);

  my $soIds  =   &getSoId($mgr,$soTermIdsOrNames) if $soTermIdsOrNames;

  my @dbNames = map{"'$_'"} split (/,/,$extDbNames);

  my $dbName = join(",", @dbNames);

  my @dbVers = map{"'$_'"} split (/,/,$extDbVers);

  my $dbVer = join(",", @dbVers);

  my $sql = <<"EOF";
     SELECT '$dataSource'
                ||'|'||
            gf.source_id
                || decode(gf.is_deprecated, 1, ' | deprecated=true', '')
                || decode(gf.is_pseudo, 1, ' | is_pseudo=true', '')
                ||' | organism='||
           replace( gf.organism, ' ', '_') 
                ||' | product='||
            gf.product
                ||' | location='||
            fl.sequence_source_id
                ||':'||
            (fl.start_min + taaf.translation_start - 1)
                ||'-'||
            (fl.end_max - (snas.length - taaf.translation_stop))
                ||'('||
            decode(fl.is_reversed, 1, '-', '+')
                ||') | length='||
            (taaf.translation_stop - taaf.translation_start + 1)
            as defline,
           SUBSTR(snas.sequence,
                  taaf.translation_start,
                  taaf.translation_stop - taaf.translation_start + 1)
           FROM ApidbTuning.FeatureLocation fl,
                ApidbTuning.GeneAttributes gf,
                dots.transcript t,
                dots.splicednasequence snas,
	        sres.taxonname tn,
                dots.translatedaafeature taaf,
                dots.nasequence ns
      WHERE gf.na_feature_id = t.parent_id
        AND t.na_sequence_id = snas.na_sequence_id
        AND gf.na_sequence_id = ns.na_sequence_id
        AND snas.taxon_id = tn.taxon_id
        AND tn.name_class = 'scientific name'
        AND gf.na_feature_id = fl.na_feature_id
        AND gf.so_term_name != 'repeat_region'
        AND gf.so_term_name = 'protein_coding'
        AND gf.external_db_name in ($dbName) 
        AND gf.external_db_version in ($dbVer)
        AND t.na_feature_id = taaf.na_feature_id
        AND fl.is_top_level = 1
        AND gf.is_deprecated = $deprecated
EOF

  $sql .= " and snas.taxon_id in ($taxonId)" if $taxonId;

  $sql .= " and ns.sequence_ontology_id in ($soIds)" if $soIds;

  makeDownloadFile($mgr, $species, $name, $sql,$project,$tmpDir);

}

sub makeRGDerivedCdsDownloadFile {
  my ($mgr, $species, $name, $extDb, $extDbVer,$seqTable,$dataSource, $project) = @_;

  my $signal = "${name}DownloadFile";

  return if $mgr->startStep("Preparing to extract  $name sequences from GUS", $signal);


  my $sql = <<"EOF";
     SELECT '$dataSource'
                ||'|'||
            gf.source_id
                ||' | organism='||
            replace(tn.name, ' ', '_')
                ||' | product='||
            gf.product
                ||' | location='||
            enas.source_id
                ||':'||
            (nl.start_min + taaf.translation_start - 1)
                ||'-'||
            (nl.end_max - (snas.length - taaf.translation_stop))
                ||'('||
            decode(nl.is_reversed, 1, '-', '+')
                ||') | length='||
            (taaf.translation_stop - taaf.translation_start + 1)
            as defline,
           SUBSTR(snas.sequence,
                  taaf.translation_start,
                  taaf.translation_stop - taaf.translation_start + 1)
           FROM dots.ExternalNASequence enas,
                dots.genefeature gf,
                dots.transcript t,
                dots.splicednasequence snas,
                sres.taxonname tn,
                sres.externaldatabase ed,
                sres.externaldatabaserelease edr,
                sres.sequenceontology so,
                dots.nalocation nl,
                dots.translatedaafeature taaf
      WHERE gf.na_feature_id = t.parent_id
        AND t.na_sequence_id = snas.na_sequence_id
        AND snas.external_database_release_id = edr.external_database_release_id
        AND gf.na_sequence_id = enas.na_sequence_id
        AND gf.sequence_ontology_id = so.sequence_ontology_id
        AND so.term_name = 'repeat_region'
        AND snas.taxon_id = tn.taxon_id
        AND tn.name_class = 'scientific name'
        AND edr.external_database_id = ed.external_database_id
        AND ed.name = '$extDb' AND edr.version = '$extDbVer'
        AND gf.na_feature_id = nl.na_feature_id
        AND t.na_feature_id = taaf.na_feature_id
EOF

  makeDownloadFile($mgr, $species, $name, $sql,$project);

}

sub makeAnnotatedProteinDownloadFileForncbiBlast {
    my ($mgr, $species, $name, $extDb, $extDbVer,$seqTable,$dataSource) = @_;

    my $sql = <<"EOF";
    SELECT replace(tn.name, ' ', '_')
        ||'|'||
    enas.source_id
        ||'|'||
    gf.source_id
        ||'|'||
    'Annotation'
        ||'|'||
    '$dataSource'
        ||'|'||
    '(protein coding) ' || taas.description as defline,
    taas.sequence
       FROM dots.$seqTable enas,
            dots.genefeature gf,
            dots.transcript t,
            dots.translatedaafeature taaf,
            dots.translatedaasequence taas,
            sres.taxonname tn,
            sres.externaldatabase ed,
            sres.externaldatabaserelease edr
      WHERE t.na_feature_id = taaf.na_feature_id
        AND gf.na_feature_id = t.parent_id
        AND taaf.aa_sequence_id = taas.aa_sequence_id
        AND enas.na_sequence_id = gf.na_sequence_id 
        AND taas.taxon_id = tn.taxon_id
        AND tn.name_class = 'scientific name'
        AND t.external_database_release_id = edr.external_database_release_id
        AND edr.external_database_id = ed.external_database_id
        AND ed.name = '$extDb' AND edr.version = '$extDbVer'
EOF
  
  my $signal = "${name}NcbiBlastDownloadFile";

  return if $mgr->startStep("Extracting $name sequences from GUS", $signal);

  my $propertySet = $mgr->{propertySet};
  my $release = $propertySet->getProp('release');
  my $projectDB = $propertySet->getProp('projectDB');
  my $projectDir = $propertySet->getProp('projectDir');
  my $seqFile = "$mgr->{dataDir}/blastSite/${name}_$projectDB-${release}.fasta";

  (-e $seqFile) and die "'$seqFile' already exists. Remove it before running this step.\n";

  my $logFile = "$mgr->{myPipelineDir}/logs/${signal}DownloadFile.log";

  my $cmd = <<"EOF";
      gusExtractSequences --outputFile $seqFile \\
      --idSQL \"$sql\" \\
      --verbose 2>> $logFile
EOF

  $mgr->runCmd($cmd);
  $mgr->endStep($signal);
}

sub makeAnnotatedProteinDownloadFile {
  my ($mgr, $species, $name, $extDb, $extDbVer,$seqTable,$dataSource,$project) = @_;

  my $sql = <<"EOF";
     SELECT '$dataSource'
                ||'|'||
            gf.source_id
                ||' | organism='||
            replace(tn.name, ' ', '_')
                ||' | product='||
            gf.product
                ||' | location='||
            enas.source_id
                ||':'||
            (nl.start_min + taaf.translation_start - 1)
                ||'-'||
            (nl.end_max - (snas.length - taaf.translation_stop))
                ||'('||
            decode(nl.is_reversed, 1, '-', '+')
                ||') | length='||
            taas.length
            as defline,
            taas.sequence
           FROM dots.ExternalNASequence enas,
                dots.genefeature gf,
                dots.transcript t,
                dots.splicednasequence snas,
                sres.taxonname tn,
                sres.externaldatabase ed,
                sres.externaldatabaserelease edr,
                sres.sequenceontology so,
                dots.nalocation nl,
                dots.translatedaafeature taaf,
                dots.translatedaasequence taas
      WHERE gf.na_feature_id = t.parent_id
        AND t.na_sequence_id = snas.na_sequence_id
        AND snas.external_database_release_id = edr.external_database_release_id
        AND gf.na_sequence_id = enas.na_sequence_id
        AND gf.sequence_ontology_id = so.sequence_ontology_id
        AND so.term_name != 'repeat_region'
        AND so.term_name = 'protein_coding'
        AND snas.taxon_id = tn.taxon_id
        AND tn.name_class = 'scientific name'
        AND edr.external_database_id = ed.external_database_id
        AND ed.name = '$extDb' AND edr.version = '$extDbVer'
        AND gf.na_feature_id = nl.na_feature_id
        AND t.na_feature_id = taaf.na_feature_id
        AND taaf.aa_sequence_id = taas.aa_sequence_id
EOF

  makeDownloadFile($mgr, $species, $name, $sql,$project);

}


sub makeAnnotatedProteinDownloadFileTransformed {
  my ($mgr, $species, $name, $extDbNames, $extDbVers,$dataSource,$project,$deprecated,$ncbiTaxId,$taxonName,$tmpDir,$soTermIdsOrNames) = @_;

  my $signal = "${name}DownloadFile";

  return if $mgr->startStep("Preparing to extract  $name sequences from GUS", $signal);

  my $taxonId =  &getTaxonId($mgr,$ncbiTaxId,$taxonName) if ($ncbiTaxId || $taxonName);

  my $soIds = &getSoId($mgr,$soTermIdsOrNames) if ($soTermIdsOrNames);

  my @dbNames = map{"'$_'"} split (/,/,$extDbNames);

  my $dbName = join(",", @dbNames);

  my @dbVers = map{"'$_'"} split (/,/,$extDbVers);

  my $dbVer = join(",", @dbVers);

  my $sql = <<"EOF";
     SELECT '$dataSource'
                ||'|'||
            gf.source_id
                || decode(gf.is_deprecated, 1, ' | deprecated=true', '')
                || decode(gf.is_pseudo, 1, ' | is_pseudo=true', '')
                ||' | organism='||
             replace( gf.organism, ' ', '_')
                ||' | product='||
            gf.product
                ||' | location='||
            fl.sequence_source_id
                ||':'||
            (fl.start_min + taaf.translation_start - 1)
                ||'-'||
            (fl.end_max - (snas.length - taaf.translation_stop))
                ||'('||
            decode(fl.is_reversed, 1, '-', '+')
                ||') | length='||
            taas.length
            as defline,
            taas.sequence
           FROM ApidbTuning.FeatureLocation fl,
                ApidbTuning.GeneAttributes gf,
                dots.transcript t,
                dots.splicednasequence snas,
                dots.translatedaafeature taaf,
	        sres.taxonname tn,
                dots.translatedaasequence taas,
                dots.nasequence ns
      WHERE gf.na_feature_id = t.parent_id
        AND gf.na_sequence_id = ns.na_sequence_id
        AND t.na_sequence_id = snas.na_sequence_id
        AND snas.taxon_id = tn.taxon_id
        AND tn.name_class = 'scientific name'
        AND gf.na_feature_id = fl.na_feature_id
        AND gf.so_term_name != 'repeat_region'
        AND gf.so_term_name = 'protein_coding'
        AND gf.external_db_name in ($dbName) AND gf.external_db_version in ($dbVer)
        AND t.na_feature_id = taaf.na_feature_id
        AND taaf.aa_sequence_id = taas.aa_sequence_id
        AND fl.is_top_level = 1
        AND gf.is_deprecated = $deprecated
EOF

  $sql .= " and snas.taxon_id in ($taxonId)" if $taxonId;

  $sql .= " and ns.sequence_ontology_id in ($soIds)" if $soIds;

  makeDownloadFile($mgr, $species, $name, $sql,$project,$tmpDir);

}



sub makeRGAnnotatedProteinDownloadFile {
  my ($mgr, $species, $name, $extDb, $extDbVer,$seqTable,$dataSource,$project) = @_;

  my $sql = <<"EOF";
     SELECT '$dataSource'
                ||'|'||
            gf.source_id
                ||' | organism='||
            replace(tn.name, ' ', '_')
                ||' | product='||
            gf.product
                ||' | location='||
            enas.source_id
                ||':'||
            (nl.start_min + taaf.translation_start - 1)
                ||'-'||
            (nl.end_max - (snas.length - taaf.translation_stop))
                ||'('||
            decode(nl.is_reversed, 1, '-', '+')
                ||') | length='||
            taas.length
            as defline,
            taas.sequence
           FROM dots.ExternalNASequence enas,
                dots.genefeature gf,
                dots.transcript t,
                dots.splicednasequence snas,
                sres.taxonname tn,
                sres.externaldatabase ed,
                sres.externaldatabaserelease edr,
                sres.sequenceontology so,
                dots.nalocation nl,
                dots.translatedaafeature taaf,
                dots.translatedaasequence taas
      WHERE gf.na_feature_id = t.parent_id
        AND t.na_sequence_id = snas.na_sequence_id
        AND snas.external_database_release_id = edr.external_database_release_id
        AND gf.na_sequence_id = enas.na_sequence_id
        AND gf.sequence_ontology_id = so.sequence_ontology_id
        AND so.term_name = 'repeat_region'
        AND snas.taxon_id = tn.taxon_id
        AND tn.name_class = 'scientific name'
        AND edr.external_database_id = ed.external_database_id
        AND ed.name = '$extDb' AND edr.version = '$extDbVer'
        AND gf.na_feature_id = nl.na_feature_id
        AND t.na_feature_id = taaf.na_feature_id
        AND taaf.aa_sequence_id = taas.aa_sequence_id
EOF

  makeDownloadFile($mgr, $species, $name, $sql,$project);

}

sub makeOrfProteinDownloadFile {
  my ($mgr, $species, $name, $extDb, $extDbVer, $length, $projectDB,$ncbiTaxId,$taxonHierarchy,$taxonName) = @_;

  my $taxonId =  &getTaxonId($mgr,$ncbiTaxId,$taxonName);

  my $taxonIdList = &getTaxonIdList($mgr,$taxonId,$taxonHierarchy);

  my $sql = <<"EOF";
    SELECT
    replace(tn.name, ' ', '_') 
        ||'|'||
    enas.source_id
        ||'|'||
    taas.source_id 
        ||'|'||
    'computed'
        ||'|'||
    '$projectDB'
        ||'|'||
    'length=' || taas.length || taas.description as defline,
    taas.sequence
       FROM dots.externalNASequence enas,
            dots.transcript t,
            dots.translatedaafeature taaf,
            dots.translatedaasequence taas,
            sres.taxonname tn,
            sres.sequenceontology so,
            sres.externaldatabase ed,
            sres.externaldatabaserelease edr
      WHERE t.na_feature_id = taaf.na_feature_id
        AND taaf.aa_sequence_id = taas.aa_sequence_id
        AND enas.na_sequence_id = t.na_sequence_id 
        AND enas.taxon_id = tn.taxon_id
        AND tn.name_class = 'scientific name'
        AND t.sequence_ontology_id = so.sequence_ontology_id
        AND so.term_name = 'ORF'
        AND taas.length > $length
        AND t.external_database_release_id = edr.external_database_release_id
        AND edr.external_database_id = ed.external_database_id
        AND ed.name = '$extDb' AND edr.version = '$extDbVer'
EOF

  makeDownloadFile($mgr, $species, $name, $sql);
}

sub makeOrfDownloadFileWithAbrevDefline {
  my ($mgr, $species, $name, $extDb, $extDbVer, $length,$project, $ncbiTaxId, $taxonHierarchy,$taxonName) = @_;

  my $taxonId =  &getTaxonId($mgr,$ncbiTaxId,$taxonName) if ($ncbiTaxId || $taxonName);

  $taxonId = &getTaxonIdList($mgr,$taxonId,$taxonHierarchy) if $taxonHierarchy;

  my @extDbs = map{"'$_'"} split (/,/,$extDb);

  my $extDb = join(",", @extDbs);

  my @extDbVers = map{"'$_'"} split (/,/,$extDbVer);

  my $extDbVer = join(",", @extDbVers);
 

  my $sql = <<"EOF";
    SELECT
       m.source_id
        ||' | organism='||
       replace(tn.name, ' ', '_')
        ||' | location='||
       enas.source_id
        ||':'||
       nl.start_min
        ||'-'||
       nl.end_max
        ||'('||
       decode(nl.is_reversed, 1, '-', '+')
        ||') | length='||
       taas.length as defline,
       taas.sequence
       FROM dots.NASequence enas,
            dots.miscellaneous m,
            dots.nalocation nl,
            dots.translatedaafeature taaf,
            dots.translatedaasequence taas,
            sres.taxonname tn,
            sres.sequenceontology so,
            sres.externaldatabase ed,
            sres.externaldatabaserelease edr
      WHERE m.na_feature_id = taaf.na_feature_id
        AND m.na_feature_id = nl.na_feature_id
        AND taaf.aa_sequence_id = taas.aa_sequence_id
        AND enas.na_sequence_id = m.na_sequence_id 
        AND enas.taxon_id = tn.taxon_id
        AND tn.name_class = 'scientific name'
        AND m.sequence_ontology_id = so.sequence_ontology_id
        AND so.term_name = 'ORF'
        AND taas.length >= $length
        AND m.external_database_release_id = edr.external_database_release_id
        AND edr.external_database_id = ed.external_database_id
        AND ed.name in ($extDb) AND edr.version in ($extDbVer)
EOF

  $sql .= " and enas.taxon_id in ($taxonId)";

  makeDownloadFile($mgr, $species, $name, $sql,$project);

}


sub makeOrfDownloadFileWithAbrevDeflineTransformed {
  my ($mgr, $species, $name, $extDbNames, $extDbVers, $length,$project,,$ncbiTaxId, $taxonName,$tmpDir,$soTermIdsOrNames) = @_;

  my $signal = "${name}DownloadFile";

  return if $mgr->startStep("Preparing to extract  $name sequences from GUS", $signal);

  my $taxonId =  &getTaxonId($mgr,$ncbiTaxId,$taxonName) if ($ncbiTaxId || $taxonName);
  my $soIds = &getSoId($mgr,$soTermIdsOrNames) if ($soTermIdsOrNames);

  my @dbNames = map{"'$_'"} split (/,/,$extDbNames);

  my $dbName = join(",", @dbNames);

  my @dbVers = map{"'$_'"} split (/,/,$extDbVers);

  my $dbVer = join(",", @dbVers);

  my $sql = <<"EOF";
    SELECT
       m.source_id
        ||' | organism='||
       replace(tn.name, ' ', '_')
        ||' | location='||
       fl.sequence_source_id
        ||':'||
       fl.start_min
        ||'-'||
       fl.end_max
        ||'('||
       decode(fl.is_reversed, 1, '-', '+')
        ||') | length='||
       taas.length as defline,
       taas.sequence
       FROM dots.miscellaneous m,
            dots.translatedaafeature taaf,
            dots.translatedaasequence taas,
            sres.taxonname tn,
            sres.sequenceontology so,
            sres.externaldatabase ed,
            sres.externaldatabaserelease edr,
            ApidbTuning.FeatureLocation fl,
            dots.nasequence enas
      WHERE m.na_feature_id = taaf.na_feature_id
        AND taaf.aa_sequence_id = taas.aa_sequence_id
        AND m.na_feature_id = fl.na_feature_id
        AND fl.is_top_level = 1
        AND enas.na_sequence_id = fl.na_sequence_id 
        AND enas.taxon_id = tn.taxon_id
        AND tn.name_class = 'scientific name'
        AND m.sequence_ontology_id = so.sequence_ontology_id
        AND so.term_name = 'ORF'
        AND taas.length >= $length
        AND m.external_database_release_id = edr.external_database_release_id
        AND edr.external_database_id = ed.external_database_id
        AND ed.name in ($dbName) AND edr.version in ($dbVer)
EOF
  $sql .= " and enas.taxon_id in ($taxonId)" if $taxonId;
 
  $sql .= " and enas.sequence_ontology_id in ($soIds)" if $soIds;

  makeDownloadFile($mgr, $species, $name, $sql,$project,$tmpDir);

}


sub makeOrfNaDownloadFileWithAbrevDeflineTransformed {
  my ($mgr, $species, $name, $extDbNames, $extDbVers, $length,$project,,$ncbiTaxId, $taxonName,$tmpDir,$soTermIdsOrNames) = @_;

  my $signal = "${name}DownloadFile";

  return if $mgr->startStep("Preparing to extract  $name sequences from GUS", $signal);

  my $taxonId =  &getTaxonId($mgr,$ncbiTaxId,$taxonName) if ($ncbiTaxId || $taxonName);

  my $soIds = &getSoId($mgr,$soTermIdsOrNames) if ($soTermIdsOrNames);

  my @dbNames = map{"'$_'"} split (/,/,$extDbNames);

  my $dbName = join(",", @dbNames);

  my @dbVers = map{"'$_'"} split (/,/,$extDbVers);

  my $dbVer = join(",", @dbVers);

  my $sql = <<"EOF";
    SELECT
       m.source_id
        ||' | organism='||
       replace(tn.name, ' ', '_')
        ||' | location='||
       fl.sequence_source_id
        ||':'||
       fl.start_min
        ||'-'||
       fl.end_max
        ||'('||
       decode(fl.is_reversed, 1, '-', '+')
        ||') | length='||
       (fl.end_max - fl.start_min + 1 ) as defline,
       decode(fl.is_reversed,1, apidb.reverse_complement_clob(SUBSTR(enas.sequence,fl.start_min,fl.end_max - fl.start_min +1)),SUBSTR(enas.sequence,fl.start_min,fl.end_max - fl.start_min + 1))
       FROM dots.miscellaneous m,
            dots.translatedaafeature taaf,
            dots.translatedaasequence taas,
            sres.taxonname tn,
            sres.sequenceontology so,
            sres.externaldatabase ed,
            sres.externaldatabaserelease edr,
            ApidbTuning.FeatureLocation fl,
            dots.nasequence enas
      WHERE m.na_feature_id = taaf.na_feature_id
        AND taaf.aa_sequence_id = taas.aa_sequence_id
        AND m.na_feature_id = fl.na_feature_id
        AND fl.is_top_level = 1
        AND enas.na_sequence_id = fl.na_sequence_id 
        AND enas.taxon_id = tn.taxon_id
        AND tn.name_class = 'scientific name'
        AND m.sequence_ontology_id = so.sequence_ontology_id
        AND so.term_name = 'ORF'
        AND taas.length >= $length
        AND m.external_database_release_id = edr.external_database_release_id
        AND edr.external_database_id = ed.external_database_id
        AND ed.name in ($dbName) AND edr.version in ($dbVer)
EOF

  $sql .= " and enas.taxon_id in ($taxonId)" if $taxonId;

  $sql .= " and enas.sequence_ontology_id in ($soIds)" if $soIds;

  makeDownloadFile($mgr, $species, $name, $sql,$project,$tmpDir);

}

sub makeOrfNaDownloadFileWithAbrevDefline {
  my ($mgr, $species, $name, $extDb, $extDbVer, $length,$project) = @_;

  my $sql = <<"EOF";
    SELECT
       m.source_id
        ||' | organism='||
       replace(tn.name, ' ', '_')
        ||' | location='||
       enas.source_id
        ||':'||
       nl.start_min
        ||'-'||
       nl.end_max
        ||'('||
       decode(nl.is_reversed, 1, '-', '+')
        ||') | length='||
       (nl.end_max - nl.start_min + 1) as defline,
       decode(nl.is_reversed,1, apidb.reverse_complement_clob(SUBSTR(enas.sequence,nl.start_min,nl.end_max - nl.start_min +1)),SUBSTR(enas.sequence,nl.start_min,nl.end_max - nl.start_min + 1))
       FROM dots.NASequence enas,
            dots.miscellaneous m,
            dots.nalocation nl,
            dots.translatedaafeature taaf,
            dots.translatedaasequence taas,
            sres.taxonname tn,
            sres.sequenceontology so,
            sres.externaldatabase ed,
            sres.externaldatabaserelease edr
      WHERE m.na_feature_id = taaf.na_feature_id
        AND m.na_feature_id = nl.na_feature_id
        AND taaf.aa_sequence_id = taas.aa_sequence_id
        AND enas.na_sequence_id = m.na_sequence_id 
        AND enas.taxon_id = tn.taxon_id
        AND tn.name_class = 'scientific name'
        AND m.sequence_ontology_id = so.sequence_ontology_id
        AND so.term_name = 'ORF'
        AND taas.length >= $length
        AND m.external_database_release_id = edr.external_database_release_id
        AND edr.external_database_id = ed.external_database_id
        AND ed.name = '$extDb' AND edr.version = '$extDbVer'
EOF
  makeDownloadFile($mgr, $species, $name, $sql,$project);

}



sub makeOrthomclFastaDownloadFile {
  my ($mgr, $species, $name, $project) = @_;

  my $sql = <<"EOF";
    SELECT ot.three_letter_abbrev
	|| '|' || eas.source_id
	|| ' | ' || nvl(og.name, 'no_group')
	|| ' | ' || eas.description,
	eas.sequence
	FROM apidb.OrthologGroup og,
	apidb.OrthologGroupAaSequence ogs,
	dots.ExternalAaSequence eas,
	apidb.OrthomclTaxon ot
	WHERE og.ortholog_group_id(+) = ogs.ortholog_group_id
	AND ogs.aa_sequence_id(+) = eas.aa_sequence_id
	AND eas.taxon_id = ot.taxon_id
EOF

  makeDownloadFile($mgr, $species, $name, $sql, $project);
}

sub makeOrthomclGroupsDownloadFile {
  my ($mgr, $species, $project) = @_;

  my $signal = "OrthomclGroupsDownloadFile";

  return if $mgr->startStep("Extracting group data from DB", $signal);

  my $propertySet = $mgr->{propertySet};
  my $release = $propertySet->getProp('projectRelease');
  my $projectDB = $project ? $project : $propertySet->getProp('projectDB');
  my $siteFileDir = $propertySet->getProp('siteFileDir');

  my $dlDir = "$siteFileDir/downloadSite/$projectDB/$release/$species";

  $mgr->runCmd("mkdir -p $dlDir");

  die "Failed to create $dlDir.\n"  unless (-e $dlDir);

  my $seqFile = "$dlDir/groups_orthomcl-2.txt";
  (-e $seqFile) and die "'$seqFile' already exists. Remove it before running this step.\n";

  my $logFile = "$mgr->{myPipelineDir}/logs/${signal}DownloadFile.log";

  my $cmd = <<"EOF";
      ga OrthoMCLData::Load::Plugin::MakeGroupsFile --outputFile $seqFile \\
      --verbose 2>> $logFile
EOF

  $mgr->runCmd($cmd);
  $mgr->endStep($signal);
}

sub makeGenomicDownloadFile {
  my ($mgr, $species, $name, $extDb, $extDbVer,$seqTable,$dataSource, $strain,$project) = @_;

  my $sql = <<"EOF";
        SELECT '$dataSource'
                ||'|'||
               enas.source_id
                ||' | organism='||
               replace(tn.name, ' ', '_')||' $strain'
                ||' | version='||
               edr.version
                ||' | length=' ||
               enas.length
               as defline,
               enas.sequence
           FROM dots.$seqTable enas,
                sres.taxonname tn,
                sres.externaldatabase ed,
                sres.externaldatabaserelease edr
          WHERE enas.taxon_id = tn.taxon_id
            AND tn.name_class = 'scientific name'
            AND enas.external_database_release_id = edr.external_database_release_id
            AND edr.external_database_id = ed.external_database_id
            AND ed.name = '$extDb' AND edr.version = '$extDbVer'
EOF

  makeDownloadFile($mgr, $species, $name, $sql,$project);

}

sub makeMixedGenomicDownloadFile {
  my ($mgr, $species, $name, $extDbNames, $extDbVers, $dataSource,$project, $allLevels,$ncbiTaxId, $taxonName, $soTermIdsOrNames) = @_;

  my $signal = "${name}DownloadFile";

  return if $mgr->startStep("Preparing to extract  $name sequences from GUS", $signal);

  my $taxonId =  &getTaxonId($mgr,$ncbiTaxId,$taxonName) if ($ncbiTaxId || $taxonName);

  my $soIds = &getSoId($mgr,$soTermIdsOrNames) if ($soTermIdsOrNames);

  my @dbNames = map{"'$_'"} split (/,/,$extDbNames);

  my $dbName = join(",", @dbNames);

  my @dbVers = map{"'$_'"} split (/,/,$extDbVers);

  my $dbVer = join(",", @dbVers);

  my $sql = <<"EOF";
  SELECT '$dataSource'
                ||'|'||
               sa.source_id
                ||' | organism='||
               replace(sa.organism, ' ', '_')
                ||' | version='||
               sa.database_version
                ||' | length=' ||
               sa.length
               as defline,
               ns.sequence
           FROM dots.nasequence ns,
	        sres.taxonname tn,
                ApidbTuning.SequenceAttributes sa
          WHERE ns.na_sequence_id = sa.na_sequence_id
	    AND ns.taxon_id = tn.taxon_id
            AND tn.name_class = 'scientific name'
            AND sa.database_name in ($dbName) AND sa.database_version in ($dbVer)

EOF

  $sql .= $allLevels ? " AND (sa.is_top_level = 1 OR sa.is_top_level = 0)" : " AND sa.is_top_level = 1";

  $sql .= " and ns.taxon_id in ($taxonId)" if $taxonId;

  $sql .= " and ns.sequence_ontology_id in ($soIds)" if $soIds;

  makeDownloadFile($mgr, $species, $name, $sql,$project);

}

sub makeIsolateDownloadFile {
  my ($mgr, $species, $name, $extDb, $extDbVer, $seqTable,$isRef) =@_;

  my $sql = <<"EOF";
        SELECT
        enas.source_id
        ||' | organism='|| 
        replace(tn.name, ' ', '_')
        ||' | description='||
        decode (enas.description,null,'$extDb',enas.description)
        ||' | length='||
        enas.length
        as defline,
        enas.sequence
        From dots.$seqTable enas,
             sres.taxonname tn,
             sres.externaldatabase ed,
             sres.externaldatabaserelease edr,
             dots.isolatesource i
        Where enas.taxon_id = tn.taxon_id
            AND tn.name_class = 'scientific name'
            AND enas.external_database_release_id = edr.external_database_release_id
            AND edr.external_database_id = ed.external_database_id
            AND ed.name = '$extDb' AND edr.version = '$extDbVer'
            AND enas.na_sequence_id = i.na_sequence_id
EOF

  $sql .= " and i.is_reference=$isRef";

  makeDownloadFile($mgr, $species, $name, $sql);

}

sub makeDownloadFile {
  my ($mgr, $species, $name, $sql, $project, $tmpDir) = @_;

  my $signal = "${name}DownloadFile";

  return if $mgr->startStep("Extracting $name sequences from GUS", $signal);

  my $propertySet = $mgr->{propertySet};
  my $release = $propertySet->getProp('projectRelease');
  my $projectDB = $project ? $project : $propertySet->getProp('projectDB');
  my $siteFileDir = $propertySet->getProp('siteFileDir');

  my $dlDir = $tmpDir ? "$tmpDir" : "$siteFileDir/downloadSite/$projectDB/release-$release/$species";

  $mgr->runCmd("mkdir -p $dlDir");

  die "Failed to create $dlDir.\n"  unless (-e $dlDir);

  my $seqFile = "$dlDir/${name}_$projectDB-${release}.fasta";

  (-e $seqFile) and die "'$seqFile' already exists. Remove it before running this step.\n";

  my $logFile = "$mgr->{myPipelineDir}/logs/${signal}DownloadFile.log";

  my $cmd = <<"EOF";
      gusExtractSequences --outputFile $seqFile \\
      --idSQL \"$sql\" \\
      --verbose 2>> $logFile
EOF

  $mgr->runCmd($cmd);
  $mgr->endStep($signal);
}

##for the following you need to check out and build WDK and ApiCommonWebsite and ApiCommonData
##you also need to have in your gus_home config directory the following files or those that correspond to the project:
##PlasmoDB/model-config.xml (personalize this with your login and password and authentication login and password) and PlasmoDB/model.prop (make sure projectId is correct)
##these files are made from the sample files 
##If you have run wdk dump for genes previously and want to now rerun it, delete all rows in apidb.GeneDetail
##If you have run gff dump for genes previously and now want to rerun it, delete all rows in apidb.GeneGff
##clear the wdkCache, if there is no wdkCache (run describe queryinstance and if doesn't exist, run wdkCache -model PlasmoDB -new)

sub clearWdkCache {
  my ($mgr, $model) = @_;

  my $signal = "clear${model}Cache";

  return if $mgr->startStep("Clearing cache for $model", $signal);

  my $logFile = "$mgr->{myPipelineDir}/logs/${signal}.log";

  my $cmd = <<"EOF";
     wdkCache \\
     -model $model \\
     -recreate\\
     2>> $logFile
EOF

  print STDERR "$cmd\n";

  $mgr->runCmd($cmd);

  $mgr->endStep($signal);
}

sub runGffDump {
  my ($mgr, $species, $model, $organism) = @_;

  my $signal = "dump${species}GffFile";

  return if $mgr->startStep("Creating gff file from model $model for $organism", $signal);

  my $propertySet = $mgr->{propertySet};
  my $release = $propertySet->getProp('projectRelease');
  my $projectDB = $propertySet->getProp('projectDB');
  my $siteFileDir = $propertySet->getProp('siteFileDir');

  my $dir = "$siteFileDir/downloadSite/$projectDB/release-$release/$species";

  my $logFile = "$mgr->{myPipelineDir}/logs/${signal}.log";

  my $cmd = <<"EOF";
     gffDump \\
     -model $model \\
     -organism \"$organism\" \\
     -dir $dir \\
     >> $logFile
EOF

  print STDERR "$cmd\n";

  $mgr->runCmd($cmd);

  $organism =~ s/\s/\_/;
 # my $file = "$dir/$organism";
  $organism = lcfirst($organism);
  $organism =~ s/^(\w)\w+_(\w+)$/$1_$2/;
  my $file = "$dir/${species}_${projectDB}-${release}.gff";

  die "Did not create non-empty file $file\n" unless (-s $file);
  $mgr->endStep($signal);
}

sub runWdkRecordDump {
  my ($mgr, $species, $model, $organism, $recordType) = @_;

  my $signal = "dump${species}WdkRecord";

  return if $mgr->startStep("Creating wdk record from model $model for $organism", $signal);

  my $propertySet = $mgr->{propertySet};
  my $release = $propertySet->getProp('projectRelease');
  my $projectDB = $propertySet->getProp('projectDB');
  my $siteFileDir = $propertySet->getProp('siteFileDir');

  my $dir = "$siteFileDir/downloadSite/$projectDB/release-$release/$species";

  my $logFile = "$mgr->{myPipelineDir}/logs/${signal}.log";

  my $cmd = <<"EOF";
     fullRecordDump \\
     -model $model \\
     -organism \"$organism\" \\
     -type \"$recordType\" \\
     -dir $dir \\
     >> $logFile
EOF

  print STDERR "$cmd\n";
  print "GUS_HOME ".$ENV{GUS_HOME}."\n";
  $mgr->runCmd($cmd);
  $mgr->endStep($signal);
}



# make release-?? directory within pre-existing site dir and
# copy download files to there. Meant to be called once after
# all download files are made. OK to call again, rsync will 
# only copy diffs. Though you'll need to remove the pipeline signal.
sub syncDownloadDirToSite {
  my ($mgr, $site) = @_;

  my $signal = "syncDownloadDir";

  return if $mgr->startStep("Syncronizing download files to website", $signal);
  my $propertySet = $mgr->{propertySet};
  my $parentDir = 'release-' . $propertySet->getProp('projectRelease');

  my $cmd = "rsync -ae ssh $mgr->{dataDir}/downloadSite/ $site/$parentDir";

  $mgr->runCmd($cmd);
  # do we really need a signal? rysnc won't re-copy files already in place
  # if this step is called again.
  #$mgr->endStep($signal);
}

sub extractAnnotatedTranscriptSeq {
  my ($mgr,$dbName,$dbRlsVer,$name,$seqType,$transcriptTable,$seqTable,$identifier) = @_;

  my $type = ucfirst($seqType);

  my $signal = "extract${name}$type";

  return if $mgr->startStep("Extracting $name $seqType from GUS", $signal);

  my $dbRlsId = &getDbRlsId($mgr,$dbName,$dbRlsVer);

  my $outFile = "$mgr->{dataDir}/seqfiles/${name}${type}.fsa";
  my $logFile = "$mgr->{myPipelineDir}/logs/${signal}.log";

  my $sql = my $sql = "select t.$identifier, s.description,
            'length='||s.length,s.sequence
             from dots.$transcriptTable t, dots.$seqTable s
             where t.external_database_release_id = $dbRlsId
             and t.na_sequence_id = s.na_sequence_id";

  my $cmd = "gusExtractSequences --outputFile $outFile --idSQL \"$sql\" --verbose 2>> $logFile";

  $mgr->runCmd($cmd);

  $mgr->endStep($signal);
}

sub extractESTs {
  my ($mgr,$dbName,$dbRlsVer,$genus,$species,$date,$ncbiTaxId,$taxonHierarchy,$database, $source,$taxonName) = @_;

  my $signal = "extract${genus}${species}${dbName}ESTs";

  $signal =~ s/\s//g;

  $signal =~ s/\//_/g;

  return if $mgr->startStep("Extracting $genus $species $dbName ESTs from GUS", $signal,$taxonName);

   my $dbRlsId = &getDbRlsId($mgr,$dbName,$dbRlsVer);

  my $taxonId =  &getTaxonId($mgr,$ncbiTaxId,$taxonName);

  my $taxonIdList = &getTaxonIdList($mgr,$taxonId,$taxonHierarchy);

  my $logFile = "$mgr->{myPipelineDir}/logs/${signal}.log";

  my $name = "${genus}_$species";

  my $sql = "select '${name}|'||source_id||'|${date}|EST|${source}',sequence
             from dots.externalnasequence
             where external_database_release_id = $dbRlsId and taxon_id in ($taxonIdList)";

  $genus =~ s/^(\w)\w+/$1/;

  my $propertySet = $mgr->{propertySet};

  my $release = $propertySet->getProp('release');

  my $outFile = "$mgr->{dataDir}/seqfiles/${genus}${species}ESTs_${database}-${release}.fasta";

  my $cmd = "gusExtractSequences --outputFile $outFile --idSQL \"$sql\" --verbose 2>> $logFile";

  $mgr->runCmd($cmd);

  $mgr->endStep($signal);
}


sub makeESTDownloadFileFromAllSources {
  my ($mgr,$species,$ncbiTaxId,$taxonHierarchy,$project,$taxonName) = @_;

  my $taxonId =  &getTaxonId($mgr,$ncbiTaxId,$taxonName);

  my $taxonIdList = &getTaxonIdList($mgr,$taxonId,$taxonHierarchy);

  my $sql = <<"EOF";
    SELECT x.source_id
           ||' | organism='||
           replace(tn.name, ' ', '_')
           ||' | length='||
           x.length as defline,
           x.sequence
           FROM dots.externalnasequence x,
                sres.taxonname tn,
                sres.taxon t,
                sres.sequenceontology so
           WHERE t.taxon_id in ($taxonIdList)
            AND t.taxon_id = tn.taxon_id
            AND tn.name_class = 'scientific name'
            AND t.taxon_id = x.taxon_id
            AND x.sequence_ontology_id = so.sequence_ontology_id
            AND so.term_name = 'EST'
EOF

   my $fileName = $species . 'EST';

   makeDownloadFile($mgr, $species, $fileName, $sql,$project);
}

sub extractIndividualNaSeq {
  my ($mgr,$dbName,$dbRlsVer,$name,$seqType,$table,$identifier) = @_;

  my $type = ucfirst($seqType);

  my $signal = "extract${name}$type";

  my $logFile = "$mgr->{myPipelineDir}/logs/${signal}.log";

  return if $mgr->startStep("Extracting individual $name $seqType sequences from GUS", $signal);

  my $dbRlsId = &getDbRlsId($mgr,$dbName,$dbRlsVer);

  my $ouputDir = "$mgr->{dataDir}/seqfiles/${name}$type";

  $mgr->runCmd("mkdir -p $ouputDir");

  my $sql = "select x.$identifier, x.description,
            'length='||x.length,x.sequence
             from dots.$table x
             where x.external_database_release_id = $dbRlsId";

  $mgr->runCmd("gusExtractIndividualSequences --outputDir $ouputDir --idSQL \"$sql\" --verbose 2>> $logFile");

  $mgr->endStep($signal);
}

sub extractOrthoGroupFastaFiles {
  my ($mgr,$dbName,$dbRlsVer,$name,$seqType,$table,$identifier) = @_;

  my $type = ucfirst($seqType);

  my $signal = "extract${name}$type";

  my $logFile = "$mgr->{myPipelineDir}/logs/${signal}.log";

  return if $mgr->startStep("Extracting individual $name $seqType sequences from GUS", $signal);

  my $dbRlsId = &getDbRlsId($mgr,$dbName,$dbRlsVer);

  my $ouputDir = "$mgr->{dataDir}/seqfiles/${name}$type";

  $mgr->runCmd("mkdir -p $ouputDir");

  my $sql = "select og.name, x.source_id,
             x.sequence
             from apidb.orthologgroup og, apidb.orthologgroupaasequence oga, dots.externalaasequence x
             where og.ortholog_group_id = oga.ortholog_group_id and oga.aa_sequence_id = x.aa_sequence_id group by og.name, x.source_id, x.sequence";

  $mgr->runCmd("gusExtractIndividualSequences --outputDir $ouputDir --idSQL \"$sql\" --verbose 2>> $logFile");

  $mgr->endStep($signal);
}


sub extractNaSeqAltDefLine {
  my ($mgr,$dbName,$dbRlsVer,$name,$seqType,$table,$defLine) = @_;

  my $type = ucfirst($seqType);

  my $signal = "extract${name}$type";

  return if $mgr->startStep("Extracting $name $seqType from GUS", $signal);

  my $dbRlsId = &getDbRlsId($mgr,$dbName,$dbRlsVer);

  my $outFile = "$mgr->{dataDir}/seqfiles/${name}${type}.fsa";
  my $logFile = "$mgr->{myPipelineDir}/logs/${signal}.log";

  my $sql = "select $defLine,sequence
             from dots.$table
             where external_database_release_id = $dbRlsId";

  my $cmd = "gusExtractSequences --outputFile $outFile --idSQL \"$sql\" --verbose 2>> $logFile";

  $mgr->runCmd($cmd);

  $mgr->endStep($signal);
}

sub runSplign {
  my ($mgr,$name,$query,$subject) = @_;

  my $queryType = ucfirst $query;

  my $subjectType = ucfirst $subject;

  my $signal = "run${name}${queryType}${subjectType}Splign";

  return if $mgr->startStep("Running splign for $name $query vs $subject", $signal);

  my $propertySet = $mgr->{propertySet};

  my $splignPath = $propertySet->getProp('splignPath');

  my $ncbiBlastPath = $propertySet->getProp('ncbiBlastPath');

  my $splignDir = "$mgr->{dataDir}/splign/${name}${queryType}$subjectType";

  $mgr->runCmd("mkdir -p $splignDir");

  $mgr->runCmd("ln -s  $mgr->{dataDir}/seqfiles/${name}${queryType}.fsa ${splignDir}/$query");

  $mgr->runCmd("ln -s  $mgr->{dataDir}/seqfiles/${name}${subjectType}.fsa ${splignDir}/$subject");

  $mgr->runCmd("${splignPath}/splign -mklds $splignDir");

  $mgr->runCmd("${ncbiBlastPath}/formatdb -i ${splignDir}/$subject -p F -o F");

  $mgr->runCmd("${ncbiBlastPath}/megablast -i ${splignDir}/$query -d ${splignDir}/$subject -m 8 | sort -k 2,2 -k 1,1 > $splignDir/test.hit");

  $mgr->runCmd("${splignPath}/splign -ldsdir $splignDir -hits $splignDir/test.hit > ${splignDir}/${query}${subjectType}.splign");

  $mgr->runCmd("rm -rf ${splignDir}/$query");

  $mgr->runCmd("rm -rf ${splignDir}/$subject");

  $mgr->endStep($signal);

}

sub updateTaxonIdField {
  my ($mgr,$file,$sourceRegex,$taxonRegex,$idSql,$extDbRelSpec,$table) =@_;

  $file = "$mgr->{dataDir}/misc/$file";

  my $args = "--fileName '$file' --sourceIdRegex  \"$sourceRegex\" $taxonRegex --idSql '$idSql' --extDbRelSpec '$extDbRelSpec'  --tableName '$table'";

  my $signal = "update${extDbRelSpec}TaxonId";

  $signal =~ s/\|//g;

  $signal =~ s/\///g;

  $signal =~ s/\s//g;

  $mgr->runPlugin($signal,
		  "ApiCommonData::Load::Plugin::UpdateTaxonFieldFromFile", $args,
		  "Updating taxon_id in $table for $extDbRelSpec based on $file file");
}

sub loadSplignResults {
  my ($mgr,$name,$query,$subject,$queryExtDbRlsSpec,$subjectExtDbRlsSpec,$queryTable,$subjectTable) = @_;

  my $subjectType = ucfirst $subject;

  my $queryType = ucfirst $query;

  my $signal = "load${name}${queryType}${subjectType}Splign";

  my $splignFile = "$mgr->{dataDir}/splign/${name}${queryType}${subjectType}/${query}${subjectType}.splign";

  my $args = "--inputFile $splignFile --estTable '$queryTable' --seqTable '$subjectTable' --estExtDbRlsSpec '$queryExtDbRlsSpec' --seqExtDbRlsSpec '$subjectExtDbRlsSpec'";

  $mgr->runPlugin($signal,
		  "ApiCommonData::Load::Plugin::InsertSplignAlignments", $args,
		  "Load splign results for $name $query vs $subject");

}

sub extractGenomeNaSequences {
  my ($mgr, $species, $table, $sequenceOntology,$taxId,$taxonName) = @_;
  my $propertySet = $mgr->{propertySet};

  $table = "Dots." . $table;

  my $signal = "extract${species}GenomeNaSequences";

  return if $mgr->startStep("Extracting $species genome na sequences from GUS", $signal);

  my $taxonId =  &getTaxonId($mgr,$taxId,$taxonName);

  foreach my $genome (@{$mgr->{genomeNaSequences}->{$species}}) {
    my $dbName =  $genome->{name};
    my $dbVer =  $genome->{ver};

    my $name = $dbName;
    $name =~ s/\s/\_/g;

    my $dbRlsId = &getDbRlsId($mgr,$dbName,$dbVer);

    my $genomeFile = "$mgr->{dataDir}/seqfiles/${name}GenomeNaSequences.fsa";

    my $logFile = "$mgr->{myPipelineDir}/logs/$signal.log";

    my $sql = "select x.na_sequence_id, x.description,
            'length='||x.length,x.sequence
             from $table x, sres.sequenceontology s
             where x.taxon_id = $taxonId
             and x.external_database_release_id = $dbRlsId
             and x.sequence_ontology_id = s.sequence_ontology_id
             and lower(s.term_name) = '$sequenceOntology'";

    my $cmd = "gusExtractSequences --outputFile $genomeFile --idSQL \"$sql\" --verbose 2>> $logFile";

    $mgr->runCmd($cmd);
  }

  $mgr->endStep($signal);
}

sub extractIdsFromBlastResult {
  my ($mgr,$simDir,$idType) = @_;

  my $blastFile = "$mgr->{dataDir}/similarity/$simDir/master/mainresult/blastSimilarity.out";

  my $signal = "ext${simDir}BlastIds";

  return if $mgr->startStep("Extracting ids from $simDir Blast result", $signal);

  my $cmd = "gunzip ${blastFile}.gz" if (-e "${blastFile}.gz");

  $mgr->runCmd($cmd) if $cmd;

  my $output = "$mgr->{dataDir}/similarity/$simDir/blastSimIds.out";

  my $logFile = "$mgr->{myPipelineDir}/logs/${signal}.log";
  $cmd = "makeIdFileFromBlastSimOutput --$idType --subject --blastSimFile $blastFile --outFile $output 2>> $logFile";

  $mgr->runCmd($cmd);

  $mgr->endStep($signal);
}

sub filterBLASTResults{
  my ($mgr, $taxonList, $gi2taxidFile, $blastDir, $fileName) = @_;

  my $signal = "filtering${blastDir}BlastResults";

  return if $mgr->startStep("Filtering BLAST Results for $blastDir", $signal);

  my $blastFile =  "$mgr->{dataDir}/similarity/$blastDir/master/mainresult/$fileName";
  my $inputFile = "$mgr->{dataDir}/similarity/$blastDir/master/mainresult/unfiltered$fileName";

  unless (-e $inputFile) {
    rename($blastFile, $inputFile) or die "cannot rename $blastFile to $inputFile\n";
  }

  my $outFile = "$mgr->{dataDir}/similarity/$blastDir/master/mainresult/blastSimilarity.out";

  $gi2taxidFile = "$mgr->{dataDir}/misc/$gi2taxidFile";

  my $logFile = "$mgr->{myPipelineDir}/logs/${signal}.log";

  $taxonList =~ s/"//g;

  my $cmd = "splitAndFilterBLASTX --taxon \"$taxonList\" --gi2taxidFile $gi2taxidFile --inputFile $inputFile --outputFile $outFile 2>> $logFile";

  $mgr->runCmd($cmd);

  $mgr->endStep($signal);
}

sub loadNRDBSubset {
  my ($mgr,$idDir,$idFile,$extDbName,$extDbRlsVer) = @_;

  my $signal = "${idDir}NrIdsLoaded";

  my $nrdbFile = "$mgr->{dataDir}/seqfiles/nr.fsa";
  
  my $sourceIdsFile = "$mgr->{dataDir}/similarity/$idDir/$idFile";

  my $args = "--externalDatabaseName $extDbName --externalDatabaseVersion $extDbRlsVer --sequenceFile $nrdbFile --sourceIdsFile  $sourceIdsFile --regexSourceId  '>gi\\|(\\d+)\\|' --regexDesc '^>(.+)' --tableName DoTS::ExternalAASequence";

  $mgr->runPlugin($signal,
		  "GUS::Supported::Plugin::LoadFastaSequences", $args,
		  "Load NRDB Ids from $idDir/$idFile");

}

sub loadFastaSequences {
  my ($mgr,$file,$table,$extDbName,$extDbRlsVer,$soTermName,$regexSourceId,$check,$taxId) = @_;

  my $inputFile = "$mgr->{dataDir}/seqfiles/$file";

  my $signal = "load$file";

  my $ncbiTaxId = $taxId ? "--ncbiTaxId $taxId" : "";

  my $noCheck = $check eq 'no' ? "--noCheck" : "";

  my $args = "--externalDatabaseName '$extDbName' --externalDatabaseVersion '$extDbRlsVer' --sequenceFile '$inputFile' --SOTermName '$soTermName' $ncbiTaxId --regexSourceId '$regexSourceId' --tableName '$table' $noCheck";

  $mgr->runPlugin($signal,
                  "GUS::Supported::Plugin::LoadFastaSequences", $args,
                  "Load $file");
}

sub documentProfileAveraging {
  my ($mgr) = @_;
  #my $documentation =
  # { name => "Average Expression Profiles",
  #   input => "",
  #   output => "Averaged expression profiles.",
  #   descrip => "",
  #   tools => [
  #      { name => "",
  #        version => "",
  #        params => "",
  #        url => "",
  #        pubmedIds => "",
  #        credits => ""
  #      },
  #     ]
  #   };
  #$mgr->documentStep('profileAveraging', $documentation);

}

sub findTandemRepeats {
  my ($mgr,$file,$fileDir,$args) = @_;

  my $propertySet = $mgr->{propertySet};

  my $signal = "run${file}.TRF";

  return if $mgr->startStep("Finding tandem repeats in $file", $signal);

  my $logFile = "$mgr->{myPipelineDir}/logs/${signal}.log";

  my $trfDir = "$mgr->{dataDir}/trf";

  $mgr->runCmd("mkdir -p $trfDir");

  #  $mgr->runCmd($cmd) if $cmd;

  if ($file =~ /\.gz/) {

    $mgr->runCmd("gunzip $mgr->{dataDir}/${fileDir}/$file");

    $file =~ s/\.gz//;
  }

  my $trfPath =  $propertySet->getProp('trfPath');

  chdir $trfDir || die "Can't chdir to $trfDir";

  my $cmd = "${trfPath}/trf400 $mgr->{dataDir}/$fileDir/$file $args -d > $logFile";

  $mgr->runCmd($cmd);

  chdir $mgr->{dataDir} || die "Can't chdir to $mgr->{dataDir}";

  $mgr->endStep($signal);
}

sub documentTandemRepeatFinder {
  my ($mgr, $version,$args) = @_;

  my $description = "The Tandem Repeats Finder program locates and displays tandem repeats in DNA sequences";

  my $documentation =
    { name => "TRF",
      input => "fasta file of DNA sequences",
      output => "a repeat table file and an alignment file",
      descrip => $description,
      tools => [
		{ name => "TRF",
		  version => $version,
		  params => $args,
		  url => "http://tandem.bu.edu/trf/trf.html",
		  pubmedIds => "9862982",
		  credits => ""
		}
	       ]
    };
  $mgr->documentStep("trf", $documentation);
}

sub documentSplign {
  my ($mgr, $args) = @_;

  my $description = "Splign uses transcript to genomic sequence BLAST hit output to generate information about exon-intron boundaries, splice-junctions, potential frameshifts, and alternative models when there is more than one possibility";

  my $documentation =
    { name => "splign",
      input => "output of megablast analysis of a fasta formatted transcript file with a genomic sequence database formatted using formatdb ",
      output => "a tab-delimited text with every line representing a separate segment on the query sequence.",
      descrip => $description,
      tools => [
		{ name => "splign",
		  params => $args,
                  version => "07/19/06",
		  url => "http://www.ncbi.nlm.nih.gov/sutils/splign/",
		  pubmedIds => "16381840",
		  credits => "Yu.Kapustin, A.Souvorov, T.Tatusova. 
                             Splign - a Hybrid Approach To Spliced Alignments.
                             RECOMB 2004 - Currents in Computational Molecular Biology. p.741."
		}
	       ]
    };
  $mgr->documentStep("splign", $documentation);
}

sub loadTandemRepeats {
  my ($mgr,$file,$args,$dbName,$dbRlsVer) = @_;

  $args =~ s/\s+/\./g;

  my $tandemRepFile = "$mgr->{dataDir}/trf/${file}.${args}.dat";

  my $signal = "load${file}.TRF";

  my $args = "--tandemRepeatFile $tandemRepFile --extDbName '$dbName' --extDbVersion '$dbRlsVer'";

  $mgr->runPlugin($signal,
                  "GUS::Supported::Plugin::InsertTandemRepeatFeatures", $args,
                  "Inserting tandem repeats for $file");
}

sub runBLASTZ {
  my ($mgr,$queryDir,$targetFile,$args) = @_;

  my $propertySet = $mgr->{propertySet};

  my $blastzPath = $propertySet->getProp('blastzPath');

  opendir(DIR,"$mgr->{dataDir}/$queryDir");

  my $signal;

  my $outputFile;

  $mgr->runCmd("mkdir $mgr->{dataDir}/similarity/blastz_${targetFile}");

  while (my $file = readdir(DIR)) {

    next if -d $file;

    $signal = "blastz${file}_$targetFile";

    $outputFile = "${file}_${targetFile}";

    $outputFile =~ s/\.\w+$/\.laj/;

    next if $mgr->startStep("Running BLASTZ for $file vs $targetFile", $signal);

    $mgr->runCmd("${blastzPath}/blastz $mgr->{dataDir}/${queryDir}/$file  $mgr->{dataDir}/seqfiles/$targetFile $args > $mgr->{dataDir}/similarity/blastz_${targetFile}/$outputFile");

    $mgr->endStep($signal);
  }
}

sub formatBLASTZResults {
  my ($mgr,$targetFile) = @_;

  my $propertySet = $mgr->{propertySet};

  $mgr->runCmd("mkdir $mgr->{dataDir}/similarity/blastz_${targetFile}/master") if ! -d "$mgr->{dataDir}/similarity/blastz_${targetFile}/master";

  $mgr->runCmd("mkdir $mgr->{dataDir}/similarity/blastz_${targetFile}/master/mainresult") if ! -d "$mgr->{dataDir}/similarity/blastz_${targetFile}/master/mainresult";

  my $outputFile = "$mgr->{dataDir}/similarity/blastz_${targetFile}/master/mainresult/blastSimilarity.out";

  my $signal = "format${targetFile}Blastz";

  return if $mgr->startStep("Formatting BLASTZ output for $targetFile", $signal);

  my $dir = "$mgr->{dataDir}/similarity/blastz_${targetFile}";

  $mgr->runCmd("parseBlastzLav.pl --dirname $dir --outfile $outputFile");

  $mgr->endStep($signal);
}


sub loadBLASTZResults {
  my ($mgr,$targetFile,$queryTable,$subjTable,$queryExtDbRlsSpec,$subjExtDbRlsSpec) = @_;

  opendir(DIR,"$mgr->{dataDir}/similarity/blastz_$targetFile");

  my $signal;

  my $args;

  while (my $file = readdir(DIR)) {

    next if ($file !~ /\.laj/);

    $signal = "loadBlastz$file";

    $args = "--inputFile '$mgr->{dataDir}/similarity/blastz_${targetFile}/$file' --queryTable '$queryTable' --subjTable '$subjTable' --queryExtDbRlsSpec '$queryExtDbRlsSpec' --subjExtDbRlsSpec '$subjExtDbRlsSpec'";

    $mgr->runPlugin($signal,
                    "ApiCommonData::Load::Plugin::InsertBlastZAlignments",$args,
		    "Loading blastz results file $file");
  }
}

sub parseBlastForSqlldr {
  my ($mgr,$blastName) = @_;

   my $signal = "parse$blastName";

  return if $mgr->startStep("Parse $blastName blastSimilarity.out into file for sqldr", $signal);

  my $blastFile = "$mgr->{dataDir}/similarity/$blastName/master/mainresult/blastSimilarity.out.gz";

  die "$blastFile doesn't exist\n" unless (-e $blastFile);

  my $sqlldrFile = "$mgr->{dataDir}/similarity/$blastName/master/mainresult/blastSimForSqlldr.out";

  my $logFile = "$mgr->{myPipelineDir}/logs/$signal.log";

  my $cmd = "parseBlastForSimilaritySequences --blastInput $blastFile --blastoutput $sqlldrFile --verbose 2>> $logFile";

  $mgr->runCmd($cmd);

  $mgr->endStep($signal);

}

sub makeOrthoSqlldrCtlFile {
  my ($mgr,$blastName,$file,$text) = @_;
  my $signal = "make$file";

  return if $mgr->startStep("Make $file for sqldr", $signal);

  my $ctlFile = "$mgr->{dataDir}/similarity/$blastName/master/mainresult/$file";

  open(CTL, ">$ctlFile") || die "Can't open '$ctlFile' for writing";
  print CTL $text;
  close(CTL);

  $mgr->endStep($signal);

}


sub updateBlastEval {
  my ($mgr,$blastName, $inFile,$outFile) = @_;

  my $signal = "blastEvalModified";

  return if $mgr->startStep("Update eval to min in $inFile to create $outFile", $signal);

  my $logFile = "$mgr->{myPipelineDir}/logs/blastEvalMod.log";

  my $cmd = "modifyExpToMin $mgr->{dataDir}/similarity/$blastName/master/mainresult/$inFile $mgr->{dataDir}/similarity/$blastName/master/mainresult/$outFile 2>> $logFile";

  $mgr->runCmd($cmd);

  $mgr->endStep($signal);

}


sub loadBlastWithSqlldr {
  my ($mgr,$blastName,$restart,$file, $ctl) = @_;

  my $signal = "sqlldrLoad$blastName";

  return if $mgr->startStep("Load $blastName using sqldr", $signal);

  my $sqlldrFile = "$mgr->{dataDir}/similarity/$blastName/master/mainresult/blastSimForSqlldr.out";

  if ($file) {
    $sqlldrFile = "$mgr->{dataDir}/similarity/$blastName/master/mainresult/$file";

    $mgr->runCmd("gunzip $sqlldrFile") if $sqlldrFile =~ /\.gz/;
    $sqlldrFile =~ s/\.gz//;
  }

  my $ctlFile = "$mgr->{dataDir}/similarity/$blastName/master/mainresult/$ctl" if $ctl;

  my $logfile = "$mgr->{myPipelineDir}/logs/$signal.log";

  die "$sqlldrFile file doesn't exist\n" unless (-e $sqlldrFile);

  my $propertySet = $mgr->{propertySet};

  my $oracleUserPswd = $propertySet->getProp('oracleUserPswd');

  my $cmd = "nohup sqlldr $oracleUserPswd control=$sqlldrFile log=$logfile rows=25000 direct=TRUE";

  $cmd = "nohup sqlldr $oracleUserPswd data=$sqlldrFile control=$ctlFile log=$logfile rows=25000 direct=TRUE" if $ctl;

  $cmd .= " SKIP=$restart" if $restart;

  $mgr->runCmd($cmd);

  $mgr->endStep($signal);


}

sub orthomclEdges {
  my ($mgr, $cleanup, $startAfter) = @_;

  my $signal = 'findOrthoMclEdges';

  return if $mgr->startStep("Find edges for orthoMCL", $signal);

  my $logfile = "$mgr->{myPipelineDir}/logs/$signal.log";

  my $propertySet = $mgr->{propertySet};

  my $gus_config_file = $propertySet->getProp('gusConfigFile');

  my @properties = ();
  my $gusconfig = CBIL::Util::PropertySet->new($gus_config_file, \@properties, 1);
  my $login = $gusconfig->{props}->{databaseLogin};
  my $password = $gusconfig->{props}->{databasePassword};
  my $dsn = $gusconfig->{props}->{dbiDsn};

my $configString =
"dbConnectString=$dsn
dbLogin=$login
dbPassword=$password
dbVendor=oracle
similarSequencesTable=apidb.SimilarSequences
orthologTable=apidb.Ortholog
inParalogTable=apidb.InParalog
coOrthologTable=apidb.CoOrtholog
interTaxonMatchView=apidb.InterTaxonMatch
percentMatchCutoff=50
evalueExponentCutoff=-5
";

  my $configFile = "orthomclEdges.config";
  open(CONFIG, ">$configFile") || die "Can't open '$configFile' for writing";
  print CONFIG $configString;
  close(CONFIG);

  my $cmd = "nohup orthomclEdges $configFile cleanup=$cleanup 2>> $logfile";

  $cmd .= " startAfter=$startAfter" if $startAfter;

  $mgr->runCmd($cmd);

  $mgr->endStep($signal);

}

sub mapProteomeToGroups{
  my ($mgr) = @_;

  my $signal = "mapProteomeToGroups";

  return if $mgr->startStep("Mapping proteome to groups file", $signal);

  my $logfile = "$mgr->{myPipelineDir}/logs/$signal.log";

  my $propertySet = $mgr->{propertySet};

  my $groupsFile = $propertySet->getProp('groupsFile');

  my $blastOutput =  "$mgr->{dataDir}/similarity/Proteome-ProteinSeqs/master/mainresult/blastSimilarity.out";

  my $blastSelfOutput =  "$mgr->{dataDir}/similarity/Proteome-Proteome/master/mainresult/blastSimilarity.out"; 

  my $cmd = "orthomclMapProteomeToGroups $blastSelfOutput $blastOutput $groupsFile  'wxyz' $mgr->{dataDir}/similarity/Proteome-ProteinSeqs mcl $logfile";

  $mgr->runCmd($cmd);

  $mgr->endStep($signal);
}


sub addIdsToGroupsFile {
  my ($mgr) = @_;

  my $signal = "addIdsToGroupsFile";

  return if $mgr->startStep("Adding mapped ids to groups file", $signal);

  my $propertySet = $mgr->{propertySet};

  my $groupsFile = $propertySet->getProp('groupsFile');

  my $proteomeName = $propertySet->getProp('proteomeName');

  my $grpPrefix = $propertySet->getProp('grpPrefix');

  my $logfile = "$mgr->{myPipelineDir}/logs/$signal.log";

  my $idsToGroups = "$mgr->{dataDir}/similarity/Proteome-ProteinSeqs/orthologGroups";

  my $outputGroups = "$mgr->{dataDir}/similarity/Proteome-ProteinSeqs/orthologGroups_$proteomeName";

  my $cmd = "addSourceIdsToGroups --sourceIdFile $idsToGroups --inputGroupsfile $groupsFile  --outputGroupsFile $outputGroups --log $logfile --grpPrefix $grpPrefix --verbose";

  $mgr->runCmd($cmd);

  $mgr->endStep($signal);
}

sub addParalogGroups {
   my ($mgr) = @_;

   my $signal = "addParaloggroups";

   return if $mgr->startStep("Adding group ids to paralog groups and paralog groups to orthologGroups file", $signal);

   my $propertySet = $mgr->{propertySet};

   my $grpPrefix = $propertySet->getProp('grpPrefix');

   my $proteomeName = $propertySet->getProp('proteomeName');

   my $orthoGroupsFile = "$mgr->{dataDir}/similarity/Proteome-ProteinSeqs/orthologGroups_$proteomeName";

   my $parlogGroupsFile = "$mgr->{dataDir}/similarity/Proteome-ProteinSeqs/paralogGroups";

   my $outputFile = "$mgr->{dataDir}/similarity/Proteome-ProteinSeqs/orthomclGroups.txt";

   my $cmd = "transformParalogGroupsToOrthologGroups --prefix $grpPrefix --pFile $parlogGroupsFile --oFile $orthoGroupsFile --outFile $outputFile";

   $mgr->runCmd($cmd);

   $mgr->endStep($signal);
}



sub orthomclPairs {
  my ($mgr, $cleanup, $startAfter) = @_;

  my $signal = 'findOrthoMclPairs';

  return if $mgr->startStep("Find pairs for orthoMCL", $signal);

  my $logfile = "$mgr->{myPipelineDir}/logs/$signal.log";

  my $propertySet = $mgr->{propertySet};

  my $gus_config_file = $propertySet->getProp('gusConfigFile');

  my @properties = ();
  my $gusconfig = CBIL::Util::PropertySet->new($gus_config_file, \@properties, 1);
  my $login = $gusconfig->{props}->{databaseLogin};
  my $password = $gusconfig->{props}->{databasePassword};
  my $dsn = $gusconfig->{props}->{dbiDsn};

my $configString =
"dbConnectString=$dsn
dbLogin=$login
dbPassword=$password
dbVendor=oracle
similarSequencesTable=apidb.SimilarSequences
orthologTable=apidb.Ortholog
inParalogTable=apidb.InParalog
coOrthologTable=apidb.CoOrtholog
interTaxonMatchView=apidb.InterTaxonMatch
percentMatchCutoff=50
evalueExponentCutoff=-5
";

  my $configFile = $propertySet->getProp('orthoMclPairsConfig');;
  open(CONFIG, ">$configFile") || die "Can't open '$configFile' for writing";
  print CONFIG $configString;
  close(CONFIG);

  my $cmd = "nohup orthomclPairs $configFile $logfile cleanup=$cleanup";

  $cmd .= " startAfter=$startAfter" if $startAfter;

  $mgr->runCmd($cmd);

  $mgr->endStep($signal);

}

sub makePairsDownloadFile{
  my ($mgr, $projectDB) = @_;

  my $signal = "pairsDownloadFiles";

  return if $mgr->startStep("Dumping pairs files into download site", $signal);

  my $propertySet = $mgr->{propertySet};

  my $config = $propertySet->getProp('orthoMclPairsConfig');

  my $siteFileDir = $propertySet->getProp('siteFileDir');

  my $release = $propertySet->getProp('projectRelease');

  my $dlDir = "$siteFileDir/downloadSite/$projectDB/release-$release/";

  $mgr->runCmd("mkdir -p $dlDir");

  chdir "$dlDir" || die "Can't chdir to $dlDir";

  my $logfile = "$mgr->{myPipelineDir}/logs/$signal.log";

  my $cmd = "orthomclDumpPairsFiles $config 2>> $logfile";

  $mgr->runCmd($cmd);

  $mgr->endStep($signal);

}

sub makeOrthoPairsFiles {
  my ($mgr) = @_;

   my $signal = "orthoPairsFiles";

  return if $mgr->startStep("Dumping orthomcl pairs file", $signal);

  my $mclPath = "$mgr->{dataDir}/mcl/";

  $mgr->runCmd("mkdir -p $mclPath");

  die "$mclPath directory not created\n" if (! -d $mclPath);

  my $logfile = "$mgr->{myPipelineDir}/logs/$signal.log";

  my $propertySet = $mgr->{propertySet};

  my $config = $propertySet->getProp('orthoMclPairsConfig');

  my $cmd = "orthomclDumpPairsFiles $config  2>> $logfile";

  chdir "$mclPath" || die "Can't chdir to $mclPath\n";

  $mgr->runCmd($cmd);

  $mgr->endStep($signal);
}


sub runMcl{
  my ($mgr, $mainInflation) = @_;

  my $signal = "runMcl";

  return if $mgr->startStep("Running the MCL algorithm", $signal);

  my $propertySet = $mgr->{propertySet};

  my $logfile = "$mgr->{myPipelineDir}/logs/$signal.log";

  my $outputFile = "$mgr->{dataDir}/mcl/mcl.out";

  my $abcFile = "$mgr->{dataDir}/mcl/mclInput";

  die " $abcFile file does not exist\n" if (! -e $abcFile);

  my $mclCommand = "mcl $abcFile --abc -I $mainInflation -o $outputFile 2>> $logfile";

  $mgr->runCmd($mclCommand);

  $mgr->endStep($signal);
}

sub mclOutToGroupsFile {
  my ($mgr, $prefix, $startWith) = @_;

  my $signal = 'mclOutToGroupsFile';

  return if $mgr->startStep("Make groups file from mcl output", $signal);

  my $logfile = "$mgr->{myPipelineDir}/logs/$signal.log";

  my $mclFile = "$mgr->{dataDir}/mcl/mcl.out";

  my $outFile = "$mgr->{dataDir}/mcl/orthomclGroups.txt";

  my $cmd = "orthomclMclToGroups $prefix $startWith < $mclFile > $outFile 2>> $logfile";

  $mgr->runCmd($cmd);

  $mgr->endStep($signal);

}

sub mapOldIdsToNewIds {
  my ($mgr,$oldSeqFile,$abbrevMap,$dbVersion) = @_;

  my $signal = "mapVersion${dbVersion}IdsToNew";

  my $args = " --oldIdsFastaFile $oldSeqFile --taxonMapFile $abbrevMap --dbVersion $dbVersion ";

  $mgr->runPlugin($signal,
                  "OrthoMCLData::Load::Plugin::InsertOrthomclOldIdsMap", $args,
		  "Mapping source ids orthoMCL version $dbVersion to this version of OrthoMCL");
}

sub mapOldGroupsToNewIds {
  my ($mgr,$oldGroupsFile,$abbrevMap,$dbVersion) = @_;

  my $signal = "mapVersion${dbVersion}GroupsToNewIds";

  my $args = " --oldGroupsFile $oldGroupsFile --taxonMapFile $abbrevMap --dbVersion $dbVersion ";

  $mgr->runPlugin($signal,
                  "OrthoMCLData::Load::Plugin::InsertOrthomclOldGroupsMap", $args,
		  "Mapping  groups from  orthoMCL version $dbVersion to this version of OrthoMCL");
}


sub  loadAveragedProfiles {
  my ($mgr,$dbSpec,$setName,$loadProfileElement) = @_;

  my $signal = "load${dbSpec}Profile";

  $signal =~ s/\s//g;

  $signal =~ s/\|/\-/g;

  $signal =~ s/\//\-/g;

  my $args = "--externalDatabaseSpec '$dbSpec' --profileSetNames '$setName' ";

  $args .= " --loadProfileElement" if $loadProfileElement;

  $mgr->runPlugin($signal,
                  "ApiCommonData::Load::Plugin::InsertAveragedProfiles", $args,
                  "Inserting averaged profiles for $setName");
}

sub documentExpressionStatistics {
  my ($mgr) = @_;
  #my $documentation =
  # { name => "Expression Profile Statistics",
  #   input => "",
  #   output => "",
  #   descrip => "",
  #   tools => [
  #      { name => "",
  #        version => "",
  #        params => "",
  #        url => "",
  #        pubmedIds => "",
  #        credits => ""
  #      },
  #     ]
  #   };
  #$mgr->documentStep('expressionStats', $documentation);


}
sub calculateExpressionStats {
  my ($mgr,$dbSpec,$profileSet,$mappingFile,$percentsAveraged, $isLogged) = @_;

  my $propertySet = $mgr->{propertySet};

  my $signal = "expStat$profileSet";

  $signal =~ s/\s//g;

  my $projectDir = $propertySet->getProp('projectDir');

  my $args = "--externalDatabaseSpec '$dbSpec'  --profileSetNames '$profileSet' --percentProfileSet '$percentsAveraged'";

  $args .= " --timePointsMappingFile '$projectDir/$mappingFile'"
    if $mappingFile;

  $args .= " --isLogged" if $isLogged;

  $mgr->runPlugin($signal,
                  "ApiCommonData::Load::Plugin::CalculateProfileSummaryStats", $args,
		  "Calculating profile summary stats for $profileSet");

}

sub InsertOntologyEntryFromMO {
  my ($mgr, $extDbName, $extDbRlsVer) = @_;

  my $signal = "loadOntologyEntryFrom" . $extDbName;
  $signal =~ s/[\s\(\)]//g;

  return if $mgr->startStep("Loading Study.OntologyEntry from:  $extDbName", $signal);

  my $args = "--externalDatabase $extDbName --externalDatabaseRls $extDbRlsVer";

  $mgr->runPlugin($signal,
                  "GUS::Community::Plugin::LoadOntologyEntryFromMO",
                  $args, 
                  "Loading Study.OntologyEntry from:  $extDbName");
}


sub InsertExpressionProfileFromProcessedResult {
  my ($mgr, $extDbName, $extDbRlsVer, $arrayName, $protocolName, $resultView, $desc, $numberOfChannels, $baseX) = @_;

  my $signal = "load_" . $extDbName;
  $signal =~ s/[\s\(\)]//g;

  return if $mgr->startStep("Loading ExpressionProfile for $extDbName", $signal);

  $desc = $extDbName unless($desc);

  my $args = "--arrayDesignName '$arrayName' --extDbName '$extDbName' --extDbRlsVer '$extDbRlsVer' --protocolName '$protocolName' --processingType '$resultView' --studyDescrip '$desc' --numberOfChannels $numberOfChannels";

  $args = $args . " --baseX $baseX" if($baseX);

  $mgr->runPlugin($signal,
                  "ApiCommonData::Load::Plugin::InsertExprProfileFromProcessedResult",
                  $args, 
                  "Inserting Rad Analysis for $extDbName");
}

sub InsertAveragedExpressionProfile {
  my ($mgr, $profileSetName, $configFile) = @_;

  my $signal = "average_" . $profileSetName;
  $signal =~ s/[\s\(\)]//g;

  return if $mgr->startStep("Loading AveragedExpressionProfile for $profileSetName", $signal);

  my $args = "--profileSetName '$profileSetName' --configFile '$configFile'";

  $mgr->runPlugin($signal,
                  "ApiCommonData::Load::Plugin::MakeAveragedProfiles",
                  $args,
                  "Inserting Averaged Profiles for $profileSetName");
}

sub InsertRadAnalysisFromConfig {
  my ($mgr, $configFile, $name, $propName) = @_;

  my $propertySet = $mgr->{propertySet};

  my $executable = $propertySet->getProp($propName) if ($propName);

  my $optionalExecutable = $executable ? "--pathToExecutable $executable" : '';

  return if $mgr->startStep("Loading Rad Analysis for $name", $name);

  my $args = "--configFile $configFile $optionalExecutable";

  $mgr->runPlugin($name,
                  "GUS::Community::Plugin::InsertBatchRadAnalysis",
                  $args, 
                  "Inserting Rad Analysis for $name");

}


sub InsertSimpleRadAnalysisFromConfig {
  my ($mgr, $inputDir, $configFile, $analysisResultView, $naFeatureView, $name, $sqlLdr) = @_;

  my $propertySet = $mgr->{propertySet};

  return if $mgr->startStep("Loading Rad Analysis for $name", $name);

  my $args = "--inputDir $inputDir --configFile $configFile --analysisResultView $analysisResultView --naFeatureView $naFeatureView";

  if($sqlLdr) {
    $args .= " --useSqlLdr";
  }

  $mgr->runPlugin($name,
                  "ApiCommonData::Load::Plugin::InsertAnalysisResult",
                  $args, 
                  "Inserting Rad Analysis and Result for $name");

}

sub InsertExtNaSeqFromShortOligos {
  my ($mgr,$extDbName,$extDbRlsVer,$arrayName) = @_;

  my $signal = "insertExtNaSeqFromOligos-$arrayName";

  $signal =~ s/\s//g;

  return if $mgr->startStep("Loading ExtNaSeq from Short Oligos for $signal", $signal);

  my $args = "--extDbName '$extDbName' --extDbRlsVer '$extDbRlsVer' --arrayDesignName '$arrayName'";

  $mgr->runPlugin($signal,
                  "ApiCommonData::Load::Plugin::InsertExtNaSeqFromRadShortOligo", $args,
		  "Inserting ExtNaSeq from Short Oligos for '$arrayName'");

}

# map array elements to genes
sub InsertCompositeElementNaSequences {
  my ($mgr,$arrayName,$tolerateUnmappables, $transcriptFileName) = @_;

  my $fixed_arrayName =$arrayName;
  $fixed_arrayName=~ s/\s/_/g;

  my $signal = "insertCompositeElementNaSeqs-$fixed_arrayName";

  $signal =~ s/\s//g;

  return if $mgr->startStep("Loading CompostieElementSequences for $fixed_arrayName", $signal);

  my $file = "$mgr->{dataDir}/microarray/${fixed_arrayName}To${transcriptFileName}.tab";

  my $args;
  if ($transcriptFileName) {
    $args = "--simpleMapFile $file";
  } else {
    $args = "--arrayDesignName '$arrayName' --tolerateUnmappables '$tolerateUnmappables'";
  }

  $mgr->runPlugin($signal,
                  "ApiCommonData::Load::Plugin::InsertCompositeElementNaSequences", $args,
		  "Inserting CompositeElementNaSequences for '$fixed_arrayName'");

}

sub extractSageTags {
  my ($mgr, $species, $prependSeq) = @_;

  my $propertySet = $mgr->{propertySet};

  my $signal = "ext${species}SageTags";

  return if $mgr->startStep("Extracting $species SAGE tags from GUS", $signal);

  foreach my $sageArray (@{$mgr->{sageTagArrays}->{$species}}) {
    my $dbName =  $sageArray->{name};
    my $dbVer =  $sageArray->{ver};

    my $name = $dbName;
    $name =~ s/\s/_/g;

    my $sageTagFile = "$mgr->{dataDir}/seqfiles/${name}SageTags.fsa";

    my $logFile = "$mgr->{myPipelineDir}/logs/$signal${species}.log";

    my $sql = "select s.composite_element_id, '$prependSeq' || s.tag as tag
             from rad.sagetag s,rad.arraydesign a
             where a.name = '$dbName'
             and a.version = $dbVer
             and a.array_design_id = s.array_design_id";

    my $cmd = "gusExtractSequences --outputFile $sageTagFile --idSQL \"$sql\" --verbose 2>> $logFile";

    $mgr->runCmd($cmd);
  }

  $mgr->endStep($signal);
}

sub extractArrayElements {
  my ($mgr, $species, $arrayDesignName, $arrayDesignVersion) = @_;

  my $propertySet = $mgr->{propertySet};

  my $signal = "ext${species}";

  return if $mgr->startStep("Extracting $species $arrayDesignName Array Elements tags from GUS", $signal);

  my $name = $arrayDesignName;
  $name =~ s/\s/_/g;

  my $outFile = "$mgr->{dataDir}/seqfiles/${name}ArrayElements.fsa";

  my $logFile = "$mgr->{myPipelineDir}/logs/$signal${species}.log";

  my $sql = "select s.composite_element_id, s.sequence 
             from rad.SHORTOLIGO s, Rad.ARRAYDESIGN a
             where s.sequence is not null
              and a.array_design_id = s.array_design_id
              and a.name = '$arrayDesignName'
              and a.version = '$arrayDesignVersion'";

  $mgr->runCmd("gusExtractSequences --outputFile $outFile --idSQL \"$sql\" --verbose 2>> $logFile");

  $mgr->endStep($signal);
}

sub mapSageTagsToNaSequences {
  my ($mgr, $species) = @_;

  my $propertySet = $mgr->{propertySet};

  my $signal = "map${species}SageTags";

  return if $mgr->startStep("Mapping SAGE tags to $species genome na sequences", $signal);

  foreach my $genome (@{$mgr->{genomeNaSequences}->{$species}}) {
    my $dbName =  $genome->{name};

    my $genName = $dbName;
    $genName =~ s/\s/\_/g;

    my $genomeFile = "$mgr->{dataDir}/seqfiles/${genName}GenomeNaSequences.fsa";

    foreach my $sageArray (@{$mgr->{sageTagArrays}->{$species}}) {
      my $dbName =  $sageArray->{name};

      my $tagName = $dbName;
      $tagName =~ s/\s/_/g;

      my $sageTagFile = "$mgr->{dataDir}/seqfiles/${tagName}SageTags.fsa";

      my $output = "$mgr->{dataDir}/sage/${tagName}To${genName}";

      my $cmd = "tagToSeq.pl $genomeFile $sageTagFile 2>> $output";

      $mgr->runCmd($cmd);
    }
  }
  $mgr->endStep($signal);
}

sub mapTagsToNaSequences {
  my ($mgr, $genomeFile, $tagFile, $species) = @_;

  my $propertySet = $mgr->{propertySet};
  my $signal = "map${species}TagsToNaSequences"; 
  
  return if $mgr->startStep("Mapping tags to genome na sequences", $signal);

  my $output = "$mgr->{dataDir}/microarray/$signal.mapping";

  my $cmd = "tagToSeq.pl $genomeFile $tagFile 2>> $output";

  $mgr->runCmd($cmd);
  $mgr->endStep($signal);
}

sub mapArrayElementsToNaSequences {
  my ($mgr, $species, $name, $seqType, $arrayDesignName, $minPercent, $minLength, $topOnly) = @_;

  my $top = "-top" if($topOnly);

  $arrayDesignName =~ s/\s/_/g;

  my $type = ucfirst($seqType);
  my $transcriptFile = "$mgr->{dataDir}/seqfiles/${name}${type}.fsa";
  my $blastDb = "$mgr->{dataDir}/microarray/${name}${type}.fsa";

  my $arrayElementsFile =  "$mgr->{dataDir}/seqfiles/${arrayDesignName}ArrayElements.fsa";

  my $propertySet = $mgr->{propertySet};

  my $wuBlastPath = $propertySet->getProp('wuBlastPath');

  my $signal = "map${species}ArrayElements";

  return if $mgr->startStep("Mapping ArrayElement sequences to $species Transcript Spliced na sequences", $signal);

  my $simOutput = "$mgr->{dataDir}/microarray/${arrayDesignName}To${name}";

  my $tabOutput = "$mgr->{dataDir}/microarray/${arrayDesignName}To${name}.tab";
  my $seqOutput = "$mgr->{dataDir}/microarray/${arrayDesignName}To${name}.seq";

  $mgr->runCmd("$wuBlastPath/xdformat -n -o $blastDb $transcriptFile");  
  $mgr->runCmd("$wuBlastPath/blastn $blastDb $arrayElementsFile $top > $simOutput");
  $mgr->runCmd("blastnToSeq.pl --blast_result_file $simOutput --min_percent $minPercent --min_length $minLength >$tabOutput 2>$seqOutput");

  $mgr->endStep($signal);
}

sub loadSageTagMap {
  my ($mgr, $species) = @_;

  my $signal = "load${species}SageTagMap";

  return if $mgr->startStep("Loading SAGE tags to $species sage na sequences maps", $signal);

  my $propertySet = $mgr->{propertySet};

  foreach my $genome (@{$mgr->{genomeNaSequences}->{$species}}) {
    my $dbName =  $genome->{name};
    my $genName = $dbName;
    $genName =~ s/\s/\_/g;

    foreach my $sageArray (@{$mgr->{sageTagArrays}->{$species}}) {
      my $dbName =  $sageArray->{name};
      my $tagName = $dbName;
      $tagName =~ s/\s/_/g;
      my $inputFile = "$mgr->{dataDir}/sage/${tagName}To${genName}";

      my $args = "--tagToSeqFile $inputFile";

      $mgr->runPlugin("load${tagName}To${genName}SageTagMap",
		      "ApiCommonData::Load::Plugin::LoadSageTagFeature", $args,
		      "Loading ${tagName}To${genName} SAGE Tag map results");
    }
  }
  $mgr->endStep($signal);
}

sub loadExpressionFeature {
  my ($mgr, $tagToSeqOutputFile, $extDbSpec, $featureType, $species) = @_;

  my $signal = "load${species}ExpressionFeature";

  return if $mgr->startStep("Loading tags to $species na sequences maps", $signal);

  my $propertySet = $mgr->{propertySet};

  my $inputFile = "$mgr->{dataDir}/microarray/$tagToSeqOutputFile";

  my $args = "--tagToSeqFile $inputFile --extDbSpec \'$extDbSpec\' --featureType $featureType";

  $mgr->runPlugin("load${species}ExpressionFeature",
		      "ApiCommonData::Load::Plugin::LoadExpressionFeature", $args,
		      "Loading Microarray Tag map results");
  $mgr->endStep($signal);
}

sub concatFilesGeneral {
  my ($mgr, $files, $fileDir, $catFile, $catFileDir) = @_;

  $files =~ s/(\S+)/$fileDir\/$1/g;

  my $signal = "concat$catFile";

  return if $mgr->startStep("Creating concatenated file, $catFile in $catFileDir", $signal);

  my $cmd = "cat $files > $catFileDir/$catFile";

  $mgr->runCmd($cmd);

  $mgr->endStep($signal);
}

sub concatFiles {
  my ($mgr,$files,$catFile) = @_;

  #$files =~ s/(\S+)/$1/g;

  my $propertySet = $mgr->{propertySet};

  my $projRel = $propertySet->getProp('release');
  
  my $siteFileDir = $propertySet->getProp('siteFileDir');

  my $signal = "concat".basename($catFile);

  $signal =~ s/-$projRel//g;

  return if $mgr->startStep("Creating concatenated file, $catFile", $signal);

  my $cmd = "cat $files > $siteFileDir/$catFile";

  $mgr->runCmd($cmd);

  $mgr->endStep($signal);
}


sub extractNRDB {
  my ($mgr) = @_;
  my $propertySet = $mgr->{propertySet};

  my $extDbName = $propertySet->getProp('nrdbDbName');
  my $extDbRlsVer = $propertySet->getProp('nrdbDbRlsVer');
  $mgr->{nrdbDbRlsId} =  &getDbRlsId($mgr,$extDbName,$extDbRlsVer) unless $mgr->{nrdbDbRlsId};
  my $nrdbDbRlsId = $mgr->{nrdbDbRlsId};

  my $sql = "select aa_sequence_id,'source_id='||source_id,'secondary_identifier='||secondary_identifier,description,'length='||length,sequence from dots.ExternalAASequence where external_database_release_id = $nrdbDbRlsId";

  &extractProteinSeqs($mgr,"nr",$sql);
}

sub extractProteinSeqs {
  my ($mgr,$name,$sql,$minLength,$maxStopCodonPercent, $noSeq) = @_;
  my $propertySet = $mgr->{propertySet};

  my $signal = "${name}Extract";

  return if $mgr->startStep("Extracting $name protein sequences from GUS", $signal);

  my $seqFile = $noSeq ? "$mgr->{dataDir}/seqfiles/${name}" : "$mgr->{dataDir}/seqfiles/${name}.fsa";
  my $logFile = "$mgr->{myPipelineDir}/logs/${name}Extract.log";

  my $cmd = "gusExtractSequences --outputFile $seqFile --idSQL \"$sql\" --verbose";

  $cmd .= " --noSequence" if $noSeq;

  $cmd .= " --minLength $minLength " if $minLength;
  $cmd .= " --maxStopCodonPercent $maxStopCodonPercent " if $maxStopCodonPercent;

  $cmd .= " 2>> $logFile";

  print STDERR "$cmd\n";

  $mgr->runCmd($cmd);

  $mgr->endStep($signal);
}


sub startProteinBlastOnComputeCluster {
  my ($mgr,$queryFile,$subjectFile,$queue,$ppn) = @_;
  my $propertySet = $mgr->{propertySet};

  my $name = $queryFile . "-" . $subjectFile;

  $name = ucfirst($name);
  my $signal = "startBlast$name";
  return if $mgr->startStep("Starting $name blast on cluster", $signal);

  $mgr->endStep($signal);
  my $gusHome = '$GUS_HOME';
  my $clusterCmdMsg = "bsub $gusHome/bin/distribjobSubmit $mgr->{clusterDataDir}/logs/${queryFile}-${subjectFile}.log --numNodes NUMBER_OF_NODES --runTime 0 --propFile $mgr->{clusterDataDir}/similarity/${queryFile}-${subjectFile}/input/controller.prop --parallelInit 4 --mpn 8 --q normal 1";
 # my $clusterCmdMsg = "runBlastSimilarities $mgr->{clusterDataDir} NUMBER_OF_NODES $queryFile $subjectFile $queue $ppn";

  my $clusterLogMsg = "monitor $mgr->{clusterDataDir}/logs/*.log and xxxxx.xxxx.stdout";

  $mgr->exitToCluster($clusterCmdMsg, $clusterLogMsg, 1);
}

sub startGenomeAlignOnComputeCluster {
  my ($mgr,$queryFile,$targetDir,$queue,$ppn) = @_;
  my $propertySet = $mgr->{propertySet};

  my $name = $queryFile . "-" . $targetDir;

  $name = ucfirst($name);
  my $signal = "startAlign$name";
  return if $mgr->startStep("Starting $name alignment on cluster", $signal);

  $mgr->endStep($signal);

  my $clusterCmdMsg = "runGenomeAlignWithGfClient --ppn $ppn --buildDir $mgr->{clusterDataDir} --numnodes NUMBER_OF_NODES --query $queryFile --target $targetDir --queue $queue";
  my $clusterLogMsg = "monitor $mgr->{clusterDataDir}/logs/*.log";

  $mgr->exitToCluster($clusterCmdMsg, $clusterLogMsg, 1);
}

sub startRepeatMaskOnComputeCluster {
  my ($mgr, $queryFile, $queue, $repeatMaskSubdir, $ppn) = @_;
  my $propertySet = $mgr->{propertySet};

  my $signal = "startRepeatMask$queryFile";
  return if $mgr->startStep("Starting $queryFile repeat mask on cluster", $signal);
 
  my $buildDir = $mgr->{clusterDataDir};
  if($repeatMaskSubdir){
      $buildDir .= "/$repeatMaskSubdir";
  }
  my $clusterCmdMsg = "runRepeatMask --buildDir $buildDir --numnodes NUMBER_OF_NODES --query $queryFile --queue $queue --ppn $ppn";
  my $clusterLogMsg = "monitor $mgr->{clusterDataDir}/logs/*.log";

  $mgr->endStep($signal);
  $mgr->exitToCluster($clusterCmdMsg, $clusterLogMsg, 1);
}

sub startGfClientWORepMaskOnComputeCluster {
  my ($mgr,$queryFile,$targetDir,$queue, $ppn) = @_;
  my $propertySet = $mgr->{propertySet};

  my $name = $queryFile . "-" . $targetDir;

  $name = ucfirst($name);
  my $signal = "startAlign$name";
  return if $mgr->startStep("Starting $name alignment on cluster", $signal);

  $mgr->endStep($signal);

  my $clusterCmdMsg = "runGfClientWORepMask --buildDir $mgr->{clusterDataDir} --numnodes NUMBER_OF_NODES --query $queryFile --target $targetDir --queue $queue --ppn $ppn";
  my $clusterLogMsg = "monitor $mgr->{clusterDataDir}/logs/*.log";

  $mgr->exitToCluster($clusterCmdMsg, $clusterLogMsg, 1);
}


sub documentTRNAScan {
  my ($mgr, $version, $options) = @_;

  my $documentation =
    { name => "tRNAScan-SE",
      input => "Transcript or genomic sequence file in fasta format",
      output => "tab delimited file with the type of tRNA, anticodon, score, and locations on the sequences analyzed",
      descrip => "tRNAscan-SE identifies transfer RNA genes in genomic DNA or RNA sequences.",
      tools => [
                { name => "tRNAScan-SE",
                  version => $version,
                  params => $options,
                  url => "http://selab.wustl.edu/cgi-bin/selab.pl?mode=software#trnascan",
                  pubmedIds => "9023104",
                  credits => ""
                }
               ]
    };

  $mgr->documentStep("signalP", $documentation); 

}

sub startTRNAscanOnComputeCluster {
  my ($mgr,$subjectFile,$queue, $ppn) = @_;
  my $propertySet = $mgr->{propertySet};

  my $signal = "start${subjectFile}TRNAscan";
  return if $mgr->startStep("Starting tRNAscan of $subjectFile on cluster", $signal);

  $mgr->endStep($signal);

  my $clusterCmdMsg = "runTRNAscan $mgr->{clusterDataDir} NUMBER_OF_NODES $subjectFile $queue, $ppn";
  my $clusterLogMsg = "monitor $mgr->{clusterDataDir}/logs/*.log and xxxxx.xxxx.stdout";

  $mgr->exitToCluster($clusterCmdMsg, $clusterLogMsg, 1);
}

sub startHMMPfamOnComputerCluster {
  my ($mgr,$queryFile,$subjectFile,$queue) = @_;
  my $propertySet = $mgr->{propertySet};

  my $query = $queryFile;

  $query =~ s/\.\w+//g;

  my $subject = $subjectFile;

  $subject =~ s/\.\w+//g;

  my $name = $query . "-" . $subject;

  $name = ucfirst($name);
  my $signal = "startHMMPfam$name";
  return if $mgr->startStep("Starting $name hmmpfam on cluster", $signal);

  $mgr->endStep($signal);

  my $clusterCmdMsg = "runPfam $mgr->{clusterDataDir} NUMBER_OF_NODES $queryFile $subjectFile $queue";
  my $clusterLogMsg = "monitor $mgr->{clusterDataDir}/logs/*.log and xxxxx.xxxx.stdout";

  $mgr->exitToCluster($clusterCmdMsg, $clusterLogMsg, 1);
}

sub loadHMMPfamOutput {
  my ($mgr,$queryFile,$subjectFile,$algName,$algVer,$extDbRlsName,$extDbRlsVer) = @_;

  my $query = $queryFile;

  $query =~ s/\.\w+//g;

  my $subject = $subjectFile;

  $subject =~ s/\.\w+//g;

  my $name = $query . "-" . $subject;

  my $args = "--data_file $mgr->{dataDir}/pfam/$name/master/mainresult/hmmpfam.out --algName '$algName' --algVer '$algVer'  --algDesc 'hmmpfam  searches queries against a PFAM domain database' --queryTable  'DoTS.TranslatedAASequence' --extDbRlsName '$extDbRlsName' --extDbRlsVer '$extDbRlsVer'";

  $mgr->runPlugin("loadHMMPfamOutput_$name",
		  "ApiCommonData::Load::Plugin::LoadPfamOutput", $args,
		  "Loading $name hmmpfam output");
}

## for use from the cluster ...takes in a name where the master/mainresult/blastSimilarity.out is found
sub loadProteinBlast {
  my ($mgr, $name, $queryTable, $subjectTable, 
      $queryTableSrcIdCol,$subjectTableSrcIdCol, # optional, use '' to bypass
      $queryDbName, $queryDbRlsVer, # optional if no queryTableSrcIdCol
      $subjectDbName, $subjectDbRlsVer,	# optional if no subjectTableSrcIdCol
      $addedArgs,$restart) = @_;
      
  my $file = (-e "$mgr->{dataDir}/similarity/$name/master/mainresult/blastSimilarity.out.gz") ? "$mgr->{dataDir}/similarity/$name/master/mainresult/blastSimilarity.out.gz" : "$mgr->{dataDir}/similarity/$name/master/mainresult/blastSimilarity.out";
  

  &loadBlastSimilarities($mgr, $name, $file, $queryTable, $subjectTable, $queryTableSrcIdCol,$subjectTableSrcIdCol, $queryDbName, $queryDbRlsVer, $subjectDbName, $subjectDbRlsVer, $addedArgs,$restart);

}

##takes in a file name
sub loadBlastSimilarities {
  my ($mgr, $name, $file, $queryTable, $subjectTable, # $name is the name of the signal
      $queryTableSrcIdCol,$subjectTableSrcIdCol, # optional, use '' to bypass
      $queryDbName, $queryDbRlsVer, # optional if no queryTableSrcIdCol
      $subjectDbName, $subjectDbRlsVer,	# optional if no subjectTableSrcIdCol
      $addedArgs,$restart) = @_;
      
  
  my $restartAlgInvs = "--restartAlgInvs $restart" if $restart;

  my $queryColArg = "--queryTableSrcIdCol $queryTableSrcIdCol" if $queryTableSrcIdCol;

  my $subjectColArg = "--subjectTableSrcIdCol $subjectTableSrcIdCol" if $subjectTableSrcIdCol;

  my $qryDbNameArg = " --queryExtDbName '$queryDbName'" if $queryDbName;
  my $qryRlsArg = " --queryExtDbRlsVer '$queryDbRlsVer'" if $queryDbRlsVer;
  my $sbjDbNameArg = " --subjectExtDbName '$subjectDbName'" if $subjectDbName ne '';
  my $sbjRlsArg = " --subjectExtDbRlsVer '$subjectDbRlsVer'" if $subjectDbRlsVer ne '';
  
  my $args = "--file $file $restartAlgInvs --queryTable $queryTable $queryColArg $qryDbNameArg $qryRlsArg --subjectTable $subjectTable $subjectColArg $sbjDbNameArg $sbjRlsArg $addedArgs";

  $mgr->runPlugin("loadSims_$name",
		  "GUS::Supported::Plugin::InsertBlastSimilarities", $args,
		  "Loading $name similarities");
}

sub calculateTranslatedProteinSequence {
  my ($mgr, $dbName,$dbRlsVer,$soCvsVersion,$overwrite,$genCodeId) = @_;

  my $args = "--sqlVerbose --extDbRlsName '$dbName' --extDbRlsVer '$dbRlsVer' --soCvsVersion $soCvsVersion $overwrite";

  $args .= " --ncbiGeneticCodeId $genCodeId" if ($genCodeId);

  $dbName =~ s/\s//g;

  $mgr->runPlugin("calculate${dbName}Translations",
		  "GUS::Supported::Plugin::CalculateTranslatedAASequences", $args,
		  "Calculating $dbName protein translations");
}

sub calculateProteinMolWt {
  my ($mgr,$species,$dbName,$dbRlsVer,$table) = @_;

  my $args = "--extDbRlsName '$dbName' --extDbRlsVer '$dbRlsVer' --seqTable $table";

  $mgr->runPlugin("calc${species}ProtMolWt",
                  "GUS::Supported::Plugin::CalculateAASequenceMolWt", $args,
                  "Calculating $species translated aa sequence MW in $table");
}

sub calculateACGT {
  my ($mgr,$nullsOnly) = @_;

  my $args = "--sqlVerbose";

  $args .= " --$nullsOnly" if ($nullsOnly);
  $mgr->runPlugin("calculateACGT",
                  "ApiCommonData::Load::Plugin::CalculateACGTContent", $args,
                  "Calculating ACGT content of na sequences");
}

sub runExportPred {
  my ($mgr,$species) = @_;

  my $propertySet = $mgr->{propertySet};

  my $signal = "exportPred$species";

  return if $mgr->startStep("Predicting the exportome of $species", $signal);

  my $exportpredPath = $propertySet->getProp('exportpredPath');

  my $name = "${species}AnnotatedProteins.fsa";

  my $outputFile = $name;

  $outputFile =~ s/\.\w+$/\.exptprd/;

  my $cmd = "${exportpredPath}/exportpred --input=$mgr->{dataDir}/seqfiles/$name --output=$mgr->{dataDir}/misc/$outputFile";

  $mgr->runCmd($cmd);

  $mgr->endStep($signal);
}

sub documentExportPred {
  my ($mgr,$version) = @_;

  my $description = "Program that predicts the exported proteins of Plasmodium.";

  my $documentation =
    { name => "ExportPred",
      input => "fasta file of protein sequences",
      output => "file containing export sequences and scores",
      descrip => $description,
      tools => [
		{ name => "ExportPred",
		  version => $version,
		  params => "default",
		  url => "http://bioinf.wehi.edu.au/exportpred/",
		  pubmedIds => "16507167",
		  credits => ""
		}
	       ]
    };
  $mgr->documentStep("exportpred", $documentation);
}

sub loadExportPredResults {
  my ($mgr,$species,$sourceIdDb,$genDb) = @_;

  my $propertySet = $mgr->{propertySet};

  my $name = "${species}AnnotatedProteins.exptprd";

  my $signal = "loadExportPred$species";

  my $inputFile = "$mgr->{dataDir}/misc/$name";

  my $args = "--inputFile  $inputFile --seqTable DoTS::AASequence --seqExtDbRlsSpec '$sourceIdDb' --extDbRlsSpec '$genDb'";

  $mgr->runPlugin($signal,
		  "ApiCommonData::Load::Plugin::InsertExportPredFeature",
		  "$args",
		  "Loading exportpred results for $name");
}

sub documentGeneAliases {
  my ($mgr) = @_;

  #   my $documentation =
  #     { name => "Tracking of Gene Aliases",
  #       input => "Gene identifiers and other aliases",
  #       output => "a corrected list of gene aliases",
  #       descrip => "Gene identifiers (or IDs) have evolved over time.  PlasmoDB attempts to provide a consistent set of IDs for each Gene, including older, outdated IDs.  Each gene has exactly one current 'systematic' ID.  All other IDs are treated as 'aliases.'  To ensure the uniqueness of each alias, we remove any that could refer to more than one current systematic ID.",
  #       tools => []
  #     };

  #   $mgr->documentStep('geneAliases', $documentation);


}

sub fixGeneAliases {
  my ($mgr,$files) = @_;

  my $path = "$mgr->{dataDir}/misc/";

  $files =~ s/(\w|\.)+/${path}$&/g;

  my $args = "--mappingFiles $files";

  my $signal = "correctGeneAliases";

  $mgr->runPlugin($signal,
                  "ApiCommonData::Load::Plugin::CorrectGeneAliases", $args,
                  "Correct gene aliases in GUS");
}

sub predictAndPrintTranscriptSequences {
  my ($mgr,$species,$dbName,$dbRlsVer,$type, $flag) = @_;

  my $cds = $type eq 'cds' ? "--cds" : "";

  my $noReversed = $flag eq 'noReversed' ? "--noReversed" : "";

  $type = $type eq 'transcripts' ? ucfirst($type) : uc($type);

  my $file = "$mgr->{dataDir}/seqfiles/${species}Annotated${type}.fsa";

  my $args = "--extDbName '$dbName' --extDbRlsVer '$dbRlsVer' --sequenceFile $file $cds $noReversed";

  $mgr->runPlugin("predict${species}$type",
		  "GUS::Supported::Plugin::ExtractTranscriptSequences", $args,
		  "Predict and print $species $type");
}


sub predictAndPrintPredictedTranscriptSequences {
  my ($mgr,$species,$dbName,$dbRlsVer,$type,$seqDbName,$seqRlsVer,$flag) = @_;

  my $cds = $type eq 'cds' ? "--cds" : "";

  my $noReversed = $flag eq 'noReversed' ? "--noReversed" : "";

  $type = $type eq 'transcripts' ? ucfirst($type) : uc($type);

  my $file = "$mgr->{dataDir}/seqfiles/${species}Predicted${type}.fsa";

  my $args = "--extDbName '$dbName' --extDbRlsVer '$dbRlsVer' --seqExtDbName '$seqDbName' --seqExtDbRlsVer '$seqRlsVer' --sequenceFile $file $cds $noReversed";

  $mgr->runPlugin("determinePredicted${species}$type",
		  "GUS::Supported::Plugin::ExtractTranscriptSequences", $args,
		  "Determine and print $species $type from prediction algorithm");
}

sub formatBlastDownloadFile {
  my ($mgr,$inputFile,$inputFileDir,$link, $arg, $species, $project) = @_;

  my $propertySet = $mgr->{propertySet};
  my $release = $propertySet->getProp('projectRelease');
  my $projectDB = $project ? $project : $propertySet->getProp('projectDB');
  my $siteFileDir = $propertySet->getProp('siteFileDir');

  my $signal = "format$inputFile";

  $signal =~ s/-$release//g;

  return if $mgr->startStep("Formatting $inputFile for blast", $signal);

  my $blastBinDir = $propertySet->getProp('ncbiBlastPath');

  my $inputFile1  = "$siteFileDir/$inputFileDir/$inputFile";

  my $outputDir = "$siteFileDir/webServices/$projectDB/$release/$species";

  $mgr->runCmd("mkdir -p $outputDir");

  die "Failed to create $outputDir.\n" unless (-e $outputDir);

  my $fastalink1 = "$outputDir/$link";

  $mgr->runCmd("ln -s $inputFile1 $fastalink1");
  $mgr->runCmd("$blastBinDir/formatdb -i $fastalink1 -p $arg");
  $mgr->runCmd("rm -rf $fastalink1");

  $mgr->endStep($signal);
}

sub formatncbiBlastFile {
  my ($mgr,$file,$fileDir,$link,$arg) = @_;

  my $propertySet = $mgr->{propertySet};

  my $projRel = $propertySet->getProp('release');

  my $signal = "format$file";

  $signal =~ s/-$projRel//g;

  return if $mgr->startStep("Formatting $file for blast", $signal);

  my $blastBinDir = $propertySet->getProp('ncbiBlastPath');
  
  my $fastalink1 = "$mgr->{dataDir}/blastSite/$link";

  $mgr->runCmd("mv $mgr->{dataDir}/blastSite/$file $fastalink1");
  
  $mgr->runCmd("$blastBinDir/formatdb -i $fastalink1 -p $arg");

  $mgr->endStep($signal);
}

sub formatBlastFile {
  my ($mgr,$file,$fileDir,$link,$arg) = @_;

  my $propertySet = $mgr->{propertySet};

  my $projRel = $propertySet->getProp('release');

  my $signal = "format$file";

  $signal =~ s/-$projRel//g;

  return if $mgr->startStep("Formatting $file for blast", $signal);

  my $blastBinDir = $propertySet->getProp('ncbiBlastPath');

  my $outputFile1  = "$mgr->{dataDir}/$fileDir/$file";

  my $fastalink1 = "$mgr->{dataDir}/blastSite/$link";

  $mgr->runCmd("ln -s $outputFile1 $fastalink1");
  $mgr->runCmd("$blastBinDir/formatdb -i $fastalink1 -p $arg");
  $mgr->runCmd("rm -rf $fastalink1");

  $mgr->endStep($signal);
}

sub formatBlastFileForOrtho {
  my ($mgr,$file,$fileDir,$link,$arg) = @_;

  my $propertySet = $mgr->{propertySet};

  my $projRel = $propertySet->getProp('release');

  my $signal = "format$file";

  $signal =~ s/-$projRel//g;

  return if $mgr->startStep("Formatting $file for blast", $signal);

  my $blastBinDir = $propertySet->getProp('ncbiBlastPath');

  my $outputFile1  = "$fileDir/$file";

  my $fastalink1 = "$mgr->{dataDir}/blastSite/$link";

  $mgr->runCmd("ln -s $outputFile1 $fastalink1");
  $mgr->runCmd("$blastBinDir/formatdb -i $fastalink1 -p $arg");
  $mgr->runCmd("rm -rf $fastalink1");

  $mgr->endStep($signal);
}
sub xdformatDownloadFileForBlastSite {
  my ($mgr, $species, $inputFile, $formattedFile, $type, $project) = @_;

  my $signal = "${formattedFile}XDFormat";

  return if $mgr->startStep("Formatting $species $formattedFile", $signal);

  my $propertySet = $mgr->{propertySet};
  my $release = $propertySet->getProp('projectRelease');
  my $projectDB = $project ? $project : $propertySet->getProp('projectDB');
  my $siteFileDir = $propertySet->getProp('siteFileDir');
  my $blastPath = $propertySet->getProp('wuBlastPath');

  my $blastDir = "$siteFileDir/webServices/$projectDB/release-$release/blast";

  $mgr->runCmd("mkdir -p $blastDir");

  die "Failed to create $blastDir.\n"  unless (-e $blastDir);

  my $inputFile = "$siteFileDir/downloadSite/$projectDB/release-$release/$species/fasta/$inputFile";

  my $formattedFile = "${blastDir}/$formattedFile";

  my $logFile = "$mgr->{myPipelineDir}/logs/${signal}.log";

  if ($type =~/\-p/){

        my $tempFile = "$inputFile.temp";

        $mgr->runCmd("cat $inputFile | perl -pe 'unless (/^>/){s/J/X/g;}' > $tempFile");

        $mgr->runCmd("$blastPath/xdformat $type -o $formattedFile $tempFile 2>> $logFile");

        $mgr->runCmd("rm -fr $tempFile");

  }else {

      $mgr->runCmd("$blastPath/xdformat $type -o $formattedFile $inputFile 2>> $logFile");
  }

  $mgr->endStep($signal);
}

##for the following you need to check out and build WDK and ApiCommonWebsite and ApiCommonData

sub xdformat {
# Note '-C X' to handle invalid letter codes (e.g. J in Cparvum)
  #  xdformat -C X  -p -t CparvumProteins CparvumAnnotatedProteins.fsa 

  my ($mgr,$type,$seqFile) = @_;

  my $propertySet = $mgr->{propertySet};

  my $signal = "xdFormat$seqFile";

  return if $mgr->startStep("Formatting $seqFile for blast", $signal);

  my $file = "$mgr->{dataDir}/seqfiles/$seqFile";

  my $blastPath = $propertySet->getProp('wuBlastPath');

  $mgr->runCmd("$blastPath/xdformat -$type $file");

  $mgr->endStep($signal);
}

sub extractKeywordSearchFiles {
  my ($mgr,$filePrefix,$commentSchema,$dbLink,$projectId,$gusConfigFile) = @_;

  my $propertySet = $mgr->{propertySet};

  my $signal = "extractSearchFiles";

  return if $mgr->startStep("Extracting flat files for keyword search", $signal);

  my $release = $propertySet->getProp('projectRelease');
  my $projectDB = $propertySet->getProp('projectDB');
  my $siteFileDir = $propertySet->getProp('siteFileDir');

  my $textSearchDir = "$siteFileDir/webServices/$projectDB/release-$release/textSearch";

  $mgr->runCmd("mkdir -p $textSearchDir");

  die "Failed to create $textSearchDir.\n"  unless (-e $textSearchDir);

  my $cmd = "extractTextSearchFiles --outputDir $textSearchDir --projectId $projectId ";
  $cmd .= "--gusConfigFile $gusConfigFile" if ($gusConfigFile);
  $cmd .= "--outputPrefix $filePrefix " if ($filePrefix);


  $cmd .= " --commentSchema $commentSchema --commentDblink $dbLink" if ($commentSchema && $dbLink);

  $mgr->runCmd($cmd);

  $mgr->endStep($signal);
}

sub orthomclGroupKeywords {
  my ($mgr) = @_;

  my $signal = "insertOrthomclGroupKeywords";

  $mgr->runPlugin($signal,
		  "OrthoMCLData::Load::Plugin::InsertGroupKeywords", ,
		  "Inserting rows into apidb.orthomclgroupkeyword");

}


sub extractCommentsFiles {
  my ($mgr,$filePrefix,$commentSchema,$dbLink,$projectId,$gusConfigFile) = @_;

  my $propertySet = $mgr->{propertySet};

  my $signal = "extractCommentsFiles";

  return if $mgr->startStep("Extracting flat comments files for text keyword search", $signal);

  my $release = $propertySet->getProp('projectRelease');
  my $projectDB = $propertySet->getProp('projectDB');
  my $siteFileDir = $propertySet->getProp('siteFileDir');

  my $textSearchDir = "$siteFileDir/webServices/$projectDB/release-$release/textSearch";

  $mgr->runCmd("mkdir -p $textSearchDir");

  die "Failed to create $textSearchDir.\n"  unless (-e $textSearchDir);

  my $cmd = "extractCommentsFile --outputDir $textSearchDir --projectId $projectId --commentSchema $commentSchema";
  $cmd .= " --gusConfigFile $gusConfigFile" if ($gusConfigFile);
  $cmd .= " --outputPrefix $filePrefix " if ($filePrefix);


  $cmd .= " --commentSchema $commentSchema --commentDblink $dbLink" if ($commentSchema && $dbLink);

  $mgr->runCmd($cmd);

  $mgr->endStep($signal);
}




sub loadDbRefAndDbRefNaSequence {
  my ($mgr, $pattern1, $pattern2, $file, $seqDbName, $seqDbRlsVer,$dbrefDbName, $dbrefDbRlsVer, $table, $att) = @_;

  my $propertySet = $mgr->{propertySet};

  my $args = "--mappingfile $file --table $table --pattern1 '$pattern1' --pattern2 '$pattern2' --seqExtDbName $seqDbName --seExtDbRlsVer $seqDbRlsVer --dbRefExtDbName $dbrefDbName --dbRefExtDbRlsVer $dbrefDbRlsVer --seqAtt $att";

  $mgr->runPlugin("loading$file", "ApiCommonData::Load::Plugin::LoadDbRefDbRefNASequence", $args, "loading $file mapping");
}


sub modifyDownloadFile {
  my ($mgr,$dir,$file,$type,$extDb,$extDbVer, $database,$sequenceTable,$seqExtDb, $seqExtDbVer) = @_;

  my $propertySet = $mgr->{propertySet};

  my $release = $propertySet->getProp('release');

  my $signal = "modify$file";

  return if $mgr->startStep("Modifying $file for download", $signal);

  my $inFile = "$mgr->{dataDir}/seqfiles/$file";

  die "$inFile doesn't exist\n" unless (-e $inFile);

  my $outFile = $file;

  $outFile =~ s/\.\w+\b//;
  $outFile .= "_${database}-${release}.fasta";

  my $outFile = "$mgr->{dataDir}/downloadSite/$dir/$outFile";

  $mgr->runCmd("mkdir -p $mgr->{dataDir}/downloadSite/$dir");

  my $cmd = "modifyDefLine -infile $inFile -outfile $outFile -extDb '$extDb' -extDbVer '$extDbVer' -type $type -sequenceTable $sequenceTable";

  $cmd .= " -seqExtDb '$seqExtDb' -seqExtDbVer $seqExtDbVer" if ($seqExtDb && $seqExtDbVer);

  $mgr->runCmd($cmd);

  $mgr->endStep($signal);
}

sub writeGeneAliasFile {

  my ($mgr,$extDbSpec,$project, $dir, $species, $dbRefNAFeatureExtDbSpec) = @_;

  my $propertySet = $mgr->{propertySet};

  my $release = $propertySet->getProp('projectRelease');

  my $projectDB = $project ? $project : $propertySet->getProp('projectDB');

  my $siteFileDir = $propertySet->getProp('siteFileDir');

  my $signal =  $species ? "write${species}GeneAliasFile" : "write${dir}GeneAliasFile";

  return if $mgr->startStep("Writing $dir gene alias file for download site", $signal);

  my $outFile = $species ? "$siteFileDir/downloadSite/$projectDB/release-$release/$dir/${species}GeneAlias_$projectDB-${release}.txt" : "$siteFileDir/downloadSite/$projectDB/release-$release/$dir/${dir}GeneAlias_$projectDB-${release}.txt";

  my  $cmd ="getGeneAliases --extDbSpec '$extDbSpec' --outfile $outFile";
  
  $cmd .= " --dbRefNAFeatureExtDbSpec $dbRefNAFeatureExtDbSpec" if $dbRefNAFeatureExtDbSpec;

  $mgr->runCmd($cmd);

  $mgr->endStep($signal);
}

sub writeSequenceAliasFile {

  my ($mgr,$extDbSpec,$project, $dir, $species, $naSequenceExtDbSpec) = @_;

  my $propertySet = $mgr->{propertySet};

  my $release = $propertySet->getProp('projectRelease');

  my $projectDB = $project ? $project : $propertySet->getProp('projectDB');

  my $siteFileDir = $propertySet->getProp('siteFileDir');

  my $signal =  $species ? "write${species}SequenceAliasFile" : "write${dir}SequenceAliasFile";

  return if $mgr->startStep("Writing $dir sequence alias file for download site", $signal);

  my $outFile = $species ? "$siteFileDir/downloadSite/$projectDB/release-$release/$dir/${species}SequenceAlias_$projectDB-${release}.txt" : "$siteFileDir/downloadSite/$projectDB/release-$release/$dir/${dir}SequenceAlias_$projectDB-${release}.txt";

  my  $cmd ="getSequenceAliases --naSequenceExtDbSpec '$extDbSpec' --outfile $outFile";
  
  $cmd .= " --dbRefNASequenceExtDbSpec '$naSequenceExtDbSpec'" if $naSequenceExtDbSpec;

  $mgr->runCmd($cmd);

  $mgr->endStep($signal);
}

sub modifyGenomeDownloadFile {
  my ($mgr,$dir,$file,$type,$extDb,$extDbVer, $database,$sequenceTable) = @_;

  my $propertySet = $mgr->{propertySet};

  my $release = $propertySet->getProp('release');

  my $signal = "modify$file";

  return if $mgr->startStep("Modifying $file for download", $signal);

  my $inFile = "$mgr->{dataDir}/seqfiles/$file";

  my $outFile = "$mgr->{dataDir}/downloadSite/$dir/${dir}Genomic_${database}-${release}.fasta";

  $mgr->runCmd("mkdir -p $mgr->{dataDir}/downloadSite/$dir");

  $mgr->runCmd("modifyGenomeDefLine -infile $inFile -outfile $outFile -extDb '$extDb' -extDbVer '$extDbVer' -type $type -sequenceTable $sequenceTable");

  $mgr->endStep($signal);
}

sub makeGFF {
   my ($mgr,$model,$questions,$speciesName,$file,$dir) = @_;

   my $propertySet = $mgr->{propertySet};

   my $signal = "gff$file";

   my $log = "$mgr->{myPipelineDir}/logs/${signal}.log";

   my $db = $model;

   $db =~ s/bModel/B/;

   $file = "$mgr->{dataDir}/downloadSite/${dir}/$file";

   return if $mgr->startStep("Making gff $file file", $signal);

   my $release = $propertySet->getProp('release');

   $file .= "_${db}-${release}.gff";

   $mgr->runCmd("gffDump $model $questions \'$speciesName\' $file 2>> $log");

   $mgr->endStep($signal);
}

sub removeFile {
  my ($mgr,$file,$fileDir) = @_;

  my $signal = "remove$file";

  return if $mgr->startStep("removing $file from $fileDir", $signal);

  $mgr->runCmd("rm -rf $mgr->{dataDir}/${fileDir}/$file");

  $mgr->endStep($signal);
}

sub modifyFile {
  my ($mgr,$inFile,$outFile,$fileDir,$regex) = @_;

  my $signal = "modify$inFile";

  return if $mgr->startStep("modifying ${fileDir}/$inFile", $signal);

  $mgr->runCmd("cat ${fileDir}/$inFile | perl -pe 's/$regex/' > ${fileDir}/$outFile");

  $mgr->endStep($signal);
}


sub documentMercatorAndMavid {
  my ($mgr,$version) = @_;
  my $description = "Mercator and Mavid are used for comparative genome analysis. Mercator uses genomes and exon coordinates to create exon translations for protein BLAT alignments and outputs orthology maps. The orthology maps are used as a guide for Mavid which also uses a phylogentic newick tree to generate gene alignments.";
  my $documentation =    { name => "MercatorAndMavid",
                         input => "genomes, exon coordinates, and a phylogentic newick tree",
			   output => "file of pairwise synteny alignments with defined spans",
			   descrip => $description,
                           tools => [{ name => "MercatorAndMavid",
				       version => $version,
				       params => "",
				       url => "",
				       pubmedIds => "17993677",
				       credits => " Dewey CN.
                                                    Aligning multiple whole genomes with Mercator and MAVID. 
                                                    Methods in Molecular Biology. 395:221-36, 2007."}]};

 $mgr->documentStep("MercatorAndMavid", $documentation);
}

sub fixMercatorOffsetsInGFF {
    my($mgr, $inFastaFile, $inGFFFile, $outFile, $fileDir,$fastaRegex,$gffRegex) = @_;
    
    my ($species) = split(/\./,$inFastaFile);
    my $signal = "fixedMercatorOffsetsIn${species}GFF";
    return if $mgr->startStep("inserting $signal", $signal);
    my $args = "--f ${fileDir}/fasta/${inFastaFile} --g ${fileDir}/gff/${inGFFFile} --o ${fileDir}/gff/${outFile} ";
    if($fastaRegex){
	$args .= "--fr '${fastaRegex}' ";
    }
    
    if($gffRegex){
	$args .= "--gr '${gffRegex}'";
    }
    
    $mgr->runCmd("fixMercatorOffsetsInGFF.pl $args");
    $mgr->endStep($signal);


}

sub dumpMercatorGff {
    my($mgr, $outputDir, $organism, $fileNamePrefix) = @_;
    
    my $signal = "mercatorGffDump";

    $signal .= "_$organism" if $organism;

    $signal =~ s/ /_/g;

    return if $mgr->startStep("$signal", $signal);
    $mgr->runCmd("mkdir -p $mgr->{dataDir}/$outputDir");

    my $cmd = "mercatorGffDump.pl --outputDir $mgr->{dataDir}/$outputDir";

    $cmd .= " --organism \"$organism\"" if $organism;

    $cmd .= " --file_name_prefix \"$fileNamePrefix\"" if $fileNamePrefix;

    $mgr->runCmd($cmd);
    $mgr->endStep($signal);
}

sub insertMercatorSyntenySpans {
  my ($mgr, $file, $seqTableA, $seqTableB, $specA, $specB, $syntenySpec, $agpFile, $organism) = @_;

  my ($signal) = $syntenySpec =~ /([\da-zA-Z-_]+)/;
  $signal .= "SyntenySpans";

  return if $mgr->startStep("inserting $signal", $signal);

  my $out = $file."-synteny";

  my $args = "--inputFile $out --seqTableA '$seqTableA' --seqTableB '$seqTableB' --extDbRlsSpecA '$specA' --extDbRlsSpecB '$specB' --syntenyDbRlsSpec '$syntenySpec' --organism '$organism'";

  my $formatCmd = "formatPxSyntenyFile --inputFile $file --outputFile $out";


  if($agpFile){

      $formatCmd .= " --agpFile $agpFile";
  }
  $mgr->runCmd($formatCmd);
  $mgr->runPlugin($signal,
		  "ApiCommonData::Load::Plugin::InsertSyntenySpans", $args,
		  "Inserting mercator-MAVID Synteny Spans");

  $mgr->endStep($signal);
}


sub runMercatorMavid {
  my ($mgr, $mercatorDir, $signal) = @_;

  return if $mgr->startStep("running mercator-MAVID [$signal]", $signal);

  my $logFile = "$mgr->{myPipelineDir}/logs/$signal";

  my $propertySet = $mgr->{propertySet};

  my $cndsrcBin = $propertySet->getProp('cndsrc_bin_dir');
  my $mavid = $propertySet->getProp('mavid_exe');
  my $draftString = $propertySet->getProp('mercator_draft_genomes');
  my $nonDraftString = $propertySet->getProp('mercator_nondraft_genomes');
  my $referenceGenome = $propertySet->getProp('mercator_reference_genome');
  my $tree = $propertySet->getProp('mercator_tree');

  my $drafts = '';
  my $nonDrafts = '';
  if(uc($draftString) ne "NONE"){ 
      $drafts =  join(" ", map { "-d $_" } split(',', $draftString));
  }
  
  if(uc($nonDraftString) ne "NONE"){
      $nonDrafts = join(" ",map { "-n $_" } split(',', $nonDraftString));
  }

  my $command = "runMercator  -t '$tree' -p $mercatorDir -c $cndsrcBin -r $referenceGenome -m $mavid $drafts $nonDrafts 2>$logFile";
  
 
  $mgr->runCmd($command);

  $mgr->endStep($signal);
}

sub runPairwiseMercatorMavid {
  my ($mgr, $mercatorDir, $signal) = @_;

  return if $mgr->startStep("running pairwise mercator-MAVID [$signal]", $signal);

  my $logFile = "$mgr->{myPipelineDir}/logs/$signal";

  my $propertySet = $mgr->{propertySet};

  my $cndsrcBin = $propertySet->getProp('cndsrc_bin_dir');
  my $mavid = $propertySet->getProp('mavid_exe');
  my $draftString = $propertySet->getProp('mercator_draft_genomes');
  my $nonDraftString = $propertySet->getProp('mercator_nondraft_genomes');
  my $referenceGenome = $propertySet->getProp('mercator_reference_genome');

  my @drafts = ();
  my @nonDrafts = ();
  my @allGenomes = ();
  my $draftIdx = -1;
  my  $nonDraftIdx = -1;

  if(uc($draftString) ne 'NONE'){
      @drafts =  map { "$_" } split(',', $draftString);
      $draftIdx = $#drafts;
  }
  
  if(uc($nonDraftString) ne 'NONE'){
      @nonDrafts = map { "$_" } split(',', $nonDraftString);
      $nonDraftIdx = $#nonDrafts;
  }

  push(@allGenomes,@drafts,@nonDrafts);


  for(my $i =0; $i <= ($#allGenomes-1); $i++){
      for(my $j =$i+1 ; $j <= $#allGenomes; $j++){
	  my $dirName = "$mercatorDir/$allGenomes[$i]-$allGenomes[$j]";

	  my $command = "runMercator  -t '($allGenomes[$i]:0.1,$allGenomes[$j]:0.1);' -p $dirName -c $cndsrcBin -r $referenceGenome -m $mavid ";
	  if($i <= $draftIdx){
	      $command .= "-d  $allGenomes[$i] ";
	  }else{
	      $command .= "-n $allGenomes[$i] ";
	  }
	  if($j <= $draftIdx){
	      $command .= "-d  $allGenomes[$j] ";
	  }else{
	      $command .= "-n $allGenomes[$j] ";
	  }


          $command .= "2>>$logFile";
	  $mgr->runCmd($command);
      }
  }



  $mgr->endStep($signal);
}

sub createPairwiseMercatorDirs {
  my ($mgr, $mercatorDir, $fastaDir, $gffDir, $signal) = @_;

  return if $mgr->startStep("creating pairwise mercator dirs [$signal]", $signal);

  my $propertySet = $mgr->{propertySet};


  my $draftString = $propertySet->getProp('mercator_draft_genomes');
  my $nonDraftString = $propertySet->getProp('mercator_nondraft_genomes');
  my $referenceGenome = $propertySet->getProp('mercator_reference_genome');
  


  my @drafts = ();
  my @nonDrafts = ();


  my @allGenomes = ();


  my $draftIdx = -1;
  my  $nonDraftIdx = -1;

  if(uc($draftString) ne 'NONE'){
      @drafts =  map { "$_" } split(',', $draftString);

      $draftIdx = $#drafts;
  }
  
  if(uc($nonDraftString) ne 'NONE'){
      @nonDrafts = map { "$_" } split(',', $nonDraftString);
 
      $nonDraftIdx = $#nonDrafts;
  }

  push(@allGenomes,@drafts,@nonDrafts);
 


  for(my $i =0; $i <= ($#allGenomes-1); $i++){
      for(my $j =$i+1 ; $j <= $#allGenomes; $j++){


	      $mgr->runCmd("mkdir -p $mercatorDir/$allGenomes[$i]-$allGenomes[$j]/fasta");
	      $mgr->runCmd("mkdir -p $mercatorDir/$allGenomes[$i]-$allGenomes[$j]/gff");
	      
	      &copy($mgr,"$fastaDir/$allGenomes[$i].fasta","$mercatorDir/$allGenomes[$i]-$allGenomes[$j]/fasta");
	      &copy($mgr,"$fastaDir/$allGenomes[$j].fasta","$mercatorDir/$allGenomes[$i]-$allGenomes[$j]/fasta");
	      &copy($mgr,"$gffDir/$allGenomes[$i].gff","$mercatorDir/$allGenomes[$i]-$allGenomes[$j]/gff");
	      &copy($mgr,"$gffDir/$allGenomes[$j].gff","$mercatorDir/$allGenomes[$i]-$allGenomes[$j]/gff");
	      
      }
  }



  $mgr->endStep($signal);
}

sub insertPairwiseMercatorSyntenySpans {
  my ($mgr, $mercatorDir, $syntenyVersion, $organism, $signal) = @_;

  return if $mgr->startStep("running pairwise insert mercator synteny spans [$signal]", $signal);

  my $propertySet = $mgr->{propertySet};


  my $draftString = $propertySet->getProp('mercator_draft_genomes');
  my $nonDraftString = $propertySet->getProp('mercator_nondraft_genomes');
  my $referenceGenome = $propertySet->getProp('mercator_reference_genome');
  
  my $draftExternalDatabases = $propertySet->getProp('mercator_draft_externaldatabase');

  my $nonDraftExternalDatabases = $propertySet->getProp('mercator_nondraft_externaldatabase');

  my $draftSeqTables = $propertySet->getProp('mercator_draft_seqtables');

  my $nonDraftSeqTables = $propertySet->getProp('mercator_nondraft_seqtables');

  my @drafts = ();
  my @nonDrafts = ();
  my @draftExternalDbs = ();
  my @nonDraftExternalDbs = ();
  my @draftSeqTables = ();
  my @nonDraftSeqTables = ();

  my ($seqTableA, $seqTableB, $specA, $specB, $syntenySpec, $agpFile);
  my @allGenomes = ();
  my @allExternalDbs = ();
  my @allSeqTables = ();

  my $draftIdx = -1;
  my  $nonDraftIdx = -1;

  if(uc($draftString) ne 'NONE'){
      @drafts =  map { "$_" } split(',', $draftString);
      @draftExternalDbs =  map { "$_" } split(',', $draftExternalDatabases);
      @draftSeqTables =  map { "$_" } split(',', $draftSeqTables);

      $draftIdx = $#drafts;
  }
  
  if(uc($nonDraftString) ne 'NONE'){
      @nonDrafts = map { "$_" } split(',', $nonDraftString);
      @nonDraftExternalDbs =  map { "$_" } split(',', $nonDraftExternalDatabases);
      @nonDraftSeqTables =  map { "$_" } split(',', $nonDraftSeqTables);

      $nonDraftIdx = $#nonDrafts;
  }

  push(@allGenomes,@drafts,@nonDrafts);
  push(@allExternalDbs,@draftExternalDbs,@nonDraftExternalDbs);
  push(@allSeqTables,@draftSeqTables,@nonDraftSeqTables);


  for(my $i =0; $i <= ($#allGenomes-1); $i++){
      for(my $j =$i+1 ; $j <= $#allGenomes; $j++){


	  if($j <= $draftIdx){
	      $agpFile = "$mercatorDir/$allGenomes[$i]-$allGenomes[$j]/mercator-output/$allGenomes[$j].agp";
	  }else{
	      $agpFile = "";
	  }

	  my $file = "$mercatorDir/$allGenomes[$i]-$allGenomes[$j]/$allGenomes[$i]-$allGenomes[$j].align";
	  $seqTableA = $allSeqTables[$j];
	  $seqTableB = $allSeqTables[$i];
	  
	  $specA = $allExternalDbs[$j];
	  $specB = $allExternalDbs[$i];


	  &createExtDbAndDbRls($mgr,"$allGenomes[$i]-$allGenomes[$j] synteny from Mercator", $syntenyVersion, '');
	  $syntenySpec = "$allGenomes[$i]-$allGenomes[$j] synteny from Mercator|$syntenyVersion";

	  &insertMercatorSyntenySpans($mgr,$file,$seqTableA,$seqTableB,$specA,$specB,$syntenySpec,$agpFile,$organism);
      }
  }



  $mgr->endStep($signal);
}


sub grepMercatorGff {
  my ($mgr, $inFile, $outFile, $fileDir) = @_;

  my $signal = "grepMercatorGff$inFile";

  return if $mgr->startStep("grepMercatorGff ${fileDir}/$inFile", $signal);

  # The Exons must come first... then append the CDS to the file
  $mgr->runCmd("grep -P '\texon\t' ${fileDir}/$inFile |sed 's/apidb|//'  > ${fileDir}/$outFile");
  $mgr->runCmd("grep -P '\tCDS\t' ${fileDir}/$inFile |sed 's/apidb|//'  >> ${fileDir}/$outFile");

  $mgr->endStep($signal);
  
}

sub makeCodonUsage {
  my ($mgr, $species, $name, $strain) = @_;


  my $signal = $strain ? "${strain}MakeCodonUsage" : "${species}MakeCodonUsage";

  return if $mgr->startStep("Running CodonUsage for $species", $signal);

  my $propertySet = $mgr->{propertySet};

  my $release = $propertySet->getProp('projectRelease');

  my $projectDB = $propertySet->getProp('projectDB');

  my $siteFileDir = $propertySet->getProp('siteFileDir');

  my $dlDir = "$siteFileDir/downloadSite/$projectDB/release-$release/$species"; 
  
  $species = $strain ? $strain : $species;

  my $logFile = "$mgr->{myPipelineDir}/logs/${species}MakeCodonUsage.log";

  my $inFile = "$dlDir/${species}${name}_$projectDB-${release}.fasta";

  my $outFile = "$dlDir/${species}CodonUsage_$projectDB-${release}.txt";

  my $cmd = "makeCodonUsage --infile $inFile --outfile $outFile 2>>$logFile";

  $mgr->runCmd($cmd);

  $mgr->endStep($signal);
}


sub extractAnnotatedProteinsBySpecies {
  my ($mgr, $species,$dbName,$dbRlsVer, $ncbiTaxId,$taxonName) = @_;

  my $fname = "${species}AnnotatedProteins";

  my $propertySet = $mgr->{propertySet};

  my $signal = "${fname}Extract";

  return if $mgr->startStep("Extracting $fname protein sequences from GUS", $signal);

  my $taxonId = &getTaxonId($mgr,$ncbiTaxId,$taxonName) if ($ncbiTaxId || $taxonName);

  my $dbRlsId = &getDbRlsId($mgr,$dbName,$dbRlsVer);

## currently PlasmoDB specific. 11/16/2005msh
#   my $sql = "select t.source_id, 'length='||t.length,t.sequence
#               from dots.NASequence x, dots.nafeature f,
#               dots.translatedaafeature a,
#               dots.translatedaasequence t
#               where x.taxon_id = $taxonId
#               and x.external_database_release_id = $dbRlsId
#               and x.na_sequence_id = f.na_sequence_id 
#               and f.na_feature_id = a.na_feature_id
#               and a.aa_sequence_id = t.aa_sequence_id";
## CryptoDB does not yet store source_id and length in translatedaasequence.
## Until it catches up, perhaps this will work for Plasmo and Crypto
  my $sql = "SELECT tx.source_id,g.product,
                    'length='||length(t.sequence),t.sequence
               FROM dots.NASequence x,
                    dots.transcript tx,
                    dots.nafeature f,
                    dots.genefeature g,
                    dots.translatedaafeature a,
                    dots.translatedaasequence t
              WHERE x.taxon_id = $taxonId
                AND x.external_database_release_id = $dbRlsId
                AND tx.parent_id = g.na_feature_id
                AND x.na_sequence_id = f.na_sequence_id 
                AND f.na_feature_id = a.na_feature_id
                AND a.aa_sequence_id = t.aa_sequence_id
                AND a.na_feature_id = tx.na_feature_id";

  &extractProteinSeqs($mgr,$fname,$sql);
}

sub filterSequences {
  my ($mgr,$seqFile,$filterDir,$filterType,$opt) = @_;
  my $propertySet = $mgr->{propertySet};

  my $signal = "${filterType}$seqFile";
  return if $mgr->startStep("Filtering $seqFile with $filterType", $signal);

  my $blastDir = $propertySet->getProp('wuBlastPath');

  my $filter = "$blastDir/$filterDir/$filterType";

  my $logFile = "$mgr->{myPipelineDir}/logs/${seqFile}.$filterType.log";

  my $input = "$mgr->{dataDir}/seqfiles/$seqFile";

  my $output = "$mgr->{dataDir}/seqfiles/${seqFile}.$filterType";

  $mgr->runCmd("$filter $input $opt > $output 2>> $logFile");

  $mgr->endStep($signal);
}


sub documentLowComplexity {
  my ($mgr, $tool, $seqType, $mask) = @_;

  my $description = "$tool was used to mask low complexity regions.";

  my $documentation =
    { name => "Filter Low Complexity $seqType Sequences",
      input => "$seqType sequences",
      output => "$seqType sequences containing regions of low complexity are masked with the character '$mask'",
      descrip => $description,
      tools => []
    };
  $mgr->documentStep('lowComplexity', $documentation);
}


sub loadLowComplexitySequences {
  my ($mgr,$file,$extdbName,$extDbRlsVer,$type,$mask,$opt) = @_;

  my $propertySet = $mgr->{propertySet};

  my $input = "$mgr->{dataDir}/seqfiles/$file";

  my $args = "--seqFile $input --fileFormat 'fasta' --extDbName '$extdbName' --extDbVersion '$extDbRlsVer' --seqType $type --maskChar $mask $opt";

  my $signal = "load$file";

  $mgr->runPlugin($signal,
		  "ApiCommonData::Load::Plugin::InsertLowComplexityFeature", $args,
		  "Loading low complexity sequence file $file");

}


sub makeTranscriptSeqs {
  my ($mgr, $name, $taxId,$taxonHierarchy, $sql,$taxonName) = @_;
  my $propertySet = $mgr->{propertySet};

  my $file = $propertySet->getProp('vectorFile');

  my $phrapDir = $propertySet->getProp('phrapDir');

  my $taxonId =  &getTaxonId($mgr,$taxId,$taxonName);

  my $taxonIdList = &getTaxonIdList($mgr,$taxonId,$taxonHierarchy);

  my $args = "--taxon_id_list '$taxonIdList' --repeatFile $file --phrapDir $phrapDir";

  $args .= " --idSQL \"$sql\"" if($sql);

  $mgr->runPlugin("make${name}AssemSeqs",
          "DoTS::DotsBuild::Plugin::MakeAssemblySequences", $args,
          "Making assembly table sequences");
}


sub extractTranscriptSeqs {
  my ($mgr,$name,$taxId,$taxonHierarchy,$sql,$taxonName) = @_;

  my $taxonId = &getTaxonId($mgr,$taxId,$taxonName);

  my $taxonIdList = &getTaxonIdList($mgr,$taxonId,$taxonHierarchy);

  my $outputFile = "$mgr->{dataDir}/seqfiles/${name}.fsa";

  my $args = "--taxon_id_list '$taxonIdList' --outputfile $outputFile --extractonly";

  $args .= " --idSQL \"$sql\"" if($sql);

    $mgr->runPlugin("${name}_ExtractUnalignedAssemSeqs",
		    "DoTS::DotsBuild::Plugin::ExtractAndBlockAssemblySequences",
		    $args, "Extracting unaligned assembly sequences");
}

sub extractAssemblies {
  my ($mgr, $species, $name, $ncbiTaxId,$taxonName) = @_;
  my $propertySet = $mgr->{propertySet};
  my $signal = "${species}${name}Extract";

  return if $mgr->startStep("Extracting ${species} $name assemblies from GUS", $signal);

  my $taxonId = &getTaxonId($mgr, $ncbiTaxId,$taxonName);
  my $seqFile = "$mgr->{dataDir}/seqfiles/${species}$name.fsa";
  my $logFile = "$mgr->{myPipelineDir}/logs/${species}${name}Extract.log";

  my $sql = "select na_sequence_id,'[$species]',description,'('||number_of_contained_sequences||' sequences)','length='||length,sequence from dots.Assembly where taxon_id = $taxonId";
  my $cmd = "gusExtractSequences --outputFile $seqFile --verbose --idSQL \"$sql\" 2>>  $logFile";

  $mgr->runCmd($cmd);

  $mgr->endStep($signal);
}


sub startTranscriptAlignToContigs {
  my ($mgr, $species, $name) = @_;
  my $propertySet = $mgr->{propertySet};

  my $signal = "${species}${name}AlignToContigs";
  my $clusterServer = $propertySet->getProp('clusterServer');
  return if $mgr->startStep("Aligning $species $name to contigs on $clusterServer", $signal);

  $mgr->endStep($signal);

  my $clusterCmdMsg = "runContigAlign $mgr->{clusterDataDir} NUMBER_OF_NODES";
  my $clusterLogMsg = "monitor $mgr->{clusterDataDir}/logs/*.log and xxxxx.xxxx.stdout";

  $mgr->exitToCluster($clusterCmdMsg, $clusterLogMsg, 1);
}


sub documentBLATAlignment {
  my ($mgr, $version,$options) = @_;

  my $documentation =
    { name => "BLATAlignment",
      input => "Fasta file of cDNA sequences blocked using repeatMasker with RepBase and genome sequences in nib format",
      output => "Text file of alignments in .psl format",
      descrip => "BLAT is a rapid tool to find mRNA/DNA alignments that can be run using the GfClient program to query an indexed DNA database on a GfServer .",
      tools => [
		{ name => "BLATAlignment",
		  version => $version,
		  params => $options,
		  url => "http://www.cbs.dtu.dk/services/SignalP/",
		  pubmedIds => "11932250",
		  credits => "Kent W.J.,
                              BLAT - The BLAST-Like Alignment Tool,
                              Genome Research, 2002,  12(4), 656-664."
		},
	       ]
    };
  $mgr->documentStep("BLATAlignment", $documentation);

}

sub loadContigAlignments {
  my ($mgr, $ncbiTaxId, $queryName, $targetName,$qDbName,$qDbRlsVer,$tDbName,$tDbRlsVer,$targetTable,$regex,$action, $table,$querySeqFile,$percentTop,$queryNcbiTaxId,$taxonName,,$queryTaxonName) = @_;

  my $propertySet = $mgr->{propertySet};

  my $dataDir = $mgr->{'dataDir'};

  my $signal = "${action}${queryName}${targetName}BLATAlignments";

  return if $mgr->startStep("Begin $signal", $signal);

  my $genomeDbRlsId = &getDbRlsId($mgr,$tDbName,$tDbRlsVer);

  my $queryDbRlsId = &getDbRlsId($mgr,$qDbName,$qDbRlsVer) if ($qDbName && $qDbRlsVer);

  my $taxonId = &getTaxonId($mgr, $ncbiTaxId,$taxonName);

  my $queryTaxonId = ($queryNcbiTaxId || $queryTaxonName)? &getTaxonId($mgr, $queryNcbiTaxId,$queryTaxonName) : $taxonId;

  my $pslFile = "$dataDir/genome/${queryName}-${targetName}/master/mainresult/out.psl";

  my $qFile = "$dataDir/repeatmask/$queryName/master/mainresult/blocked.seq";

  $qFile =  "$dataDir/seqfiles/$querySeqFile" if $querySeqFile;

  my $tmpFile;

  my $qDir = "/tmp/" . $queryName;

  my $qTabId = ($queryName =~ /FinalTranscript/i) ? 
    &getTableId($mgr, "Assembly") :
      &getTableId($mgr, "AssemblySequence");

  $tmpFile = $qDir . "/blocked.seq";

  $qTabId = &getTableId($mgr, "$table") if $table;

# copy qFile to /tmp directory to work around a bug in the
# LoadBLATAlignments plugin's call to FastaIndex
  $mgr->runCmd("mkdir $qDir") if ! -d $qDir;
  $mgr->runCmd("cp $qFile $tmpFile")if ! -e $tmpFile;

  my $tTabId = &getTableId($mgr, $targetTable);

  my $args = "--blat_files '$pslFile' --query_file $tmpFile --action '$action' --queryRegex '$regex'"
    . " --query_table_id $qTabId --query_taxon_id $queryTaxonId"
  . " --target_table_id  $tTabId --target_db_rel_id $genomeDbRlsId --target_taxon_id $taxonId"
    . " --max_query_gap 5 --min_pct_id 95 --max_end_mismatch 10"
      . " --end_gap_factor 10 --min_gap_pct 90 "
        . " --ok_internal_gap 15 --ok_end_gap 50 --min_query_pct 10";

  $args .= " --query_db_rel_id $queryDbRlsId" if $queryDbRlsId;

  $args .= " --percentTop $percentTop" if $percentTop;

  $action = ucfirst($action);

  $mgr->runPlugin("${action}${queryName}${targetName}BLATAlignments", 
            "GUS::Community::Plugin::LoadBLATAlignments",
            $args, "$action genomic alignments of ${queryName} vs $targetName");

  $mgr->runCmd("rm -rf $qDir") if -d $qDir;
}


sub clusterByContigAlign {
    my ($mgr, $species, $name, $extDbName, $extDbRlsVer,$ncbiTaxId,$taxonName) = @_;
    my $propertySet = $mgr->{propertySet};

    my $dataDir = $mgr->{'dataDir'};
    #my $taxonId = $mgr->{taxonId};

    my $signal = "Cluster${species}${name}ByContig";

    return if $mgr->startStep("Begin $signal", $signal);
    
    my $taxonId = &getTaxonId($mgr,$ncbiTaxId,$taxonName);
 
    $mgr->{contigDbRlsId} =  &getDbRlsId($mgr,$extDbName,$extDbRlsVer) unless $mgr->{contigDbRlsId};
    my $extDbRelId = $mgr->{contigDbRlsId};

    my $extDbNameGB = $propertySet->getProp('genbankDbName');
    my $extDbRlsVerGB = $propertySet->getProp('genbankDbRlsVer');
    $mgr->{genbankDbRlsId} =  &getDbRlsId($mgr,$extDbNameGB,$extDbRlsVerGB) unless $mgr->{genbankDbRlsId};
    my $gb_db_rel_id = $mgr->{genbankDbRlsId};

    my $outputFile = "$dataDir/cluster/$species$name/cluster.out";
    my $logFile = "$dataDir/logs/${name}Cluster.log";

    my $args = "--stage $name --taxon_id $taxonId --query_db_rel_id $gb_db_rel_id --target_table_name ExternalNASequence "
	. "--target_db_rel_id $extDbRelId --out $outputFile --sort 1";
    # $args .= " --test_chr 5";

    $mgr->runPlugin($signal, 
		    "DoTS::DotsBuild::Plugin::ClusterByGenome",
		    $args, "$name clustering by contig alignment");

}

sub documentCAP4 {
  my ($mgr) = @_;
  my $description = "CAP4 is used to generate predicted, alternatively-spliced transcripts. CAP4 aligns and assembles clustered sequence reads and produces consensus sequences";
  my $documentation =    { name => "CAP4",
                         input => "clusters of EST and mRNA sequences",
			   output => "assembled consensus sequence and quality values",
			   descrip => $description,
                           tools => [{ name => "CAP4",
				       version =>"",
				       params => "",
				       url => "",
				       pubmedIds => "10508846",
				       credits => " Huang, X. and Madan, A.
                                                    (1999) CAP3: A DNA sequence assembly program. 
                                                    Genome Res., 9, 868-877."}]};

 $mgr->documentStep("CAP4", $documentation);
}

sub documentRepeatMasker {
  my ($mgr,$version) = @_;

  my $description = "RepeatMasker uses cross-match and a RepBase repeat library to screen DNA sequences for interspersed repeats and low complexity DNA sequences and outputs a modified version of the query sequence in which all the repeats have been masked.";
  my $documentation =    { name => "RepeatMasker",
                           input => "Fasta file of nucleic acid sequences and RepBase ",
			   output => "Fasta file of masked nucleic acid sequences",
			   descrip => $description,
                           tools => [{ name => "RepeatMasker",
				       version => $version,
				       params => "",
				       url => "http://www.repeatmasker.org",
				       pubmedIds => "",
				       credits => "Smit, AFA, Hubley, R & Green, P. 
                                                   RepeatMasker Open-3.0.
                                                   1996-2004"}]};

 $mgr->documentStep("RepeatMasker", $documentation);
}

### subroutine used when the aligned transcripts are from multiple sources with different external_database_release_ids
sub clusterMultiEstSourcesByAlign { 
    my ($mgr, $name, $species, $tExtDbName, $tExtDbRlsVer,$taxId, $targetTable,$distance,$taxonName) = @_;
    my $propertySet = $mgr->{propertySet};

    my $dataDir = $mgr->{'dataDir'};

    my $signal = "Cluster${species}${name}ByContigWithAltSql";

    return if $mgr->startStep("Begin $signal", $signal);
 
    my $tDbRlsId=  &getDbRlsId($mgr,$tExtDbName,$tExtDbRlsVer);

    my $taxonId = &getTaxonId($mgr,$taxId,$taxonName);

    my $outputFile = "$dataDir/cluster/$species$name/cluster.out";

    $mgr->runCmd("mkdir -p $dataDir/cluster/$species$name");

    my $logFile = "$dataDir/logs/${species}${name}Cluster.log";

    my $args = "--taxon_id $taxonId --target_table_name  $targetTable --mixedESTs "
	. "--target_db_rel_id $tDbRlsId --out $outputFile --sort 1 --distanceBetweenStarts $distance";

    $mgr->runPlugin($signal, 
		    "DoTS::DotsBuild::Plugin::ClusterByGenome",
		    $args, "$species $name clustering by contig alignment");

}

sub snpGffToFasta {
  my ($mgr,$gffFile,$refStrain,$gffFormat) = @_;

  my $signal = "convert${gffFile}ToFasta";

  my $logfile = "$mgr->{myPipelineDir}/logs/${signal}.log";

  return if $mgr->startStep("Converting $gffFile to a fasta formatted file", $signal);

  my $subdir = $gffFile;

  $subdir =~ s/\.gff//;

  $mgr->runCmd("mkdir -p $mgr->{dataDir}/snp/$subdir");

  my $outFile = "${subdir}.fasta";

  my $cmd = "snpFastaMUMmerGff --gff_file $mgr->{dataDir}/snp/$gffFile --reference_strain $refStrain --output_file $mgr->{dataDir}/snp/$subdir/$outFile --make_fasta_file_only > --gff_format $gffFormat 2>> $logfile";

  $mgr->runCmd($cmd);

  $mgr->endStep($signal);
}

sub blastToGff {
  my ($mgr,$gffFile,$blastFile) = @_;

  my $signal = "convert${blastFile}ToGff";

  my $logfile = "$mgr->{myPipelineDir}/logs/${signal}.log";

  return if $mgr->startStep("Converting $blastFile to a Gff formatted file", $signal);

  my $cmd = "perl blastToGff.pl --blastInput $blastFile --outputFile $gffFile 2>> $logfile";

  $mgr->runCmd($cmd);

  $mgr->endStep($signal);
}

sub runMummer {
  my ($mgr,$queryFile,$snpDir) = @_;

  my $outFile = $queryFile;

  $outFile =~ s/\.\S+\b//;

  $outFile = "${outFile}_${snpDir}Mummer";

  my $signal = "run$outFile";

  return if $mgr->startStep("Running mummer on $queryFile with files in $snpDir", $signal);

  my $propertySet = $mgr->{propertySet};

  my $logfile = "$mgr->{myPipelineDir}/logs/${signal}.log";

  my $mummerPath = $propertySet->getProp('mummerDir');

  opendir (SNPDIR,"$mgr->{dataDir}/snp/$snpDir") || die "Unable to open $mgr->{dataDir}/snp/$snpDir\n";

  while(my $snpFile = readdir(SNPDIR)) {
    my $cmd = "callMUMmerForSnps --mummerDir $mummerPath --query_file $mgr->{dataDir}/seqfiles/$queryFile --output_file $mgr->{dataDir}/snp/$outFile --snp_file $mgr->{dataDir}/snp/$snpDir/$snpFile 2>> $logfile"; 

    $mgr->runCmd($cmd);
  }

  closedir(SNPDIR);

  $mgr->endStep($signal);
}

sub snpMummerToGFF {
  my ($mgr,$mummerFile,$gffFile,$refStrain,$gffFormat) = @_;

  my $signal = "convert${mummerFile}ToGff";

  my $logfile = "${mummerFile}Errors.log";

  my $output = "${mummerFile}.gff";

  return if $mgr->startStep("Converting $mummerFile to a gff formatted file", $signal);

  my $cmd = "snpFastaMUMmerGff --gff_file $mgr->{dataDir}/snp/$gffFile --mummer_file $mgr->{dataDir}/snp/$mummerFile --output_file $mgr->{dataDir}/snp/$output --reference_strain $refStrain --error_log $mgr->{myPipelineDir}/logs/$logfile --gff_format $gffFormat --skip_multiple_matches";

  $mgr->runCmd($cmd);

  $mgr->endStep($signal);
}

sub loadMummerSnpResults {
  my ($mgr,$snpDbName,$snpDbRlsVer,$targetDbName,$targetDbRlsVer,$transcriptDbName,$transcriptDbRlsVer,$targetTable,$org,$refOrg,$gffFile,$restart) = @_;

  my $args = "--reference '$refOrg' --organism '$org' --snpExternalDatabaseName '$snpDbName' --snpExternalDatabaseVersion '$snpDbRlsVer' --naExternalDatabaseName '$targetDbName' --naExternalDatabaseVersion '$targetDbRlsVer' --transcriptExternalDatabaseName '$transcriptDbName' --transcriptExternalDatabaseVersion '$transcriptDbRlsVer' --seqTable '$targetTable' --ontologyTerm 'SNP' --snpFile $mgr->{dataDir}/snp/$gffFile";

  $args .= " --restart $restart" if $restart;

  $mgr->runPlugin("load$gffFile",
		  "ApiCommonData::Load::Plugin::InsertSnps",
		  $args, "Loading mummer results from $gffFile");
}

sub createSTSFileFromGenBank {
  my ($mgr, $genbankFile, $filePrefix) = @_;
  
  my $propertySet = $mgr->{propertySet};

  my $fileDir = "$mgr->{dataDir}/microsatellite";
  
  my $signal = "create${filePrefix}_microsatelliteSTSFile";
  
  my $logFile = "${filePrefix}_microsatelliteSTSErr.log";

  
  
  my $cmd = "createSTSFileFromGB --genbank_file $fileDir/$genbankFile --output_file $fileDir/${filePrefix}_microsatellite.sts 2> $mgr->{myPipelineDir}/logs/$logFile";
  
  $mgr->runCmd($cmd);

  $mgr->endStep($signal);


}

sub ePCRMsStsForLocations {
  my ($mgr, $stsFile, $outputFile, $seqFile, $margin, $mismatch, $gap, $msInfo) = @_;

  my $sts = $stsFile;

  $sts =~ s/\.\S+\b//;

  my $seq = $seqFile;

  $seq =~ s/\.\S+\b//;

  my $propertySet = $mgr->{propertySet};

  my $signal = "ePcr${sts}_${seq}";

  my $inputDir = "$mgr->{dataDir}/microsatellite";
  
  my $outputDir = "$mgr->{dataDir}/seqfiles";
   
  my $logFile = "$mgr->{myPipelineDir}/logs/${signal}.log";
  
  my $ePcrDir = $propertySet->getProp('ePcrDir');


  my $args = "--sts_file $inputDir/$stsFile --output_file $outputDir/$outputFile --seq_file $outputDir/$seqFile --epcr_dir $ePcrDir --log_file $logFile ";
  $args .= "--margin $margin " if($margin =~ /^\d+$/);
  $args .= "--gap $gap " if ($gap =~ /^\d+$/);
  $args .= "--mismatch $mismatch " if ($mismatch =~ /^\d+$/);
  $args .= "--microsatellite_info $msInfo" if ($msInfo);

  my $cmd = "ePCRMicrosatelliteForLocations $args";
  
  $mgr->runCmd($cmd);

  $mgr->endStep($signal);
}


sub loadMicrosatelliteFile {
    my ($mgr, $msFile, $extDbName, $extDbRlsVer, $mapFile, $soCvsVersion, $subclass, $defaultOrg) = @_;

    my $signal = "load_$msFile";

    my $args = <<"EOF";
--extDbName '$extDbName'  \\
--extDbRlsVer '$extDbRlsVer' \\
--mapFile $mapFile \\
--inputFileOrDir $mgr->{dataDir}/seqfiles/$msFile \\
--fileFormat gff2   \\
--seqSoTerm microsatellite  \\
--soCvsVersion $soCvsVersion \\
--naSequenceSubclass $subclass \\
EOF

    if ($defaultOrg){
      $args .= "--defaultOrganism '$defaultOrg'";
    }

    $mgr->runPlugin(
        $signal,
        "GUS::Supported::Plugin::InsertSequenceFeatures",
        $args, 
        "Loading $msFile output");

}


sub createSageTagNormFiles {
  my ($mgr,$name,$paramValue) = @_;
  my $propertySet = $mgr->{propertySet};

  my $fileDir = "$mgr->{dataDir}/sage";

  my $signal = "Create_${name}_NormFiles";

  $signal =~ s/\s/_/g;

  my $args = "--paramValue $paramValue --studyName '$name' --fileDir $fileDir";

  $mgr->runPlugin($signal,
                  "ApiCommonData::Load::Plugin::CreateSageTagNormalizationFiles",
                  $args,"Creating files for $name");
}

sub createSignalPDir {
  my ($mgr) = @_;

  my $propertySet = $mgr->{propertySet};

  my $signal = "createSignalPDir";

  return if $mgr->startStep("Creating SignalP dir", $signal);

  my $signalpDir = "$mgr->{'dataDir'}/signalp";

  $mgr->runCmd("mkdir $signalpDir");

  $mgr->endStep($signal);
}

sub documentSignalP {
  my ($mgr, $version,$options) = @_;

  my $documentation =
    { name => "SignalP",
      input => "Protein sequences",
      output => "Signal peptide predictions",
      descrip => "SignalP is used to identify signal peptides and their likely cleavage sites.",
      tools => [
		{ name => "SignalP",
		  version => $version,
		  params => $options,
		  url => "http://www.cbs.dtu.dk/services/SignalP/",
		  pubmedIds => "15223320",
		  credits => "Bendtsen JD, Nielsen H, von Heijne G, Brunak S."
		},
	       ]
    };
  $mgr->documentStep("signalP", $documentation);

}

sub runSignalP {
  my ($mgr, $species, $options) = @_;

  my $signal = "${species}RunSignalP";

  return if $mgr->startStep("Running SignalP for $species", $signal);
  
  my $propertySet = $mgr->{propertySet};

  my $logFile = "$mgr->{myPipelineDir}/logs/${species}SignalP.log";

  my $inFilePath = "$mgr->{dataDir}/seqfiles/${species}AnnotatedProteins.fsa";

  my $outFilePath = "$mgr->{dataDir}/signalp/${species}SignalP.out";
  
  my $binPath = $propertySet->getProp('signalP.path');
  
  my $cmd = "runSignalP --binPath $binPath  --options '$options' --seqFile $inFilePath --outFile $outFilePath 2>>$logFile"; 

  $mgr->runCmd($cmd);

  $mgr->endStep($signal);
}

sub loadSignalPData{
  my ($mgr, $species,$extDbName,$extDbRlsVer) = @_;
  my $propertySet = $mgr->{propertySet};

  my $resultFile = "$mgr->{dataDir}/signalp/${species}SignalP.out";

  my $version = $propertySet->getProp('signalP.version');

  my $projectName = $propertySet->getProp('projectName');

  my $desc = "SignalP version $version";

  my $args = "--data_file $resultFile --algName 'SignalP' --algVer '$version' --algDesc '$desc' --extDbName '$extDbName' --extDbRlsVer '$extDbRlsVer' --project_name $projectName --useSourceId";

  $mgr->runPlugin("${species}LoadSignalP", "ApiCommonData::Load::Plugin::LoadSignalP", $args, "Loading $species SignalP results");
}

sub createTmhmmDir {
  my ($mgr) = @_;

  my $propertySet = $mgr->{propertySet};
  my $signal = "createTmhmmDir";
  return if $mgr->startStep("Creating Tmhmm dir", $signal);

  my $tmhmmDir = "$mgr->{'dataDir'}/tmhmm";

  $mgr->runCmd("mkdir $tmhmmDir");

  $mgr->endStep($signal);
}

sub createDir {
  my ($mgr,$dir) = @_;

  my $signal = "create${dir}Dir";

  return if $mgr->startStep("Creating Tmhmm dir", $signal);

  $mgr->runCmd("mkdir -p $mgr->{'dataDir'}/$dir");

  $mgr->endStep($signal);
}



sub makeBlastParamsFile {
  my ($mgr,$dir,$blastParams) = @_;

  my $signal = "write${dir}ParamsFile";

  return if $mgr->startStep("Writing $dir blast params file", $signal);

  my $file = "$mgr->{'dataDir'}/similarity/$dir/params";

  open (FILE, "> $file");

  print FILE "$blastParams";

  close FILE;

  die "Didn't make valid params file" unless (-e $file);

  $mgr->endStep($signal);
}

 sub runLocalWuBlast {
   my ($mgr, $blastType, $subjectFile, $queryFile, $simDir, $pValCutoff, $lengthCutoff, $percentCutoff, $outputType,$adjustMatchLength) = @_;

   my $propertySet = $mgr->{propertySet};

   my $signal = "run${simDir}WuBlast";

   return if $mgr->startStep("Running $simDir WuBlast locally", $signal);

   my $wuBlastDir = $propertySet->getProp('wuBlastPath');

   my $adjust = $adjustMatchLength ? "--adjustMatchLength" : "";

   chdir "$mgr->{'dataDir'}/similarity/$simDir" || die "Can't chdir to $mgr->{'dataDir'}/similarity/$simDir";

   my $cmd = "blastSimilarity --blastProgram '$blastType' --pValCutoff $pValCutoff --lengthCutoff $lengthCutoff --percentCutoff $percentCutoff --database $mgr->{'dataDir'}/seqfiles/$subjectFile --seqFile $mgr->{'dataDir'}/seqfiles/$queryFile --blastVendor 'wuBlast' --blastParamsFile $mgr->{'dataDir'}/similarity/$simDir/params --blastFileDir $mgr->{'dataDir'}/similarity/$simDir --outputType '$outputType' $adjust --blastBinDir $wuBlastDir --regex '(\\S+)'";

   print STDERR "$cmd\n";

   $mgr->runCmd($cmd);

   $mgr->runCmd("mv blastSimilarity.log $mgr->{myPipelineDir}/logs/");

   $mgr->runCmd("mkdir -p $mgr->{'dataDir'}/similarity/$simDir/master/mainresult");

   $mgr->runCmd("mv $mgr->{'dataDir'}/similarity/$simDir/blastSimilarity.out $mgr->{'dataDir'}/similarity/$simDir/master/mainresult/blastSimilarity.out");

   chdir $mgr->{myPipelineDir} || die "Can't chdir to $mgr->{myPipelineDir}";

   $mgr->endStep($signal);
}

sub documentTMHMM {
  my ($mgr,$version) = @_; 

  my $documentation =
    { name => "Predict transmembrane domains",
      input => "Protein sequences",
      output => "Predicted transmembrane domain topology",
      descrip => "TMHMM is used to predict transmembrane domain presence and topology",
      tools => [
		{ name => "tmhmm",
		  version => $version,
		  params => "",
		  url => "",
		  pubmedIds => "11152613",
		  credits => "Anders Krogh, Bjorn Larsson, Gunnar von Heijne, and Erik L.L. Sonnhammer"
		},
	       ]
    };
  $mgr->documentStep('tmhmm', $documentation);
}

sub runTMHmm{
  my ($mgr, $species) = @_;

  my $propertySet = $mgr->{propertySet};

  my $signal = "${species}RunTMHMM";

  return if $mgr->startStep("Running TMHMM for $species", $signal);

  my $binPath = $propertySet->getProp('tmhmm.path');

  my $seqFile = "$mgr->{dataDir}/seqfiles/${species}AnnotatedProteins.fsa";

  my $outFile = "$mgr->{'dataDir'}/tmhmm/${species}Tmhmm.out";

  my $cmd = "runTMHMM -binPath $binPath -short  -seqFile $seqFile -outFile $outFile 2>> $mgr->{myPipelineDir}/logs/${species}Tmhmm.log";

  $mgr->runCmd($cmd);

  $mgr->endStep($signal);
}


sub loadTMHmmData{
  my ($mgr, $species,$extDbName,$extDbRlsVer) = @_;
  my $propertySet = $mgr->{propertySet};

  my $resultFile = "$mgr->{dataDir}/tmhmm/${species}Tmhmm.out";

  my $version = $propertySet->getProp('tmhmm.version');

  my $desc = "TMHTMM version $version";

  my $args = "--data_file $resultFile --algName TMHMM --algDesc '$desc' --useSourceId --extDbName '$extDbName' --extDbRlsVer '$extDbRlsVer'";

  $mgr->runPlugin("${species}LoadTMDomains", "ApiCommonData::Load::Plugin::LoadTMDomains", $args, "Loading $species TMHMM output");
}

sub insertAASeqMWMinMax {
  my ($mgr,$table,$extDbRlsName,$extDbRlsVer) = @_;

  my $signal = "${extDbRlsName}MinMax";

  $signal =~ s/\s//g;

  $signal =~ s/\.//g;

  my $args = "--extDbRlsName '$extDbRlsName' --extDbRlsVer '$extDbRlsVer'  --seqTable '$table'";

  $mgr->runPlugin($signal,
		  "ApiCommonData::Load::Plugin::CalculateAASeqMolWtMinMax",
		  $args, "Calculating and loading $extDbRlsName AA MW min and max");
}

sub documentAAip {
  my ($mgr) = @_;

    my $documentation =
      { name => "Protein pI (isoelectric point) calculation",
	input => "Protein sequences",
	output => "pI (isoelectric point) values",
	descrip => "The pKa values used to calculate pI are those used in the EMBOSS package; the pI is calculated to only two decimal points.",
	tools => [],
      };
  $mgr->documentStep('AAip', $documentation);
}

sub insertAAiP {
  my ($mgr,$table,$extDbRlsName,$extDbRlsVer) = @_;

   my $signal = "${extDbRlsName}IP";

  $signal =~ s/\s//g;

  $signal =~ s/\.//g;

  my $args = "--extDbRlsName '$extDbRlsName' --extDbRlsVer '$extDbRlsVer'  --seqTable '$table'";

  $mgr->runPlugin($signal,
		  "ApiCommonData::Load::Plugin::CalculateAASequenceIsoelectricPoint",
		  $args, "Calculating and loading $extDbRlsName AA iP");
}

sub insertNormSageTagFreqs {
  my ($mgr,$name) = @_;
  my $propertySet = $mgr->{propertySet};

  $name =~ s/\s/_/g;

  my $signal = "Insert_${name}_NormFreqs";

  return if $mgr->startStep("Loading normalized $name", $signal);

  my $fileDir = "$mgr->{dataDir}/sage/$name";

  opendir (DIR,$fileDir);

  my @files = grep { /\w*\.dat/ && -f "${fileDir}/$_" } readdir(DIR);

  foreach my $file (@files) {

    my $cfg = $file;

    $cfg =~ s/\.dat/\.cfg/;

    my $args = "--cfg_file '$fileDir/$cfg' --data_file '$fileDir/$file' --subclass_view RAD::DataTransformationResult";

    $mgr->runPlugin("${file}Inserted",
 		    "GUS::Supported::Plugin::InsertRadAnalysis",
 		    $args,"Inserting $file for $name");
  }

  $mgr->endStep($signal);
}

sub copyFilesToComputeCluster {
  my ($mgr,$file,$dir) = @_;
  my $propertySet = $mgr->{propertySet};

  my $clusterServer = $propertySet->getProp('clusterServer');
  
  my $signalDir = $dir;
  $signalDir =~ s/\//_/g;
  my $signal = "${signalDir}_${file}ToCluster";
  return if $mgr->startStep("Copying $file to $mgr->{clusterDataDir}/$file on $clusterServer", $signal);

  my $fileDir = "$mgr->{dataDir}/$dir";

  $mgr->{cluster}->copyTo($fileDir, $file, "$mgr->{clusterDataDir}/$dir");

  $mgr->endStep($signal);
}

sub copyFilesToComputeClusterForOrtho {
  my ($mgr,$fileDir,$file,$clusterDir) = @_;
  my $propertySet = $mgr->{propertySet};

  my $clusterServer = $propertySet->getProp('clusterServer');

  my $sig = $file;

  $sig =~ s/\//_/g; 

  my $signal = "${sig}${file}CopiedToCluster";

  return if $mgr->startStep("Copying $file to $clusterDir on $clusterServer", $signal);

  $mgr->{cluster}->copyTo($fileDir, $file, "$clusterDir");

  $mgr->endStep($signal);
}

sub clusterByBlastSim {
  my ($mgr, $species, $name, @matrices) = @_;
  my $propertySet = $mgr->{propertySet};

  my $signal = "${species}${name}Cluster";

  return if $mgr->startStep("Clustering ${species}$name", $signal);

  my $length = $propertySet->getProp("${name}Cluster.length");
  my $percent = $propertySet->getProp("${name}Cluster.percent");
  my $logbase = $propertySet->getProp("${name}Cluster.logbase");
  my $consistentEnds = $propertySet->getProp("${name}Cluster.consistentEnds");
  my $cliqueSzArray = $propertySet->getProp("${name}Cluster.cliqueSzArray");
  my $logbaseArray = $propertySet->getProp("${name}Cluster.logbaseArray");

  my @matrixFileArray;
  foreach my $matrix (@matrices) {
    push(@matrixFileArray,
	 "$mgr->{dataDir}/matrix/$matrix/master/mainresult/blastMatrix.out.gz");
  }
  my $matrixFiles = join(",", @matrixFileArray);

  my $ceflag = ($consistentEnds eq "yes")? "--consistentEnds" : "";

  my $outputFile = "$mgr->{dataDir}/cluster/$species$name/cluster.out";
  my $logFile = "$mgr->{myPipelineDir}/logs/$signal.log";

  my $cmd = "buildBlastClusters.pl --lengthCutoff $length --percentCutoff $percent --verbose --files '$matrixFiles' --logBase $logbase --iterateCliqueSizeArray $cliqueSzArray $ceflag --iterateLogBaseArray $logbaseArray --sort > $outputFile 2>> $logFile";

  $mgr->runCmd($cmd);

  $mgr->endStep($signal);
}


sub splitCluster {
  my ($mgr, $species, $name) = @_;
  my $propertySet = $mgr->{propertySet};

  my $signal = "${species}${name}SplitCluster";

  return if $mgr->startStep("SplitCluster $name", $signal);

  my $clusterFile = "$mgr->{dataDir}/cluster/$species$name/cluster.out";
  my $splitCmd = "splitClusterFile $clusterFile";

  $mgr->runCmd($splitCmd);
  $mgr->endStep($signal);
}

sub assembleTranscripts {
  my ($mgr, $species, $old, $reassemble, $name,$taxId) = @_;
  my $propertySet = $mgr->{propertySet};

  my $signal = "${species}${name}Assemble";

  return if $mgr->startStep("Assemble $name", $signal);

  my $clusterFile = "$mgr->{dataDir}/cluster/$species$name/cluster.out";

  &runAssemblePlugin($clusterFile, "big", $species, $name, $old, $reassemble, $taxId, $mgr);

  $mgr->runCmd("sleep 10");

  &runAssemblePlugin($clusterFile, "small", $species, $name, $old, $reassemble, $taxId, $mgr);
  $mgr->endStep($signal);
  my $msg =
    "EXITING.... PLEASE DO THE FOLLOWING:
 1. check for errors in assemble.err and sql failures in updateDOTSAssemblies.log
 2. resume when assembly completes (validly) by re-runnning '$pipelineScript $mgr->{propertiesFile}'
";
  print STDERR $msg;
  print $msg;
  $mgr->goodbye($msg);
}

sub reassembleTranscripts {
  my ($mgr, $species, $name, $taxId,$taxonName) = @_;
  my $propertySet = $mgr->{propertySet};

  my $signal = "${species}${name}Reassemble";

  return if $mgr->startStep("Reassemble ${species}${name}", $signal);

  my $taxonId = &getTaxonId($mgr,$taxId,$taxonName);

  my $sql = "select na_sequence_id from dots.assembly where taxon_id = $taxonId  and (assembly_consistency < 90 or length < 50 or length is null or description = 'ERROR: Needs to be reassembled')";

  print $sql . "\n"; # DEBUG
  my $clusterFile = "$mgr->{dataDir}/cluster/$species$name/cluster.out";

  my $suffix = "reassemble";

  my $old = "";

  my $reassemble = "yes";

  my $cmd = "makeClusterFile --idSQL \"$sql\" --clusterFile $clusterFile.$suffix";

  $mgr->runCmd($cmd);

  &runAssemblePlugin($clusterFile, $suffix, $species, $name, $old, $reassemble, $taxId, $mgr);

  $mgr->endStep($signal);
  my $msg =
    "EXITING.... PLEASE DO THE FOLLOWING:
 1. resume when reassembly completes (validly) by re-runnning '$pipelineScript $mgr->{propertiesFile}'
";
  print STDERR $msg;
  print $msg;
  $mgr->goodbye($msg);
}

sub runAssemblePlugin {
  my ($file, $suffix, $species, $name, $assembleOld, $reassemble, $taxId, $mgr,$taxonName) = @_;
  my $propertySet = $mgr->{propertySet};

  my $taxonId = &getTaxonId($mgr,$taxId,$taxonName);
  my $cap4Dir = $propertySet->getProp('cap4Dir');
  my $reass = $reassemble eq "yes"? "--reassemble" : "";
  my $args = "--clusterfile $file.$suffix $assembleOld $reass --taxon_id $taxonId --cap4Dir $cap4Dir";
  my $pluginCmd = "ga DoTS::DotsBuild::Plugin::UpdateDotsAssembliesWithCap4 --commit $args --comment '$args'";

  print "running $pluginCmd\n";
  my $logfile = "$mgr->{myPipelineDir}/logs/${species}${name}Assemble.$suffix.log";

  my $assemDir = "$mgr->{dataDir}/assembly/$species$name/$suffix";
  $mgr->runCmd("mkdir -p $assemDir");
  chdir $assemDir || die "Can't chdir to $assemDir";

  my $cmd = "runUpdateAssembliesPlugin --clusterFile $file.$suffix --pluginCmd \"$pluginCmd\" 2>> $logfile";
  $mgr->runCmdInBackground($cmd);
}


sub updateAssemblySourceId {
  my ($mgr,$species,$ncbiTaxId,$taxonName) = @_;

  my $propertySet = $mgr->{propertySet};

  my $taxonId = &getTaxonId($mgr,$ncbiTaxId,$taxonName) if $ncbiTaxId;  

  my $signal = "${species}UpdateAssSourceId";

  return if $mgr->startStep("Updating dots.assembly.source_id", $signal);

  $species =~ s/\b(\w\w)\w+/$1/;

  $species = "${species}DT.";

  my $log = "$mgr->{myPipelineDir}/logs/${signal}.log";

  $mgr->runCmd("updateAssSourceIdFromPK --prefix $species --suffix '.tmp' --TaxonId $taxonId 2>> $log");

  $mgr->endStep($signal);
}

sub deleteAssembliesWithNoTranscripts {
  my ($mgr, $species, $name, $ncbiTaxId,$taxonName) = @_;
  my $taxonId = &getTaxonId($mgr,$ncbiTaxId,$taxonName) if $ncbiTaxId;
  my $args = "--taxon_id $taxonId";

  $mgr->runPlugin("${species}${name}deleteAssembliesWithNoAssSeq", 
		  "DoTS::DotsBuild::Plugin::DeleteAssembliesWithNoAssemblySequences",
		  $args, "Deleting assemblies with no assemblysequences");
}


sub startTranscriptMatrixOnComputeCluster {
  my ($mgr, $species, $name) = @_;
  my $propertySet = $mgr->{propertySet};

  my $signal = "${species}${name}TranscriptMatrix";
  return if $mgr->startStep("Starting ${species}${name}Transcript matrix", $signal);

  $mgr->endStep($signal);

  my $cmd = "run" . ucfirst($signal);

  my $cmdMsg = "submitPipelineJob $cmd $mgr->{clusterDataDir} NUMBER_OF_NODES";
  my $logMsg = "monitor $mgr->{clusterDataDir}/logs/*.log and xxxxx.xxxx.stdout";

  print $cmdMsg . "\n" . $logMsg . "\n";

  $mgr->exitToCluster($cmdMsg, $logMsg, 0);
}

# copies a 'master' dir
sub copyFilesFromComputeCluster {
  my ($mgr,$name,$dir) = @_;
  my $propertySet = $mgr->{propertySet};

  my $clusterServer = $propertySet->getProp('clusterServer');

  my $signal = "copy${name}ResultsFromCluster";
  return if $mgr->startStep("Copying $name results from $clusterServer",
			    $signal);

  $mgr->{cluster}->copyFrom(
		       "$mgr->{clusterDataDir}/$dir/$name/",
		       "master",
		       "$mgr->{dataDir}/$dir/$name");
  $mgr->endStep($signal);
}

# for copying an arbitrary file or directory
sub copyFileOrDirFromComputeCluster {
  my ($mgr, $fromDir, $fromFile, $toDir) = @_;

  my $signal = "copy${fromDir}/${fromFile}FromCluster";
  $signal =~ s|/|_|g;
  my $clusterServer = $mgr->{propertySet}->getProp('clusterServer');
  return if $mgr->startStep("Copying ${fromDir}/${fromFile} results from $clusterServer",
			    $signal);

  $mgr->{cluster}->copyFrom($fromDir, $fromFile, $toDir);
  $mgr->endStep($signal);
}

sub usage {
  my $prog = `basename $0`;
  chomp $prog;
  print STDERR "usage: $prog propertiesfile [-printXML -skipCleanup]\n";
  exit 1;
}

sub insertTaxonRow {
  my ($mgr,$name,$nameClass,$rank,$parentTaxId,$parentRank) = @_;

  my $args = "--name $name --nameClass $nameClass --rank $rank --parentNcbiTaxId $parentTaxId --parentRank $parentRank";

   $mgr->runPlugin("${name}TaxonInserted",
                  "ApiCommonData::Load::Plugin::InsertTaxonAndTaxonName",
                  $args, "Inserting taxon and taxonname rows for $name");
}


sub getTaxonIdFromTaxId {
  my ($mgr,$taxId) = @_;

  my $propertySet = $mgr->{propertySet};

  my %taxHsh;
  foreach my $tax ( @$taxId) {
    my ($species,$tax_id) = split (/\:/,$tax);
    my $sql = $tax_id ? "select taxon_id from sres.taxon where ncbi_tax_id = $tax_id" : "select taxon_id from sres.taxonname where name = '${species}' and name_class = 'scientific name'";
    my $cmd = "getValueFromTable --idSQL \"$sql\"";
    my $taxonId = $mgr->runCmd($cmd);
    $taxHsh{$species} = $taxonId;
  }

  return  \%taxHsh;
}

sub getTaxonId {
  my ($mgr,$taxId,$taxonName) = @_;

  my $sql = $taxId ? "select taxon_id from sres.taxon where ncbi_tax_id = $taxId" : "select taxon_id from sres.taxonname where name = '${taxonName}' and name_class = 'scientific name'";

  my $cmd = "getValueFromTable --idSQL \"$sql\"";

  my $taxonId = $mgr->runCmd($cmd);

  return $taxonId;
}

sub getSoId {
  my ($mgr,$soTermIdsOrNames) = @_;

  my ($soTermIds,$soTerms);


  if($soTermIdsOrNames =~ /SO:/){

    my @soIds = map{"'$_'"} split(/,/, $soTermIdsOrNames);
    $soTermIds =  join(",",@soIds);

    #$soTermIds =  join(",", map { "'$_'" } split(/,/, $soTermIdsOrNames));
  }else{

    my @soTerms = map{"'$_'"} split(/,/, $soTermIdsOrNames);
    $soTerms =  join(",",@soTerms);

    #$soTerms =  join(",", map { "'$_'" } split(/,/, $soTermIdsOrNames));
  }

  my $sql = $soTermIds ? "select sequence_ontology_id from sres.sequenceontology where so_id IN (${soTermIds})" : "select sequence_ontology_id from sres.sequenceontology where term_name IN (${soTerms})";

  my $cmd = "getValueFromTable --idSQL \"$sql\"";

  print STDERR "This is the command: $cmd\n";

  my $soIds = $mgr->runCmd($cmd);

  return $soIds;
}

sub getTaxonIdList {
  my ($mgr,$taxonId,$hierarchy) = @_;
  my $propertySet = $mgr->{propertySet};
  my $returnValue;

  if ($hierarchy) {
    $returnValue = $mgr->runCmd("getSubTaxaList --taxon_id $taxonId");
    chomp $returnValue;
  } else {
    $returnValue = $taxonId;
  }

  return $returnValue;
}

sub getNCBITaxIdList {
  my ($mgr,$taxonId,$hierarchy) = @_;
  my $propertySet = $mgr->{propertySet};
  my $returnValue;

  if ($hierarchy) {
    $returnValue = $mgr->runCmd("getSubNCBITaxaList --taxon_id $taxonId");
    chomp $returnValue;
  } else {
    $returnValue = $taxonId;
  }

  return $returnValue;
}

sub getContigDbRlsHsh {
  my ($mgr) = @_;
  my $propertySet = $mgr->{propertySet};
  my %configDbRlsHsh;

  my $extDbName = $propertySet->getProp('contigDbName');
  my @nameArr = split(/\,/,$extDbName);
  my $extDbRlsVer = $propertySet->getProp('contigDbRlsVer');
  my @verArr = split(/\,/,$extDbRlsVer);

  foreach my $namePair (@nameArr){
    my ($species,$name) = split(/\:/,$namePair);
    $configDbRlsHsh{$species}[0] = $name;
  }
  foreach my $verPair (@verArr){
    my ($species,$ver) = split(/\:/,$verPair);
    $configDbRlsHsh{$species}[1] = $ver;
  }
  foreach my $species (keys %configDbRlsHsh) {
    my $dbRlsId =  &getDbRlsId($mgr,$configDbRlsHsh{$species}[0],$configDbRlsHsh{$species}[1]);
    $configDbRlsHsh{$species}[2] = $dbRlsId;
  }

  return \%configDbRlsHsh;
}

sub getDbRlsId {
  my ($mgr,$extDbName,$extDbRlsVer) = @_;

  my $propertySet = $mgr->{propertySet};

  my $sql = "select external_database_release_id from sres.externaldatabaserelease d, sres.externaldatabase x where x.name = '${extDbName}' and x.external_database_id = d.external_database_id and d.version = '${extDbRlsVer}'";

  my $cmd = "getValueFromTable --idSQL \"$sql\"";
  my $extDbRlsId = $mgr->runCmd($cmd);

  return  $extDbRlsId;
}

sub createExtDbAndDbRls {
  my ($mgr,$extDbName,$extDbRlsVer,$extDbRlsDescrip) = @_;

  my $dbPluginArgs = "--name '$extDbName' ";

  my $signalName = $extDbName;
  $signalName =~ s/\s/_/g;

  $mgr->runPlugin("createDb_${signalName}",
			  "GUS::Supported::Plugin::InsertExternalDatabase",$dbPluginArgs,
			  "Inserting/checking external database info for $extDbName");

  my $releasePluginArgs = "--databaseName '$extDbName' --databaseVersion '$extDbRlsVer'";

  $releasePluginArgs .= " --description '$extDbRlsDescrip'" if $extDbRlsDescrip;

  $mgr->runPlugin("createRelease_${signalName}_$extDbRlsVer",
		  "GUS::Supported::Plugin::InsertExternalDatabaseRls",$releasePluginArgs,
		  "Inserting/checking external database release for $extDbName $extDbRlsVer");
}


sub getTableId {
  my ($mgr,$tableName) = @_;

  my $propertySet = $mgr->{propertySet};

  my $sql = "select table_id from core.tableinfo where name = '$tableName'";

  my $cmd = "getValueFromTable --idSQL \"$sql\"";
  my $tableId = $mgr->runCmd($cmd);
  return  $tableId;
}


sub runPFamHmm{
  my ($mgr,$name,$cmd,$dir) = @_;

  my $propertySet = $mgr->{propertySet};
  my $signal = $name;
  my $seqfilesDir = "$mgr->{dataDir}/seqfiles/";
  my $outfilesDir = "$mgr->{dataDir}/analysis/";
  my $fi = "${name}.fsa";
  my $fo = "${name}.out";

  $cmd = "$dir$cmd$outfilesDir $seqfilesDir$fi >$outfilesDir$fo";
  $mgr->runCmd($cmd);
  $mgr->endStep($signal);
}




sub loadPfamData{
  my ($mgr,$name) = @_;
  my $propertySet = $mgr->{propertySet};

  my $alg = "hmmpfam";
  my $ver = $propertySet->getProp('hmmpfamVer');
  my $desc = "$alg $ver";
  my $outfilesDir = "$mgr->{dataDir}/analysis/";
  my $f = "${name}.out";
  my $file = "$outfilesDir$f";
  my $extDbName = $propertySet->getProp('contigDbName');
  my $extDbRlsVer = $propertySet->getProp('contigDbRlsVer');

  my $args = "--data_file $file --algname $alg --algVer $ver --alg_desc $desc --$extDbName $extDbName --extDbRlsVer $extDbRlsVer";
  $mgr->runPlugin("LoadPfamOutput", "ApiCommonData::Load::Plugin::LoadPfamOutput", $args, "Loading $name output");
}

sub makeUserProjectGroup {
  my ($mgr) = @_;

  my $propertySet = $mgr->{propertySet};

  my $firstName = $propertySet->getProp('firstName');

  my $lastName = $propertySet->getProp('lastName');

  my $release = $propertySet->getProp('release');

  my $signal = "${lastName}UserProjectGroup";

  return if $mgr->startStep("Inserting userinfo,groupinfo,projectinfo for $lastName gus config file", $signal);

  $mgr->runCmd ("insertUserProjectGroup --firstName $firstName --lastName $lastName --projectRelease $release --commit");

  $mgr->endStep($signal);
}


sub transformSimilarityCoordinates {
  my ($mgr, $extDbRlsSpec, $virtExtDbRlsSpec, $seqRole) = @_;


  my $signal = "transform${seqRole}SimilarityToVirtualCoordinates";

  my $args = "--extDbRlsSpec '$extDbRlsSpec' --virtExtDbRlsSpec '$virtExtDbRlsSpec' --sequenceRole $seqRole";

  $mgr->runPlugin($signal, "ApiCommonData::Load::Plugin::TransformSimilarityCoordinates", $args, "Transforming Similarity coordinates from '$extDbRlsSpec' to '$virtExtDbRlsSpec'");

}


# $seqFile from earlier extractNaSeq() step, outputs gff file to sseqfiles
sub makeOrfFile {
  my ($mgr, $seqFile, $minPepLength) = @_;
  my $propertySet = $mgr->{propertySet};

  my $outFile = $seqFile;
  $outFile =~ s/\.\w+\b//;
  $outFile = "${outFile}_orf${minPepLength}.gff";
  $outFile = "$mgr->{dataDir}/seqfiles/$outFile";
  
  my $signal = "makeOrfFileFrom_${seqFile}";
  return if $mgr->startStep("makeOrfFile from $seqFile", $signal);

  my $cmd = <<"EOF";
orfFinder --dataset $mgr->{dataDir}/seqfiles/$seqFile \\
--minPepLength $minPepLength \\
--outFile $outFile
EOF

  $mgr->runCmd($cmd);
  $mgr->endStep($signal);
}

sub loadOrfFile {
    my ($mgr, $orfFile, $extDbName, $extDbRlsVer, $mapFile, $soCvsVersion, $subclass, $defaultOrg) = @_;

    my $signal = "load_$orfFile";

    my $args = <<"EOF";
--extDbName '$extDbName'  \\
--extDbRlsVer '$extDbRlsVer' \\
--mapFile $mapFile \\
--inputFileOrDir $mgr->{dataDir}/seqfiles/$orfFile \\
--fileFormat gff3   \\
--seqSoTerm ORF  \\
--soCvsVersion $soCvsVersion \\
--naSequenceSubclass $subclass \\
EOF

    if ($defaultOrg){
      $args .= "--defaultOrganism '$defaultOrg'";
    }

    $mgr->runPlugin(
        $signal,
        "GUS::Supported::Plugin::InsertSequenceFeatures",
        $args, 
        "Loading $orfFile output");

}


sub loadTransposableElementFromGff {
    my ($mgr, $gffFile, $extDbName, $extDbRlsVer, $mapFile, $seqExtDbName,$seqExtDbRlsVer,$soCvsVersion, $subclass, $defaultOrg,$enzymeDB) = @_;

    my $signal = "load_$gffFile";

    my $args = <<"EOF";
--extDbName '$extDbName'  \\
--extDbRlsVer '$extDbRlsVer' \\
--mapFile $mapFile \\
--inputFileOrDir $gffFile \\
--fileFormat gff2   \\
--gff2GroupTag ID \\
--handlerExternalDbs $enzymeDB \\
--seqIdColumn source_id \\
--seqExtDbName $seqExtDbName \\
--seqExtDbRlsVer $seqExtDbRlsVer \\
--soCvsVersion $soCvsVersion \\
--naSequenceSubclass $subclass \\
EOF

    if ($defaultOrg){
      $args .= "--defaultOrganism '$defaultOrg'";
    }

    $mgr->runPlugin(
        $signal,
        "GUS::Supported::Plugin::InsertSequenceFeatures",
        $args, 
        "Loading $gffFile output");

}


sub modifyOrfFileForDownload {
  my ($mgr,$genus,$species,$dbName,$file) = @_;

  my $signal = "${genus}${species}OrfDownload";

  return if $mgr->startStep("Modifying $file for fasta formatted download file", $signal);

  my $propertySet = $mgr->{propertySet};

  my $release = $propertySet->getProp('release');

  my $dataDir = $mgr->{'dataDir'};

  $genus =~ /\b(\w)/;

  my $dir = $1;

  $species =~ /\b(\w)/;

  my $sp = $1;

  my $speciesAbreviation = "${dir}$sp";

  my $database = lcfirst($dbName);

  my $output = "${dir}${species}Orfs";
  $output .= "_${database}-${release}.fasta";

  $dir = "${dir}$species";

  $mgr->runCmd("mkdir -p $dataDir/downloadSite/$dir");

  my $cmd = "modifyOrfFileDefline --outFile $dataDir/downloadSite/$dir/$output --inFile $dataDir/seqfiles/$file --species $speciesAbreviation --dbName $dbName";

  $mgr->runCmd($cmd);

  $mgr->endStep($signal);
}

sub copyToDownloadSiteWithSsh {
  my ($mgr,$serverDir) = @_;

  my $propertySet = $mgr->{propertySet};

  my $server = $propertySet->getProp('downloadServer');

  my $user = $propertySet->getProp('downloadUser');

  my $signal = "copyDownloadDirTo$server";

  return if $mgr->startStep("Copying download directory files to $server using ssh", $signal);

  my $release = $propertySet->getProp('release');

  my $dataDir = $mgr->{'dataDir'};

  my $cmd = "mv $dataDir/downloadSite $dataDir/release-$release\n";

  $mgr->runCmd($cmd);

  my $ssh = GUS::Pipeline::SshCluster->new($server,$user);

  $ssh->setManager($mgr);

  $ssh->copyTo($dataDir, "release-$release", $serverDir);

  $mgr->runCmd("mv $dataDir/release-$release $dataDir/downloadSite");

  $mgr->endStep($signal);
}

###########IPRSCAN#####################
## the environment on the compute cluster must be set for the iprscan directory path
## example: setenv IPRSCAN_HOME /genomics/share/pkg/bio/interproscan/iprscan_v4.3.1
#######################################


sub documentIPRScan {
  my ($mgr,$version) = @_;
  my $description = "InterProScan scans protein sequences against the protein signatures of the InterPro member databases including PROSITE, PRINTS, xPfam, ProDom,SMART, TIGRFAMs, PIR, SUPERFAMILY.";
  my $documentation =    { name => "InterProScan",
                         input => "fasta file of protein sequences and InterPro databases",
			   output => "file containing the domain matched, description of the interpro entry, GO description of the Interpro entry and E-value of the match",
			   descrip => $description,
                           tools => [{ name => "InterProScan",
				       version => $version,
				       params => "",
				       url => "http://www.ebi.ac.uk/InterProScan/",
				       pubmedIds => "11590104x",
				       credits => " Zdobnov E.M. and Apweiler R. ,
                                                  InterProScan - an integration platform for the signature-recognition methods in InterPro,
                                                  Bioinformatics, 2001, 17(9): 847-8"}]};

 $mgr->documentStep("InterProScan", $documentation);
}

sub createIprscanDir{
  my ($mgr, $subjectFile) = @_;

  my $propertySet = $mgr->{propertySet};
  my $subject = $subjectFile;
  my $signal = "make" . $subject . "IprscanDir";

  my $dataDir = $mgr->{'dataDir'};
  my $clusterDataDir = $mgr->{'clusterDataDir'};
  my $nodePath = $propertySet->getProp ('nodePath');
  my $taskSize = $propertySet->getProp ('iprscan.taskSize');
  my $nodeClass = $propertySet->getProp ('nodeClass');

  my $appl = $propertySet->getProp('iprscan.appl'); 
  my $email = $propertySet->getProp ('iprscan.email') 
  					? $propertySet->getProp('iprscan.email') 
  					: $ENV{USER} . "\@pcbi.upenn.edu";

  return if $mgr->startStep("Creating iprscan dir", $signal);
  $mgr->runCmd("mkdir -p $dataDir/iprscan");
  #Disable this to allow InterPro DBs to be upgrated independent of the 
  #Inteproscan release, just in case. 
  my $doCrc = "false";

  &makeIprscanDir ($subject, $dataDir, $clusterDataDir,
		   $nodePath, $taskSize, 
		   $nodeClass, "$clusterDataDir/seqfiles",
		   $subjectFile, "p", $appl, $doCrc, $email);

  $mgr->endStep($signal);
}

sub startIprScanOnComputeCluster {
  my ($mgr,$dir,$queue, $returnImmediately, $ppn) = @_;

  my $propertySet = $mgr->{propertySet};

  my $signal = "start" . uc($dir) . "IprScan";

  return if $mgr->startStep("Starting iprscan of $dir on cluster", $signal);

  $mgr->endStep($signal);

  my $clusterCmdMsg = "runIprScan $mgr->{clusterDataDir} NUMBER_OF_NODES $dir $queue, $ppn";
  my $clusterLogMsg = "monitor $mgr->{clusterDataDir}/logs/${dir}_Iprscan.log";

  $mgr->exitToCluster($clusterCmdMsg, $clusterLogMsg, $returnImmediately);
}

 #LoadIprscanResults.
 sub loadIprscanResults{
   my ($mgr, $dir, $extDbName, $extDbRlsVer, $conf, $aaTable, $addedArgs) = @_;

   my $propertySet = $mgr->{propertySet};

   my $resultFileDir = "$mgr->{dataDir}/iprscan/$dir/master/mainresult/";

   my $signal = "load${dir}Iprscan";
   return if $mgr->startStep("Starting Data Load $signal", $signal);
   
   my $goversion = $propertySet->getProp('iprscan.goversion');

   my $aaSeqTable = $aaTable ? $aaTable : 'TranslatedAASequence';

   

   my $args = <<"EOF";
--resultFileDir=$resultFileDir \\
--confFile=$conf \\
--aaSeqTable=$aaSeqTable \\
--extDbName='$extDbName' \\
--extDbRlsVer='$extDbRlsVer' \\
--goVersion=\'$goversion\' \\
$addedArgs \\
EOF

   $mgr->runPlugin($signal, 
         "ApiCommonData::Load::Plugin::InsertInterproscanResults", 
         $args,
         "Loading $dir Iprscan output");
}

###############################################
# Isolate Vocabulary Steps
##############################################

# Insert ontology terms
sub isolateVocabulary{

my ($mgr, $inFile) = @_;

my $signal = "isolateVocabInsertTerms";

return if $mgr->startStep("Inserting Isolate Vocabulary", $signal);

my $logFile = "$mgr->{myPipelineDir}/logs/${signal}.log";

my $propertySet = $mgr->{propertySet};

my $gus_config_file = $propertySet->getProp('gusConfigFile');

my $cmd = "updateIsolateVocabulary.pl --gus_config_file $gus_config_file --inFile $inFile";

$mgr->runCmd($cmd);

$mgr->endStep($signal);
}
################################

# Create vocabulary reports
sub isolateVocabularyReport{

my ($mgr,  $fileType, $xmlFile, $outFile) = @_;
 
my $signal = "isolateVocabReport_$fileType";

return if $mgr->startStep("Running Isolate Vocabulary Report_$fileType", $signal);

my $logFile = "$mgr->{myPipelineDir}/logs/${signal}.log";

my $propertySet = $mgr->{propertySet};

my $gus_config_file = $propertySet->getProp('gusConfigFile');

my $cmd = "isolateVocabulary.pl report --gus_config_file $gus_config_file --type $fileType --xml_file $xmlFile > $outFile 2>> $logFile";

$mgr->runCmd($cmd);

$mgr->endStep($signal);
}
#################################

# Update Database
sub isolateVocabularyUpdate{

my ($mgr, $fileType, $xmlFile) = @_;
	
my $signal = "updateIsolateVocab_$fileType";

return if $mgr->startStep("Updating $fileType Isolate Vocabulary", $signal);

my $logFile = "$mgr->{myPipelineDir}/logs/${signal}.log";

my $propertySet = $mgr->{propertySet};

my $gus_config_file = $propertySet->getProp('gusConfigFile');

my $cmd = "isolateVocabulary.pl update --gus_config_file $gus_config_file --type $fileType --xml_file $xmlFile 2>> $logFile";

$mgr->runCmd($cmd);

$mgr->endStep($signal);
}

  
################################################################################
# OrthoMCL steps
################################################################################

# load the OrthoMCL groups
sub loadOrthoMCLResultsForOrthomclDB {
   my ($mgr, $extDbName, $extDbRlsVer, $orthoFile, $addedArgs) = @_;


   my $orthoFileFullPath = "$mgr->{dataDir}/mcl/$orthoFile";

   my $signal = "loadOrthoMCLResult";
   return if $mgr->startStep("Starting Data Load $signal", $signal);

   my $args = " --orthoFile $orthoFileFullPath --extDbName '$extDbName' --extDbVersion '$extDbRlsVer' $addedArgs";

   $mgr->runPlugin($signal, 
         "OrthoMCLData::Load::Plugin::InsertOrthologousGroupsFromMcl", 
         $args,
         "Loading OrthoMCL output");
}

# update ortholog group fields
sub updateOrthologGroups {

  my ($mgr) = @_;

  my $signal = "updateOrthologGroups";

  my $args = "";

  return if $mgr->startStep("Updating the statistical fields of each OrthologGroup and OrthologGroupAASequence", $signal);

  $mgr->runPlugin($signal, 
         "OrthoMCLData::Load::Plugin::UpdateOrthologGroup",
         $args,
         "Updating  OrthoGroup and OrthologGroupAASequence");

}

sub extractFilesForMsa {
  my ($mgr, $tarSize) = @_;

  my $signal = "extractGroupsFiles";

  return if $mgr->startStep("extracting groups files for msa", $signal);

  my $dir = "$mgr->{dataDir}/seqfiles/groups";

  my $logfile = "$mgr->{myPipelineDir}/logs/${signal}.log";

  $mgr->runCmd("mkdir -p $dir");

  $mgr->runCmd("extractGroupFastaFiles --outputDir $dir --tarBall $tarSize 2>> $logfile");

  $mgr->endStep($signal);
}

sub updateSecondaryIds {
  my ($mgr) = @_;

  my $signal = "updateAASeqSecIds";

  return if $mgr->startStep("updating dots.externalaasequence.secondary_identifier from source_id and abbrev", $signal);

  $mgr->runCmd("updateAASecondaryId");

  $mgr->endStep($signal);
}

sub startMuscleOnCluster {
  my ($mgr, $queue) = @_;

  my $propertySet = $mgr->{propertySet};

  my $signal = "startMuscleOnCluster";

  return if $mgr->startStep("Starting iprscan on cluster", $signal);

  $mgr->endStep($signal);

  my $clusterCmdMsg = "runMsa --buildDir $mgr->{clusterDataDir} --numnodes NUMBER_OF_NODES --queue $queue";
  my $clusterLogMsg = "monitor $mgr->{clusterDataDir}/logs/msa.log";

  $mgr->exitToCluster($clusterCmdMsg, $clusterLogMsg);

}

sub loadMsaResultFiles {
  my ($mgr,$dir,$regex,$untar) = @_;

  my $propertySet = $mgr->{propertySet};
  my $signal = "loadMsaResult";

  return if $mgr->startStep("load MSA results", $signal);

  my $msaDir = "$mgr->{dataDir}/msa/$dir";

  $mgr->runCmd("mkdir -p $msaDir");

  if ($untar) {

    chdir "$mgr->{dataDir}/msa/master/mainresult/";

    opendir(DIR, "$mgr->{dataDir}/msa/master/mainresult/") || die "Can't open directory '$mgr->{dataDir}/msa/master/mainresult/'";

    while (my $file = readdir (DIR)) {

      next if ($file eq "." || $file eq "..");

      $mgr->runCmd("tar -C $msaDir -zxf $file");
    }

    closedir(DIR);
  }

  my $args = "--msaDir $mgr->{dataDir}/msa/$dir --fileRegex \"$regex\" ";

  $mgr->runPlugin($signal,
		  "OrthoMCLData::Load::Plugin::UpdateOrthGroupWithMsa", $args,
		  "Updating rows in apidb.orthologgroup from msa files");
}


sub loadGroupTaxonMatrix {
  my ($mgr) = @_;

  $mgr->runPlugin("loadOrthomclGroupMatrix",
                  "OrthoMCLData::Load::Plugin::InsertOrthomclGroupTaxonMatrix", ,
                  "Inserting rows into apidb.GroupTaxonMatrix");
}

sub loadMsaResult {
  my ($mgr, $msaName) = @_;

  my $propertySet = $mgr->{propertySet};
  my $signal = "loadMsaResult";

  return if $mgr->startStep("load MSA results", $signal);

  my $msaDir = "$mgr->{dataDir}/msa/$msaName";

  # $mgr->runCmd("mkdir -p $msaDir");

#   chdir "$mgr->{dataDir}/msa/master/mainresult/";

#   opendir(DIR, "$mgr->{dataDir}/msa/master/mainresult/") || die "Can't open directory '$mgr->{dataDir}/msa/master/mainresult/'";

#    while (my $file = readdir (DIR)) {

#      next if ($file eq "." || $file eq "..");

#      print STDERR "$file\n";

#      $mgr->runCmd("tar -C $msaDir -zxf $file");
#    }

#    closedir(DIR);

  my $gusConfigFile = $propertySet->getProp('gusConfigFile');

  my $logFile = "$mgr->{myPipelineDir}/logs/${signal}.log";

  my $jdbcDsn = $propertySet->getProp('jdbcDsn');
  my $password = $propertySet->getProp('password');
  my $login = $propertySet->getProp('login');

  my $cmd = <<"EOF";
      orthoPlugin \\
      $gusConfigFile \\
      org.apidb.orthomcl.load.plugin.LoadMsaPlugin \\
      $msaDir \\
EOF

  print STDERR "$cmd\n";
  $mgr->runCmd($cmd);
  $mgr->endStep($signal);
}

# generate and cache Domain keywords for each group
sub generateOrthomclDomainKeywords{
   my ($mgr, $addedArgs) = @_;

   my $signal = "generateOrthomclDomainKeywords";
   return if $mgr->startStep("Starting Data Load $signal", $signal);
   

   my $args = <<"EOF";
$addedArgs \\
EOF

   $mgr->runPlugin($signal, 
         "OrthoMCLData::Load::Plugin::InsertGroupDomains", 
         $args,
         "Generating Orthomcl Domain Keywords");
}


# update ortholog group fields, and load MSA results
sub createBiolayoutData {
  my ($mgr, $svgTemplate) = @_;

  my $signal = "createBiolayoutData";
  return if $mgr->startStep("Generating Biolayout files and images for each group", $signal);
  
  my $signalFile = "/tmp/$signal.finish";
  unlink $signalFile if -e $signalFile;

  # get the gus.config
  my $propertySet = $mgr->{propertySet};
  my $gusConfigFile = $propertySet->getProp('gusConfigFile');

  my $logFile = "$mgr->{myPipelineDir}/logs/${signal}.log";

  my $cmd = <<"EOF";
     orthoPlugin \\
     \"$gusConfigFile\" \\
     \"org.apidb.orthomcl.load.plugin.GenerateBioLayoutPlugin\" \\
     \"$svgTemplate\" \\
     \"$signalFile\" \\
     >> $logFile
EOF

  print STDERR "$cmd\n";
  
  # run the command multiple times till the signal file is created
  do {
      $mgr->runCmd($cmd);
  } until(-e $signalFile);
  unlink $signalFile;
  
  $mgr->endStep($signal);
}


sub updateEviganSecondaryScore {
  my ($mgr, $extDbRlsSpec) = @_;

  my $propertySet = $mgr->{propertySet};
  my $gusConfigFile = $propertySet->getProp('gusConfigFile');

  my $signal = "updateEvigansecondaryScore";

  return if $mgr->startStep("updating secondary score for evigan gene models", $signal);

  $mgr->runCmd("updateEviganSecondaryScore.pl --evigan_ext_db_rls_spec $extDbRlsSpec --gus_config_file $gusConfigFile");

  $mgr->endStep($signal);
}


sub blastSimOutput2ApidbSimSequences {
  my ($mgr, $simFile) = @_;

  my $shortFn = basename($simFile);

  my $signal = "loadApidbSimSequences_$shortFn";
  return if $mgr->startStep("Converting $shortFn for bulk load into Apidb.similarsequences", $signal);

  my $bulkLoaderInput = $simFile . ".blkLd";

  $mgr->runCmd("blastSimOutput2simSeqsInput $simFile >$bulkLoaderInput");

  &sqlLoader($mgr, $bulkLoaderInput);

  $mgr->endStep($signal);
}


sub getNotAlignedEstAndAddOneCluster {
  my ($mgr,$species,$taxId,$taxonHierarchy, $targetTaxId, $blockDir, $clusterDir,$taxonName) = @_;

  my $dataDir = $mgr->{dataDir};

  my $signal = "getNotAlignedEstAndAddOneCluster-$species";

  my $logFile = "$mgr->{myPipelineDir}/logs/${signal}.log";

  return if $mgr->startStep("Getting not aligned ESTs and add them into one cluster", $signal);

  $clusterDir = "$dataDir/$clusterDir";

  my $blockFile = "$dataDir/$blockDir/blocked.err";
 
  my $propertySet = $mgr->{propertySet};

  my $taxonId =  &getTaxonId($mgr,$taxId,$taxonName);

  my $targetTaxonId =  &getTaxonId($mgr,$targetTaxId,$taxonName);

  my $taxonIdList = &getTaxonIdList($mgr,$taxonId,$taxonHierarchy);

  my $sqlEST = "select distinct e.na_sequence_id from dots.ExternalNASequence e, sres.sequenceontology s where e.taxon_id in($taxonIdList) and s.term_name in ('EST','mRNA') and e.sequence_ontology_id = s.sequence_ontology_id";

  my $sqlBLAT = "select distinct query_na_sequence_id from dots.blatalignment where target_taxon_id=$targetTaxonId and is_best_alignment=1 and query_na_sequence_id=?";

  my $sqlBLOCK = "select distinct assembly_sequence_id from DoTS.assemblysequence where na_sequence_id = ?";
  
  my $outputFile ="$clusterDir/AddCluster";
 
  my $cmd = "getSourceIds --idSQLEST \"$sqlEST\" --idSQLBLAT \"$sqlBLAT\" --idSQLBLOCK \"$sqlBLOCK\" --outputFile $outputFile --blockFile $blockFile --clusterDir $clusterDir  2>> $logFile";
 
  $mgr->runCmd($cmd);

  $mgr->endStep($signal);

}


sub getNotAlignedEstAndAddOneCluster_new{
  my ($mgr,$species,$taxId,$taxonHierarchy, $targetTaxId, $blockDir, $clusterDir,$taxonName) = @_;

  my $dataDir = $mgr->{dataDir};

  my $signal = "getNotAlignedEstAndAddOneCluster-$species";

  my $logFile = "$mgr->{myPipelineDir}/logs/${signal}.log";

  return if $mgr->startStep("Getting not aligned ESTs and add them into one cluster", $signal);

  $clusterDir = "$dataDir/$clusterDir";

  my $blockFile = "$dataDir/$blockDir/blocked.err";
 
  my $propertySet = $mgr->{propertySet};

  my $taxonId =  &getTaxonId($mgr,$taxId,$taxonName);

  my $targetTaxonId =  &getTaxonId($mgr,$targetTaxId,$taxonName);

  my $taxonIdList = &getTaxonIdList($mgr,$taxonId,$taxonHierarchy);

  my $outputFile ="$clusterDir/AddCluster";
  my $alignedClustersFile ="$clusterDir/cluster.out.AlignedEsts";

  my $cmd = "getUnalignedAssemSeqIds --outputFile $outputFile --repeatMaskErrFile $blockFile  --alignedClustersFile $alignedClustersFile 2>> $logFile";
 
  $mgr->runCmd($cmd);

  $mgr->endStep($signal);

}

sub updateChromosomeNumberFromMap{
  my ($mgr,$map_file, $sequence_table) = @_;

  my $signal = "updateChromosomeNumberfrom $map_file for $sequence_table";

  my $logFile = "$mgr->{myPipelineDir}/logs/${signal}.log";

  return if $mgr->startStep("Updating Chromosome Number from $map_file for $sequence_table", $signal);

  $mgr->runCmd("updateChromosomeNumberFromMap.pl --map_file $map_file --sequence_table $sequence_table 2>> $logFile");

  $mgr->endStep($signal);
}

sub cleanUpDBRefNaFeature{
  my ($mgr) = @_;

  my $signal = "cleanUpDBRefNaFeature";

  my $logFile = "$mgr->{myPipelineDir}/logs/${signal}.log";

  return if $mgr->startStep("Cleaned Up DBRefNaFeature", $signal);

  $mgr->runCmd("cleanUpDBRefNaFeature.pl 2>> $logFile");

  $mgr->endStep($signal);
}

sub cleanUpNaFeatureNaGene{
  my ($mgr) = @_;

  my $signal = "cleanUpNaFeatureNaGene";

  my $logFile = "$mgr->{myPipelineDir}/logs/${signal}.log";

  return if $mgr->startStep("Cleaned Up NaFeatureNaGene", $signal);

  $mgr->runCmd("cleanUpNaFeatureNaGene.pl 2>> $logFile");

  $mgr->endStep($signal);
}
## these are the old "steps specific" property
## declarations.  we intend to incorporate them into the steps that need them

  my @plasmoProps = (
    # step specific properties
     ["blastsimilarity.taskSize", "", "number of query sequences per blast similarity done on cluster"],
     ["exportpredPath", "", "full path to exportpred software"],
     ["genome.taskSize", "" ,"fill in"],
     ["genome.path", "" ,"fill in"],
     ["genome.options", "" ,"fill in"],
     ["genome.version", "" ,"fill in"],
     ["phrapDir", "", "fill in"],
     ["fileOfRepeats", "", "fill in"],
     ["wuBlastBinPathCluster", "", "path to find wu BLAST on cluster"],
     ["signalP.version", "", "version number for the signalP package"],
     ["signalP.path", "","full path of signalP executable"],
     ["tmhmm.path", "","full path of tmhmm executable"],
     ["tmhmm.version", "","version number for the TMHMM package"],
     ["trfPath", "","path of directory that contains trf400"],
     ["ncbiBlastPath", "", "path to find ncbi blast dir on server"],
     ["psipredPath", "", "path to find the psipred executables"],
     ["psipred.taskSize", "","number of seqs per subtask to be done on compute cluster"],
     ["psipred.clusterpath", "","path to dir containing psipred script on cluster"],
     ["trnascan.taskSize", "", "number of seqs per subtask to be done on compute cluster"],
     ["trnascan.clusterpath", "", "path to dir containing tRNAscan script on cluster"]
 );

my @toxoProps = 
(
 ["wuBlastBinPathCluster", "", "path to find wu BLAST on cluster"],
 ["wuBlastPath", "", "path to find wu BLAST locally"],
 ["blastzPath", "", "path to find BLASTZ locally"],
 ["signalP.version", "", "version number for the signalP package"],
 ["signalP.path", "","full path of signalP executable"],
 ["projectName", "", " project name from projectinfo.name"],
 ["tmhmm.path", "","full path of tmhmm executable"],
 ["tmhmm.version", "","version number for the TMHMM package"],
 ["ncbiBlastPath", "", "path to find ncbi blast dir on server"],
 ["trfPath","","path to find the trf software"]
);

my @orthomclProps = 
(
 ["wuBlastBinPathCluster", "", "path to find wu BLAST on cluster"],
 ["wuBlastPath", "", "path to find wu BLAST locally"],
 ["blastzPath", "", "path to find BLASTZ locally"],
 ["projectName", "", " project name from projectinfo.name"],
 ["ncbiBlastPath", "", "path to find ncbi blast dir on server"],
 ["ncbiBlastBinPathCluster", "", "path to find ncbi BLAST on cluster"],
);

my @orthomclProps = 
(

);

1;
