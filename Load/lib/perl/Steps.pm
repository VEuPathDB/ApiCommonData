use strict;

use Bio::SeqIO;
#use CBIL::Util::GenomeDir;

sub createPipelineDir {
  my ($mgr,$allSpecies) = @_;

  my $propertySet = $mgr->{propertySet};
  my $signal = "createDir";

  return if $mgr->startStep("Creating dir structure", $signal);

  my $pipelineDir = $mgr->{'pipelineDir'};    # buildDir/release/speciesNickname
  print STDERR "$pipelineDir = pipeline dir\n";
  $mgr->runCmd("mkdir -p $pipelineDir/seqfiles") unless (-e "$pipelineDir/seqfiles");
  $mgr->runCmd("mkdir -p $pipelineDir/misc") unless (-e "$pipelineDir/misc");
  $mgr->runCmd("mkdir -p $pipelineDir/downloadSite") unless (-e "$pipelineDir/downloadSite");
  $mgr->runCmd("mkdir -p $pipelineDir/blastSite") unless (-e "$pipelineDir/blastSite");
  $mgr->runCmd("mkdir -p $pipelineDir/sage") unless (-e "$pipelineDir/sage");
  $mgr->runCmd("mkdir -p $pipelineDir/analysis") unless (-e "$pipelineDir/analysis");
  $mgr->runCmd("mkdir -p $pipelineDir/similarity") unless (-e "$pipelineDir/similarity");
  $mgr->runCmd("mkdir -p $pipelineDir/iprscan") unless (-e "$pipelineDir/iprscan");

  my @Species = split(/,/,$allSpecies);

  foreach my $species (@Species) {
    $mgr->runCmd("mkdir -p $pipelineDir/cluster/${species}Initial") unless (-e "$pipelineDir/cluster/${species}initial");
    $mgr->runCmd("mkdir -p $pipelineDir/cluster/${species}Intermed") unless (-e "$pipelineDir/cluster/${species}intermed");
    $mgr->runCmd("mkdir -p $pipelineDir/assembly/${species}Initial/big") unless (-e "$pipelineDir/assembly/${species}initial/big");
    $mgr->runCmd("mkdir -p $pipelineDir/assembly/${species}Initial/small") unless (-e "$pipelineDir/assembly/${species}initial/small");
    $mgr->runCmd("mkdir -p $pipelineDir/assembly/${species}Initial/reassemble") unless (-e "$pipelineDir/assembly/${species}initial/reassemble");
    $mgr->runCmd("mkdir -p $pipelineDir/assembly/${species}Intermed/big") unless (-e "$pipelineDir/assembly/${species}intermed/big");
    $mgr->runCmd("mkdir -p $pipelineDir/assembly/${species}Intermed/small") unless (-e "$pipelineDir/assembly/${species}intermed/small");
    $mgr->runCmd("mkdir -p $pipelineDir/assembly/${species}Intermed/reassemble") unless (-e "$pipelineDir/assembly/${species}intermed/reassemble");
  }

  $mgr->runCmd("chmod -R g+w $pipelineDir");

  $mgr->endStep($signal);
}

sub createBlastMatrixDir {
  my ($mgr, $species, $queryFile, $subjectFile) = @_;

  my $propertySet = $mgr->{propertySet};
  my $signal = "create${queryFile}-${subjectFile}MatrixDir";

  return if $mgr->startStep("Creating ${queryFile}-${subjectFile} dir", $signal);

  my $buildName = $mgr->{'buildName'};        # release/speciesNickname
  my $buildDir = $propertySet->getProp('buildDir');
  my $serverPath = $propertySet->getProp('serverPath');
  my $nodePath = $propertySet->getProp('nodePath');
  my $nodeClass = $propertySet->getProp('nodeClass');
  my $bmTaskSize = $propertySet->getProp('blastmatrix.taskSize');
  my $wuBlastBinPathCluster = $propertySet->getProp('wuBlastBinPathCluster');
  my $pipelineDir = $mgr->{'pipelineDir'};

  my $speciesFile = $species . $queryFile;
  &makeMatrixDir($speciesFile, $species.$subjectFile, $buildName, $buildDir,
       $serverPath, $nodePath, $bmTaskSize, $wuBlastBinPathCluster, $nodeClass);

  $mgr->runCmd("chmod -R g+w $pipelineDir");

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
  my ($mgr,$queryFile,$subjectFile,$regex,$bsParams,$blastType) = @_;
  my $propertySet = $mgr->{propertySet};
  my $signal = "create" . ucfirst($queryFile) . "-" . ucfirst ($subjectFile) ."SimilarityDir";

  my $dbType = ($blastType =~ m/blastn|tblastx/i) ? 'n' : 'p';

  my $description="";


  return if $mgr->startStep("Creating ${queryFile}-${subjectFile} similarity dir", $signal);

  my $buildName = $mgr->{'buildName'};        # release/speciesNickname
  my $buildDir = $propertySet->getProp('buildDir');
  my $serverPath = $propertySet->getProp('serverPath');
  my $nodePath = $propertySet->getProp('nodePath');
  my $nodeClass = $propertySet->getProp('nodeClass');
  my $bsTaskSize = $propertySet->getProp('blastsimilarity.taskSize');
  my $wuBlastBinPathCluster = $propertySet->getProp('wuBlastBinPathCluster');
  my $pipelineDir = $mgr->{'pipelineDir'};

  &makeSimilarityDir($queryFile, $subjectFile, $buildName, $buildDir,
		     $serverPath, $nodePath, $bsTaskSize,
		     $wuBlastBinPathCluster,
		     "${subjectFile}.fsa", "$serverPath/$buildName/seqfiles", "${queryFile}.fsa", $regex, $blastType, $bsParams, $nodeClass,$dbType);

  $mgr->runCmd("chmod -R g+w $pipelineDir");

  $mgr->endStep($signal);
}

sub createRepeatMaskDir {
  my ($mgr, $species, $file) = @_;

  my $propertySet = $mgr->{propertySet};
  my $signal = "make$species" . ucfirst($file) . "SubDir";

  return if $mgr->startStep("Creating $file repeatmask dir", $signal);

  my $buildName = $mgr->{'buildName'};        # release/speciesNickname
  my $buildDir = $propertySet->getProp('buildDir');
  my $serverPath = $propertySet->getProp('serverPath');
  my $nodePath = $propertySet->getProp('nodePath');
  my $nodeClass = $propertySet->getProp('nodeClass');
  my $rmTaskSize = $propertySet->getProp('repeatmask.taskSize');
  my $rmPath = $propertySet->getProp('repeatmask.path');
  my $rmOptions = $propertySet->getProp('repeatmask.options');
  my $dangleMax = $propertySet->getProp('repeatmask.dangleMax');
  my $pipelineDir = $mgr->{'pipelineDir'};

  my $speciesFile = $species . $file;
  &makeRMDir($speciesFile, $buildName, $buildDir,
       $serverPath, $nodePath, $rmTaskSize, $rmOptions, $dangleMax, $rmPath, $nodeClass);

  $mgr->runCmd("chmod -R g+w $pipelineDir");

  $mgr->endStep($signal);
}

sub createGenomeDir {
  my ($mgr, $species, $query, $genome) = @_;
  my $signal = "create$species" . ucfirst($query) . "-" . ucfirst($genome) . "GenomeDir";
  return if $mgr->startStep("Creating ${query}-${genome} genome dir", $signal);

  my $propertySet = $mgr->{propertySet};
  my $buildName = $mgr->{buildName}; # release/nickName : release3.0/crypto
  my $buildDir = $propertySet->getProp('buildDir');
  my $serverPath = $propertySet->getProp('serverPath');
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
  &makeGenomeDir($speciesQuery, $genome, $buildName, $buildDir, $serverPath,
    $nodePath, $gaTaskSize, $gaOptions, $gaPath, $genomeFile, $nodeClass);

  $mgr->runCmd("chmod -R g+w $buildDir/$buildName/");
  $mgr->endStep($signal);
}

sub copyPipelineDirToComputeCluster {
  my ($mgr) = @_;
  my $propertySet = $mgr->{propertySet};
  my $buildName = $mgr->{'buildName'}; 
  my $release = "release".$propertySet->getProp('release');
  my $serverPath = $propertySet->getProp('serverPath');
  my $fromDir =   $propertySet->getProp('buildDir');
  my $signal = "dir2cluster";
  return if $mgr->startStep("Copying $buildName in $fromDir to $serverPath on clusterServer", $signal);

  $mgr->{cluster}->copyTo($fromDir, $buildName, "$serverPath");

  $mgr->endStep($signal);
}


sub moveSeqFile {
  my ($mgr,$file,$dir) = @_;

  my $propertySet = $mgr->{propertySet};

  my $signal = $file;

  $signal =~ s/\///g;

  $signal = "move" . ucfirst($signal);

  return if $mgr->startStep("Moving $file to $dir", $signal);

  my $buildDir = $propertySet->getProp('buildDir');

  my $release = $propertySet->getProp('release');

  my $seqFile = "$buildDir/$release/$file";

  if (! -e $seqFile) { die "$seqFile doesn't exist\n";}

  if ($seqFile =~ /\.gz/) {
    $mgr->runCmd("gunzip -f $seqFile");

    $seqFile =~ s/\.gz//;
  }

  $mgr->runCmd("mkdir -p $mgr->{pipelineDir}/$dir");

  $mgr->runCmd("mv $seqFile $mgr->{pipelineDir}/$dir");

  $mgr->endStep($signal);
}

sub renameFile {
  my ($mgr,$fileName,$newName,$dir) = @_;

  my $propertySet = $mgr->{propertySet};

  my $signal = $fileName;

  $signal =~ s/\///g;

  $signal = "rename" . ucfirst($signal);

  return if $mgr->startStep("Renaming $fileName to $newName in $dir", $signal);

  if (! -e "$mgr->{pipelineDir}/$dir/$fileName") { die "$fileName doesn't exist\n";};

  $mgr->runCmd("mv  $mgr->{pipelineDir}/$dir/$fileName $mgr->{pipelineDir}/$dir/$newName");

  $mgr->endStep($signal);
}

sub copy {
  my ($mgr, $from, $to) = @_;
  my $propertySet = $mgr->{propertySet};

  my $signal = "copy_${from}_${to}";
  $signal =~ s|/|:|g;
  return if $mgr->startStep("Copying $from to $to", $signal);
  unless (-e $from) { die "$from doesn't exist\n";};

  $mgr->runCmd("cp -a  $from $to");
  $mgr->endStep($signal);
}

sub extractNaSeq {
  my ($mgr,$dbName,$dbRlsVer,$name,$seqType,$table,$identifier) = @_;

  my $type = ucfirst($seqType);

  my $dbRlsId = &getDbRlsId($mgr,$dbName,$dbRlsVer);

  my $signal = "extract${name}$type";

  return if $mgr->startStep("Extracting $name $seqType from GUS", $signal);

  my $outFile = "$mgr->{pipelineDir}/seqfiles/${name}${type}.fsa";
  my $logFile = "$mgr->{pipelineDir}/logs/${signal}.log";

  my $sql = my $sql = "select x.$identifier, x.description,
            'length='||x.length,x.sequence
             from dots.$table x
             where x.external_database_release_id = $dbRlsId";

  my $cmd = "gusExtractSequences --outputFile $outFile --idSQL \"$sql\" --verbose 2>> $logFile";

  $mgr->runCmd($cmd);

  $mgr->endStep($signal);
}


sub extractIdsFromBlastResult {
  my ($mgr,$simDir,$idType) = @_;

  my $blastFile = "$mgr->{pipelineDir}/similarity/$simDir/master/mainresult/blastSimilarity.out";

  my $signal = "ext${simDir}BlastIds";

  return if $mgr->startStep("Extracting ids from $simDir Blast result", $signal);

  my $cmd = "gunzip ${blastFile}.gz" if (-e "${blastFile}.gz");

  $mgr->runCmd($cmd) if $cmd;

  my $output = "$mgr->{pipelineDir}/similarity/$simDir/blastSimIds.out";

  my $logFile = "$mgr->{pipelineDir}/logs/${signal}.log";

  $cmd = "makeIdFileFromBlastSimOutput --$idType --subject --blastSimFile $blastFile --outFile $output 2>> $logFile";

  $mgr->runCmd($cmd);

  $mgr->endStep($signal);
}

sub loadNRDBSubset {
  my ($mgr,$idDir,$idFile,$extDbName,$extDbRlsVer) = @_;

  my $signal = "${idDir}NrIdsLoaded";

  my $nrdbFile = "$mgr->{pipelineDir}/seqfiles/nr.fsa";

  my $sourceIdsFile = "$mgr->{pipelineDir}/similarity/$idDir/$idFile";

  my $args = "--externalDatabaseName $extDbName --externalDatabaseVersion $extDbRlsVer --sequenceFile $nrdbFile --sourceIdsFile  $sourceIdsFile --regexSourceId  '>gi\\|(\\d+)\\|' --regexDesc '^>(.+)' --tableName DoTS::ExternalAASequence";

  $mgr->runPlugin($signal,
		  "GUS::Supported::Plugin::LoadFastaSequences", $args,
		  "Load NRDB Ids from $idDir/$idFile");

}

sub loadFastaSequences {
  my ($mgr,$file,$table,$extDbName,$extDbRlsVer,$soTermName,$regexSourceId,$check,$taxId) = @_;

  my $inputFile = "$mgr->{pipelineDir}/seqfiles/$file";

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

  my $logFile = "$mgr->{pipelineDir}/logs/${signal}.log";

  my $trfDir = "$mgr->{pipelineDir}/trf";

  $mgr->runCmd("mkdir -p $trfDir");

#  $mgr->runCmd($cmd) if $cmd;

  if ($file =~ /\.gz/) {

    $mgr->runCmd("gunzip $mgr->{pipelineDir}/${fileDir}/$file");

    $file =~ s/\.gz//;
  }

  my $trfPath =  $propertySet->getProp('trfPath');

  chdir $trfDir || die "Can't chdir to $trfDir";

  my $cmd = "${trfPath}/trf400 $mgr->{pipelineDir}/$fileDir/$file $args -d 2>> $logFile";

  $mgr->runCmd($cmd);

  chdir $mgr->{pipelineDir} || die "Can't chdir to $mgr->{pipelineDir}";

  $mgr->endStep($signal);
}

sub loadTandemRepeats {
  my ($mgr,$file,$args,$dbName,$dbRlsVer) = @_;

  $args =~ s/\s+/\./g;

  my $tandemRepFile = "$mgr->{pipelineDir}/trf/${file}.${args}.dat";

  my $signal = "load$tandemRepFile";

  my $args = "--tandemRepeatFile $tandemRepFile --extDbName $dbName --extDbVersion $dbRlsVer";

  $mgr->runPlugin($signal,
                  "GUS::Supported::Plugin::InsertTandemRepeatFeatures", $args,
                  "Inserting tandem repeats for $file");
}

sub runBLASTZ {
  my ($mgr,$queryDir,$targetFile,$args) = @_;

  my $propertySet = $mgr->{propertySet};

  my $blastzPath = $propertySet->getProp('blastzPath');

  opendir(DIR,$queryDir);

  my $signal;

  my $outputFile;

  while(my $file = readdir(DIR)) {

    $signal = "blastz${file}_$targetFile";

    $outputFile = $file;

    $outputFile =~ s/\.\w+$/\.laj/;

    next if $mgr->startStep("Running BLASTZ for $file vs $targetFile", $signal);

    $mgr->runCmd("mkdir $mgr->{pipelineDir}/similarity/${file}_${targetFile}");

    $mgr->runCmd("${blastzPath}/blastz ${queryDir}/$file  $targetFile $args > $mgr->{pipelineDir}/similarity/${file}_${targetFile}/$outputFile");

    $mgr->endStep($signal);
  }
}

sub  loadAveragedProfiles {
  my ($mgr,$dbSpec,$setName) = @_;

  my $signal = "load${dbSpec}Profile";

  $signal =~ s/\s//g;

  $signal =~ s/\|//g;

  my $args = "--externalDatabaseSpec '$dbSpec' --profileSetNames '$setName'";

  $mgr->runPlugin($signal,
                  "PlasmoDBData::Load::Plugin::InsertAveragedProfiles", $args,
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
  my ($mgr,$dbSpec,$profileSet,$mappingFile,$percentsAveraged) = @_;

  my $propertySet = $mgr->{propertySet};

  my $signal = "expStat$profileSet";

  $signal =~ s/\s//g;

  my $buildDir = $propertySet->getProp('buildDir');

  my $args = "--externalDatabaseSpec '$dbSpec'  --profileSetNames '$profileSet' --timePointsMappingFile '$buildDir/$mappingFile' --percentProfileSet '$percentsAveraged'";

  $mgr->runPlugin($signal,
                  "PlasmoDBData::Load::Plugin::CalculateProfileSummaryStats", $args,
		  "Calculating profile summary stats for $profileSet");

}


sub extractSageTags {
  my ($mgr,$species) = @_;

  my $propertySet = $mgr->{propertySet};

  my $signal = "ext${species}SageTags";

  return if $mgr->startStep("Extracting $species SAGE tags from GUS", $signal);

  my $gusConfigFile = $propertySet->getProp('gusConfigFile');

  foreach my $sageArray (@{$mgr->{sageTagArrays}->{$species}}) {
    my $dbName =  $sageArray->{name};
    my $dbVer =  $sageArray->{ver};

    my $name = $dbName;
    $name =~ s/\s/_/g;

    my $sageTagFile = "$mgr->{pipelineDir}/seqfiles/${name}SageTags.fsa";

    my $logFile = "$mgr->{pipelineDir}/logs/$signal${species}.log";

    my $sql = "select s.composite_element_id,s.tag
             from rad.sagetag s,rad.arraydesign a
             where a.name = '$dbName'
             and a.version = $dbVer
             and a.array_design_id = s.array_design_id";

    my $cmd = "gusExtractSequences --gusConfigFile $gusConfigFile  --outputFile $sageTagFile --idSQL \"$sql\" --verbo\se\ 2>> $logFile";

    $mgr->runCmd($cmd);
  }

  $mgr->endStep($signal);
}

sub mapSageTagsToScaffolds {
  my ($mgr, $species) = @_;

  my $propertySet = $mgr->{propertySet};

  my $signal = "map${species}SageTags";

  return if $mgr->startStep("Mapping SAGE tags to $species scaffolds", $signal);

  foreach my $scaffolds (@{$mgr->{scaffolds}->{$species}}) {
    my $dbName =  $scaffolds->{name};

    my $scafName = $dbName;
    $scafName =~ s/\s/\_/g;

    my $scaffoldFile = "$mgr->{pipelineDir}/seqfiles/${scafName}Scaffolds.fsa";

    foreach my $sageArray (@{$mgr->{sageTagArrays}->{$species}}) {
      my $dbName =  $sageArray->{name};

      my $tagName = $dbName;
      $tagName =~ s/\s/_/g;

      my $sageTagFile = "$mgr->{pipelineDir}/seqfiles/${tagName}SageTags.fsa";

      my $output = "$mgr->{pipelineDir}/sage/${tagName}To${scafName}";

      my $cmd = "tagToSeq.pl $scaffoldFile $sageTagFile 2>> $output";

      $mgr->runCmd($cmd);
    }
  }
  $mgr->endStep($signal);
}

sub loadSageTagMap {
  my ($mgr, $species) = @_;

  my $signal = "load${species}SageTagMap";

  return if $mgr->startStep("Loading SAGE tags to $species scaffolds maps", $signal);

  my $propertySet = $mgr->{propertySet};

  foreach my $scaffolds (@{$mgr->{scaffolds}->{$species}}) {
    my $dbName =  $scaffolds->{name};
    my $scafName = $dbName;
    $scafName =~ s/\s/\_/g;

    foreach my $sageArray (@{$mgr->{sageTagArrays}->{$species}}) {
      my $dbName =  $sageArray->{name};
      my $tagName = $dbName;
      $tagName =~ s/\s/_/g;
      my $inputFile = "$mgr->{pipelineDir}/sage/${tagName}To${scafName}";

      my $args = "--tagToSeqFile $inputFile";

      $mgr->runPlugin("load${tagName}To${scafName}SageTagMap",
		      "ApiCommonData::Load::Plugin::LoadSageTagFeature", $args,
		      "Loading ${tagName}To${scafName} SAGE Tag map results");
    }
  }
    $mgr->endStep($signal);
}



sub concatFiles {
   my ($mgr,$files,$catFile,$fileDir) = @_;

   $files =~ s/(\S+)/$mgr->{pipelineDir}\/${fileDir}\/$1/g;

   my $signal = "concat$catFile";

   my $cmd = "cat $files > $mgr->{pipelineDir}/$fileDir/$catFile";

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
  my ($mgr,$name,$sql) = @_;
  my $propertySet = $mgr->{propertySet};

  my $signal = "${name}Extract";

  return if $mgr->startStep("Extracting $name protein sequences from GUS", $signal);

  my $seqFile = "$mgr->{pipelineDir}/seqfiles/${name}.fsa";
  my $logFile = "$mgr->{pipelineDir}/logs/${name}Extract.log";

  my $cmd = "gusExtractSequences --outputFile $seqFile --idSQL \"$sql\" --verbose 2>> $logFile";

  $mgr->runCmd($cmd);

  $mgr->endStep($signal);
}


sub startProteinBlastOnComputeCluster {
  my ($mgr,$queryFile,$subjectFile) = @_;
  my $propertySet = $mgr->{propertySet};

  my $serverPath = $propertySet->getProp('serverPath');

  my $name = $queryFile . "-" . $subjectFile;

  $name = ucfirst($name);
  my $signal = "startBlast$name";
  return if $mgr->startStep("Starting $name blast on cluster", $signal);

  $mgr->endStep($signal);

  my $clusterCmdMsg = "runBlastSimilarities $serverPath/$mgr->{buildName} NUMBER_OF_NODES $queryFile $subjectFile";
  my $clusterLogMsg = "monitor $serverPath/$mgr->{buildName}/logs/*.log and xxxxx.xxxx.stdout";

  $mgr->exitToCluster($clusterCmdMsg, $clusterLogMsg, 1);
}

sub loadProteinBlast {
  my ($mgr, $name, $queryTable, $subjectTable, 
      $queryTableSrcIdCol,$subjectTableSrcIdCol, # optional, use '' to bypass
      $queryDbName, $queryDbRlsVer,  # optional if no queryTableSrcIdCol
      $subjectDbName, $subjectDbRlsVer, # optional if no subjectTableSrcIdCol
      $addedArgs,$restart) = @_;
      
  my $propertySet = $mgr->{propertySet};

  my $file = (-e "$mgr->{pipelineDir}/similarity/$name/master/mainresult/blastSimilarity.out.gz") ? "$mgr->{pipelineDir}/similarity/$name/master/mainresult/blastSimilarity.out.gz" : "$mgr->{pipelineDir}/similarity/$name/master/mainresult/blastSimilarity.out";
  
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
  my ($mgr, $dbName,$dbRlsVer,$soCvsVersion,$overwrite) = @_;

  my $args = "--sqlVerbose --extDbRlsName '$dbName' --extDbRlsVer '$dbRlsVer' --soCvsVersion $soCvsVersion $overwrite";

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

sub runExportPred {
  my ($mgr,$species) = @_;

  my $propertySet = $mgr->{propertySet};

  my $signal = "exportPred$species";

  return if $mgr->startStep("Predicting the exportome of $species", $signal);

  my $exportpredPath = $propertySet->getProp('exportpredPath');

  my $name = "${species}AnnotatedProteins.fsa";

  my $outputFile = $name;

  $outputFile =~ s/\.\w+$/\.exptprd/;

  my $cmd = "${exportpredPath}/exportpred --input=$mgr->{pipelineDir}/seqfiles/$name --output=$mgr->{pipelineDir}/misc/$outputFile";

  $mgr->runCmd($cmd);

  $mgr->endStep($signal);
}


sub loadExportPredResults {
  my ($mgr,$species,$sourceIdDb,$genDb) = @_;

  my $propertySet = $mgr->{propertySet};

  my $name = "${species}AnnotatedProteins.exptprd";

  my $signal = "loadExportPred$species";

  my $inputFile = "$mgr->{pipelineDir}/misc/$name";

  my $args = "--inputFile  $inputFile --seqTable DoTS::AASequence --seqExtDbRlsSpec '$sourceIdDb' --extDbRlsSpec '$genDb'";

  $mgr->runPlugin($signal,
		  "PlasmoDBData::Load::Plugin::InsertExportPredFeature",
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

  my $path = "$mgr->{pipelineDir}/misc/";

  $files =~ s/(\w|\.)+/${path}$&/g;

  my $args = "--mappingFiles $files";

  my $signal = "correctGeneAliases";

  $mgr->runPlugin($signal,
                  "PlasmoDBData::Load::Plugin::CorrectGeneAliases", $args,
                  "Correct gene aliases in GUS");
}

sub predictAndPrintTranscriptSequences {
  my ($mgr,$species,$dbName,$dbRlsVer,$type) = @_;

  my $cds = $type eq 'cds' ? "--cds" : "";

  $type = $type eq 'transcripts' ? ucfirst($type) : uc($type);

  my $file = "$mgr->{pipelineDir}/seqfiles/${species}Annotated${type}.fsa";

  my $args = "--extDbName '$dbName' --extDbRlsVer '$dbRlsVer' --sequenceFile $file $cds";

  $mgr->runPlugin("predict${species}$type",
		  "GUS::Supported::Plugin::ExtractTranscriptSequences", $args,
		  "Predict and print $species $type");
}

sub formatBlastFile {
  my ($mgr,$file,$fileDir,$link,$arg) = @_;

  my $propertySet = $mgr->{propertySet};

  my $signal = "format$file";

  return if $mgr->startStep("Formatting $file for blast", $signal);

  my $blastBinDir = $propertySet->getProp('ncbiBlastPath');

  my $outputFile1  = "$mgr->{pipelineDir}/$fileDir/$file";

  my $fastalink1 = "$mgr->{pipelineDir}/blastSite/$link";

  $mgr->runCmd("ln -s $outputFile1 $fastalink1");
  $mgr->runCmd("$blastBinDir/formatdb -i $fastalink1 -p $arg");
  $mgr->runCmd("rm -rf $fastalink1");

  $mgr->endStep($signal);
}

sub modifyPlasmoDownloadFile {
  my ($mgr,$dir,$file,$type,$extDb,$extDbVer) = @_;

  my $propertySet = $mgr->{propertySet};

  my $release = $propertySet->getProp('projectRelease');

  my $signal = "modify$file";

  return if $mgr->startStep("Modifying $file for download", $signal);

  my $inFile = "$mgr->{pipelineDir}/seqfiles/$file";

  my $outFile = $file;

  $outFile =~ s/\.\w+\b//;
  $outFile .= "_plasmoDB-${release}.fasta";

  my $outFile = "$mgr->{pipelineDir}/downloadSite/$dir/$outFile";

  $mgr->runCmd("mkdir -p $mgr->{pipelineDir}/downloadSite/$dir");

  $mgr->runCmd("modifyDefLine -infile $inFile -ouitfile $outFile -extDb $extDb -extDbVer $extDbVer -type $type");

  $mgr->endStep($signal);
}

sub modifyPlasmoGenomeDownloadFile {
  my ($mgr,$dir,$file,$type,$extDb,$extDbVer) = @_;

  my $propertySet = $mgr->{propertySet};

  my $release = $propertySet->getProp('projectRelease');

  my $signal = "modify$file";

  return if $mgr->startStep("Modifying $file for download", $signal);

  my $inFile = "$mgr->{pipelineDir}/seqfiles/$file";

  my $outFile = "$mgr->{pipelineDir}/downloadSite/$dir/${dir}Genomic_plasmoDB-${release}.fasta";

  $mgr->runCmd("mkdir -p $mgr->{pipelineDir}/downloadSite/$dir");

  $mgr->runCmd("modifyGenomeDefLine -infile $inFile -outfile $outFile -extDb $extDb -extDbVer $extDbVer -type $type");

  $mgr->endStep($signal);
}

sub makeGFF {
   my ($mgr,$model,$questions,$speciesName,$file) = @_;

   my $propertySet = $mgr->{propertySet};

   my $signal = gff$file;

   return if $mgr->startStep("Making gff $file file", $signal);

   my $release = $propertySet->getProp('projectRelease');

   $file .= "_plasmoDB-${release}.gff";

   $mgr->runCmd("gffDump $model $questions '$speciesName' $file");

   $mgr->endStep($signal);
}

sub removeFile {
  my ($mgr,$file,$fileDir) = @_;

  my $signal = "remove$file";

  return if $mgr->startStep("removing $file from $fileDir", $signal);

  $mgr->runCmd("rm -f $mgr->{pipelineDir}/${fileDir}/$file");

  $mgr->endStep($signal);
}

sub extractAnnotatedProteinsBySpecies {
  my ($mgr, $species,$dbName,$dbRlsVer) = @_;

  my $fname = "${species}AnnotatedProteins";

  my $propertySet = $mgr->{propertySet};

  my $taxonId = $mgr->{taxonHsh}->{$species};

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

  my $logFile = "$mgr->{pipelineDir}/logs/${seqFile}.$filterType.log";

  my $input = "$mgr->{pipelineDir}/seqfiles/$seqFile";

  my $output = "$mgr->{pipelineDir}/seqfiles/${seqFile}.$filterType";

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

  my $input = "$mgr->{pipelineDir}/seqfiles/$file";

  my $args = "--seqFile $input --fileFormat 'fasta' --extDbName '$extdbName' --extDbVersion '$extDbRlsVer' --seqType $type --maskChar $mask $opt";

  my $signal = "load$file";

  $mgr->runPlugin($signal,
		  "PlasmoDBData::Load::Plugin::InsertLowComplexityFeature", $args,
		  "Loading low complexity sequence file $file");

}


sub makeTranscriptSeqs {
  my ($mgr, $species) = @_;
  my $propertySet = $mgr->{propertySet};

  my $file = $propertySet->getProp('fileOfRepeats');
  my $externalDbDir = $propertySet->getProp('externalDbDir');
  my $repeatFile = "$externalDbDir/repeat/$file";

  my $phrapDir = $propertySet->getProp('phrapDir');

  my $taxonHsh = $mgr->{taxonHsh};

  my $taxonId =  $taxonHsh->{$species};
  my $taxonIdList = &getTaxonIdList($mgr,$taxonId );

  my $args = "--taxon_id_list '$taxonIdList' --repeatFile $repeatFile --phrapDir $phrapDir";

  $mgr->runPlugin("make${species}AssemSeqs",
          "DoTS::DotsBuild::Plugin::MakeAssemblySequences", $args,
          "Making assembly table sequences");
}


sub extractTranscriptSeqs {
  my ($mgr, $species, $name) = @_;
  my $propertySet = $mgr->{propertySet};

  my $taxonId = $mgr->{taxonHsh}->{$species};

  my $outputFile = "$mgr->{pipelineDir}/seqfiles/${species}${name}.fsa";
  my $args = "--taxon_id_list '$taxonId' --outputfile $outputFile --extractonly";

    $mgr->runPlugin("${species}_${name}_ExtractUnalignedAssemSeqs",
		    "DoTS::DotsBuild::Plugin::ExtractAndBlockAssemblySequences",
		    $args, "Extracting unaligned assembly sequences");
}

sub extractAssemblies {
  my ($mgr, $species, $name) = @_;
  my $propertySet = $mgr->{propertySet};
  my $signal = "${species}${name}Extract";

  return if $mgr->startStep("Extracting ${species} $name assemblies from GUS", $signal);

  my $taxonId = $mgr->{taxonHsh}->{$species};

  my $seqFile = "$mgr->{pipelineDir}/seqfiles/${species}$name.fsa";
  my $logFile = "$mgr->{pipelineDir}/logs/${species}${name}Extract.log";

  my $sql = "select na_sequence_id,'[$species]',description,'('||number_of_contained_sequences||' sequences)','length='||length,sequence from dots.Assembly where taxon_id = $taxonId";
  my $cmd = "gusExtractSequences --outputFile $seqFile --verbose --idSQL \"$sql\" 2>>  $logFile";

  $mgr->runCmd($cmd);

  $mgr->endStep($signal);
}

sub startTranscriptAlignToContigs {
  my ($mgr, $species, $name) = @_;
  my $propertySet = $mgr->{propertySet};

  my $serverPath = $propertySet->getProp('serverPath');
  my $clusterServer = $propertySet->getProp('clusterServer');

  my $signal = "${species}${name}AlignToContigs";
  return if $mgr->startStep("Aligning $species $name to contigs on $clusterServer", $signal);

  $mgr->endStep($signal);

  my $clusterCmdMsg = "runContigAlign $serverPath/$mgr->{buildName} NUMBER_OF_NODES";
  my $clusterLogMsg = "monitor $serverPath/$mgr->{buildName}/logs/*.log and xxxxx.xxxx.stdout";

  $mgr->exitToCluster($clusterCmdMsg, $clusterLogMsg, 1);
}

sub loadContigAlignments {
  my ($mgr, $species, $queryName, $targetName) = @_;
  my $propertySet = $mgr->{propertySet};

  my $taxonHsh = $mgr->{taxonHsh};
  my $contigDbRlsHsh =  $mgr->{contigDbRlsHsh};

  my $pipelineDir = $mgr->{'pipelineDir'};

  my $signal = "Load${species}${queryName}BLATAlignments";
  return if $mgr->startStep("Loading ${species}${queryName} BLAT Alignments", $signal);
  my $genomeId = $contigDbRlsHsh->{$species}->[2];
  my $taxonId = $taxonHsh->{$species};

  my $pslDir = "$pipelineDir/genome/${species}${queryName}-${targetName}/master/mainresult/per-seq";

  my $qFile = "$pipelineDir/repeatmask/${species}${queryName}/master/mainresult/blocked.seq";
  my $tmpFile;
  my $qDir = "/tmp/" . $species;

    my $qTabId = ($queryName =~ /FinalTranscript/i) ? 
        &getTableId($mgr, "Assembly") :
        &getTableId($mgr, "AssemblySequence");

    $qFile = "$pipelineDir/repeatmask/${species}${queryName}/master/mainresult/blocked.seq";
    $tmpFile = $qDir . "/blocked.seq";

# copy qFile to /tmp directory to work around a bug in the
# LoadBLATAlignments plugin's call to FastaIndex
  $mgr->runCmd("mkdir $qDir") if ! -d $qDir;
  $mgr->runCmd("cp $qFile $tmpFile");

  my $tTabId = ($targetName =~ /contigs/i) ?
        &getTableId($mgr, "ExternalNASequence") :
        &getTableId($mgr, "VirtualSequence");
     
# 56  Assembly
# 57  AssemblySequence
# 89  ExternalNASequence
# 245 VirtualSequence

  my $args = "--blat_dir $pslDir --query_file $tmpFile --keep_best 2 "
    . "--query_table_id $qTabId --query_taxon_id $taxonId "
  . "--target_table_id  $tTabId --target_db_rel_id $genomeId --target_taxon_id $taxonId "
    . "--max_query_gap 5 --min_pct_id 95 max_end_mismatch 10 "
      . "--end_gap_factor 10 --min_gap_pct 90 "
        . "--ok_internal_gap 15 --ok_end_gap 50 --min_query_pct 10 ";

 if ($queryName =~ /NewTranscripts/i) {
   my $extDbName = $propertySet->getProp('genbankDbName');
  my $extDbRlsVer = $propertySet->getProp('genbankDbRlsVer');
   $mgr->{genbankDbRlsId} =  &getDbRlsId($mgr,$extDbName,$extDbRlsVer) unless $mgr->{genbankDbRlsId};
   my $gb_db_rel_id = $mgr->{genbankDbRlsId};
   $args .= " --query_db_rel_id $gb_db_rel_id";
 }
  
 $mgr->runPlugin("Load${species}${queryName}BLATAlignments", 
            "GUS::Community::Plugin::LoadBLATAlignments",
            $args, "loading genomic alignments of ${species}${queryName} vs $targetName");

    $mgr->runCmd("rm -rf $qDir") if -d $qDir;
}
sub clusterByContigAlign {
    my ($mgr, $species, $name, $extDbName, $extDbRlsVer) = @_;
    my $propertySet = $mgr->{propertySet};

    my $pipelineDir = $mgr->{'pipelineDir'};
    #my $taxonId = $mgr->{taxonId};
    
    my $taxonId = $mgr->{taxonHsh}->{$species};
 
    $mgr->{contigDbRlsId} =  &getDbRlsId($mgr,$extDbName,$extDbRlsVer) unless $mgr->{contigDbRlsId};
    my $extDbRelId = $mgr->{contigDbRlsId};

    my $extDbNameGB = $propertySet->getProp('genbankDbName');
    my $extDbRlsVerGB = $propertySet->getProp('genbankDbRlsVer');
    $mgr->{genbankDbRlsId} =  &getDbRlsId($mgr,$extDbNameGB,$extDbRlsVerGB) unless $mgr->{genbankDbRlsId};
    my $gb_db_rel_id = $mgr->{genbankDbRlsId};

    my $outputFile = "$pipelineDir/cluster/$species$name/cluster.out";
    my $logFile = "$pipelineDir/logs/${name}Cluster.log";

    my $args = "--stage $name --taxon_id $taxonId --query_db_rel_id $gb_db_rel_id --target_table_name ExternalNASequence "
	. "--target_db_rel_id $extDbRelId --out $outputFile --sort 1";
    # $args .= " --test_chr 5";

    $mgr->runPlugin("Cluster${species}${name}ByContig", 
		    "DoTS::DotsBuild::Plugin::ClusterByGenome",
		    $args, "$name clustering by contig alignment");

}

sub createSageTagNormFiles {
  my ($mgr,$name,$paramValue) = @_;
  my $propertySet = $mgr->{propertySet};

  my $fileDir = "$mgr->{pipelineDir}/sage";

  my $signal = "Create_${name}_NormFiles";

  $signal =~ s/\s/_/g;

  my $contact = $propertySet->getProp('contact');

  my $args = "--paramValue $paramValue --studyName '$name' --fileDir $fileDir --contact $contact";

  $mgr->runPlugin($signal,
                  "ApiCommonData::Load::Plugin::CreateSageTagNormalizationFiles",
                  $args,"Creating files for $name");
}

sub createSignalPDir {
  my ($mgr) = @_;

  my $propertySet = $mgr->{propertySet};

  my $signal = "createSignalPDir";

  return if $mgr->startStep("Creating SignalP dir", $signal);

  my $signalpDir = "$mgr->{'pipelineDir'}/signalp";

  $mgr->runCmd("mkdir $signalpDir");

  $mgr->endStep($signal);
}

sub documentSignalP {
  my ($mgr, $options) = @_;

  my $documentation =
    { name => "SignalP",
      input => "Protein sequences",
      output => "Signal peptide predictions",
      descrip => "SignalP is used to identify signal peptides and their likely cleavage sites.",
      tools => [
		{ name => "SignalP",
		  version => "3.0",
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

  my $logFile = "$mgr->{pipelineDir}/logs/${species}SignalP.log";

  my $inFilePath = "$mgr->{pipelineDir}/seqfiles/${species}AnnotatedProteins.fsa";

  my $outFilePath = "$mgr->{pipelineDir}/signalp/${species}SignalP.out";
  
  my $binPath = $propertySet->getProp('signalP.path');
  
  my $cmd = "runSignalP --binPath $binPath  --options '$options' --seqFile $inFilePath --outFile $outFilePath 2>>$logFile"; 

  $mgr->runCmd($cmd);

  $mgr->endStep($signal);
}

sub loadSignalPData{
  my ($mgr, $species,$extDbName,$extDbRlsVer) = @_;
  my $propertySet = $mgr->{propertySet};

  my $resultFile = "$mgr->{pipelineDir}/signalp/${species}SignalP.out";

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

  my $tmhmmDir = "$mgr->{'pipelineDir'}/tmhmm";

  $mgr->runCmd("mkdir $tmhmmDir");

  $mgr->endStep($signal);
}

sub documentTMHMM {
  my ($mgr) = @_; 

  my $documentation =
    { name => "Predict transmembrane domains",
      input => "Protein sequences",
      output => "Predicted transmembrane domain topology",
      descrip => "TMHMM is used to predict transmembrane domain presence and topology",
      tools => [
		{ name => "tmhmm",
		  version => "2.0a",
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

  my $seqFile = "$mgr->{pipelineDir}/seqfiles/${species}AnnotatedProteins.fsa";

  my $outFile = "$mgr->{'pipelineDir'}/tmhmm/${species}Tmhmm.out";

  my $cmd = "runTMHMM -binPath $binPath -short  -seqFile $seqFile -outFile $outFile 2>> $mgr->{pipelineDir}/logs/${species}Tmhmm.log";

  $mgr->runCmd($cmd);

  $mgr->endStep($signal);
}


sub loadTMHmmData{
  my ($mgr, $species,$extDbName,$extDbRlsVer) = @_;
  my $propertySet = $mgr->{propertySet};

  my $resultFile = "$mgr->{pipelineDir}/tmhmm/${species}Tmhmm.out";

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

  my $fileDir = "$mgr->{pipelineDir}/sage/$name";

  opendir (DIR,$fileDir);

  my @files = grep { /\w*\.dat/ && -f "${fileDir}/$_" } readdir(DIR);

  foreach my $file (@files) {

    my $cfg = $file;

    $cfg =~ s/\.dat/\.cfg/;

    my $args = "--cfg_file $fileDir/$cfg --data_file $fileDir/$file --subclass_view RAD::DataTransformationResult";

    $mgr->runPlugin("${file}Inserted",
		    "GUS::Supported::Plugin::InsertRadAnalysis",
		    $args,"Inserting $file for $name");
  }

  $mgr->endStep($signal);
}

sub copyFilesToComputeCluster {
  my ($mgr,$file,$dir) = @_;
  my $propertySet = $mgr->{propertySet};

  my $serverPath = $propertySet->getProp('serverPath');
  my $clusterServer = $propertySet->getProp('clusterServer');

  my $signal = "${file}ToCluster";
  return if $mgr->startStep("Copying $file to $serverPath/$mgr->{buildName}/$file on $clusterServer", $signal);

  my $fileDir = "$mgr->{pipelineDir}/$dir";

  $mgr->{cluster}->copyTo($fileDir, $file, "$serverPath/$mgr->{buildName}/$dir");

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
	 "$mgr->{pipelineDir}/matrix/$matrix/master/mainresult/blastMatrix.out.gz");
  }
  my $matrixFiles = join(",", @matrixFileArray);

  my $ceflag = ($consistentEnds eq "yes")? "--consistentEnds" : "";

  my $outputFile = "$mgr->{pipelineDir}/cluster/$species$name/cluster.out";
  my $logFile = "$mgr->{pipelineDir}/logs/$signal.log";

  my $cmd = "buildBlastClusters.pl --lengthCutoff $length --percentCutoff $percent --verbose --files '$matrixFiles' --logBase $logbase --iterateCliqueSizeArray $cliqueSzArray $ceflag --iterateLogBaseArray $logbaseArray --sort > $outputFile 2>> $logFile";

  $mgr->runCmd($cmd);

  $mgr->endStep($signal);
}


sub splitCluster {
  my ($mgr, $species, $name) = @_;
  my $propertySet = $mgr->{propertySet};

  my $signal = "${species}${name}SplitCluster";

  return if $mgr->startStep("SplitCluster $name", $signal);

  my $clusterFile = "$mgr->{pipelineDir}/cluster/$species$name/cluster.out";
  my $splitCmd = "splitClusterFile $clusterFile";

  $mgr->runCmd($splitCmd);
  $mgr->endStep($signal);
}

sub assembleTranscripts {
  my ($mgr, $species, $old, $reassemble, $name) = @_;
  my $propertySet = $mgr->{propertySet};

  my $signal = "${species}${name}Assemble";

  return if $mgr->startStep("Assemble $name", $signal);

  my $clusterFile = "$mgr->{pipelineDir}/cluster/$species$name/cluster.out";

  &runAssemblePlugin($clusterFile, "big", $species, $name, $old, $reassemble, $mgr);
  &runAssemblePlugin($clusterFile, "small", $species, $name, $old, $reassemble, $mgr);
  $mgr->endStep($signal);
  my $msg =
    "EXITING.... PLEASE DO THE FOLLOWING:
 1. check for errors in assemble.err and sql failures in updateDOTSAssemblies.log
 2. resume when assembly completes (validly) by re-runnning '" . basename $0 . " $mgr->{propertiesFile}'
";
  print STDERR $msg;
  print $msg;
  $mgr->goodbye($msg);
}

sub reassembleTranscripts {
  my ($mgr, $species, $name) = @_;
  my $propertySet = $mgr->{propertySet};

  my $signal = "${species}${name}Reassemble";

  return if $mgr->startStep("Reassemble ${species}${name}", $signal);

  my $taxonId = $mgr->{taxonHsh}->{$species};

  my $sql = "select na_sequence_id from dots.assembly where taxon_id = $taxonId  and (assembly_consistency < 90 or length < 50 or length is null or description = 'ERROR: Needs to be reassembled')";

  print $sql . "\n"; # DEBUG
  my $clusterFile = "$mgr->{pipelineDir}/cluster/$species$name/cluster.out";

  my $suffix = "reassemble";

  my $old = "";

  my $reassemble = "yes";

  my $cmd = "makeClusterFile --idSQL \"$sql\" --clusterFile $clusterFile.$suffix";

  $mgr->runCmd($cmd);

  &runAssemblePlugin($clusterFile, $suffix, $species, $name, $old, $reassemble, $mgr);

  $mgr->endStep($signal);
  my $msg =
    "EXITING.... PLEASE DO THE FOLLOWING:
 1. resume when reassembly completes (validly) by re-runnning '" . basename $0 . " $mgr->{propertiesFile}'
";
  print STDERR $msg;
  print $msg;
  $mgr->goodbye($msg);
}

sub runAssemblePlugin {
  my ($file, $suffix, $species, $name, $assembleOld, $reassemble, $mgr) = @_;
  my $propertySet = $mgr->{propertySet};

  my $taxonId = $mgr->{taxonHsh}->{$species};
  my $cap4Dir = $propertySet->getProp('cap4Dir');
  my $reass = $reassemble eq "yes"? "--reassemble" : "";
  my $args = "--clusterfile $file.$suffix $assembleOld $reass --taxon_id $taxonId --cap4Dir $cap4Dir";
  my $pluginCmd = "ga DoTS::DotsBuild::Plugin::UpdateDotsAssembliesWithCap4 --commit $args --comment '$args'";

  print "running $pluginCmd\n";
  my $logfile = "$mgr->{pipelineDir}/logs/${species}${name}Assemble.$suffix.log";

  my $assemDir = "$mgr->{pipelineDir}/assembly/$species$name/$suffix";
  $mgr->runCmd("mkdir -p $assemDir");
  chdir $assemDir || die "Can't chdir to $assemDir";

  my $cmd = "runUpdateAssembliesPlugin --clusterFie $file.$suffix --pluginCmd \"$pluginCmd\" 2>> $logfile";
  $mgr->runCmdInBackground($cmd);
}

sub deleteAssembliesWithNoTranscripts {
  my ($mgr, $species, $name) = @_;

  my $taxonId =  $mgr->{taxonHsh}->{$species};

  my $args = "--taxon_id $taxonId";

  $mgr->runPlugin("${species}${name}deleteAssembliesWithNoAssSeq", 
		  "DoTS::DotsBuild::Plugin::DeleteAssembliesWithNoAssemblySequences",
		  $args, "Deleting assemblies with no assemblysequences");
}


sub startTranscriptMatrixOnComputeCluster {
  my ($mgr, $species, $name) = @_;
  my $propertySet = $mgr->{propertySet};

  my $serverPath = $propertySet->getProp('serverPath');

  my $signal = "${species}${name}TranscriptMatrix";
  return if $mgr->startStep("Starting ${species}${name}Transcript matrix", $signal);

  $mgr->endStep($signal);

  my $cmd = "run" . ucfirst($signal);

  my $cmdMsg = "submitPipelineJob $cmd $serverPath/$mgr->{buildName} NUMBER_OF_NODES";
  my $logMsg = "monitor $serverPath/$mgr->{buildName}/logs/*.log and xxxxx.xxxx.stdout";

  print $cmdMsg . "\n" . $logMsg . "\n";

  $mgr->exitToCluster($cmdMsg, $logMsg, 0);
}


sub copyFilesFromComputeCluster {
  my ($mgr,$name,$dir) = @_;
  my $propertySet = $mgr->{propertySet};

  my $serverPath = $propertySet->getProp('serverPath');
  my $clusterServer = $propertySet->getProp('clusterServer');

  my $signal = "copy${name}ResultsFromCluster";
  return if $mgr->startStep("Copying $name results from $clusterServer",
			    $signal);

  $mgr->{cluster}->copyFrom(
		       "$serverPath/$mgr->{buildName}/$dir/$name/",
		       "master",
		       "$mgr->{pipelineDir}/$dir/$name");
  $mgr->endStep($signal);
}

sub usage {
  my $prog = `basename $0`;
  chomp $prog;
  print STDERR "usage: $prog propertiesfile [-printXML]\n";
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

sub getTaxonIdList {
  my ($mgr,$taxonId) = @_;
  my $propertySet = $mgr->{propertySet};
  my $returnValue;

  if ($propertySet->getProp('includeSubspecies') eq "yes") {
    $returnValue = $mgr->runCmd("getSubTaxa --taxon_id $taxonId");
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
  my $seqfilesDir = "$mgr->{pipelineDir}/seqfiles/";
  my $outfilesDir = "$mgr->{pipelineDir}/analysis/";
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
  my $outfilesDir = "$mgr->{pipelineDir}/analysis/";
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

  my $projectRelease = $propertySet->getProp('projectRelease');

  my $signal = "${lastName}UserProjectGroup";

  return if $mgr->startStep("Inserting userinfo,groupinfo,projectinfo for $lastName gus config file", $signal);

  $mgr->runCmd ("insertUserProjectGroup --firstName $firstName --lastName $lastName --projectRelease $projectRelease --commit");

  $mgr->endStep($signal);
}


# $seqFile from earlier extractNaSeq() step, outputs gff file to sseqfiles
sub makeOrfFile {
  my ($mgr, $seqFile, $minPepLength) = @_;
  my $propertySet = $mgr->{propertySet};

  my $outFile = $seqFile;
  $outFile =~ s/\.\w+\b//;
  $outFile = "${outFile}_orf${minPepLength}.gff";
  $outFile = "$mgr->{pipelineDir}/seqfiles/$outFile";
  
  my $signal = "makeOrfFileFrom_${seqFile}";
  return if $mgr->startStep("makeOrfFile from $seqFile", $signal);

  my $cmd = <<"EOF";
orfFinder --dataset seqfiles/$seqFile \\
--minPepLength $minPepLength \\
--outFile $outFile
EOF

  $mgr->runCmd($cmd);
  $mgr->endStep($signal);
    
}

sub loadOrfFile {
    my ($mgr, $orfFile, $extDbName, $extDbRlsVer, $mapFile, $soCvsVersion) = @_;
    
    my $signal = "load_$orfFile";
    
    my $args = <<"EOF";
--extDbName '$extDbName'  \\
--extDbRlsVer '$extDbRlsVer' \\
--mapFile $mapFile \\
--inputFileOrDir $mgr->{pipelineDir}/seqfiles/$orfFile \\
--fileFormat gff3   \\
--seqSoTerm ORF  \\
--soCvsVersion $soCvsVersion \\
--naSequenceSubclass ExternalNASequence \\
EOF

    $mgr->runPlugin(
        $signal, 
        "GUS::Supported::Plugin::InsertSequenceFeatures", 
        $args, 
        "Loading $orfFile output");

}


1;
