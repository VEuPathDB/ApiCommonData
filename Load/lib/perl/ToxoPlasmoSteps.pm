use lib "$ENV{GUS_HOME}/lib/perl";

use GUS::Pipeline::NfsCluster;
use GUS::Pipeline::SshCluster;
use CBIL::Util::PropertySet;
use GUS::Pipeline::Manager;

use strict;

## NOTE: at the bottom of this file are the old "steps specific property
## declarations.  we intend to incorporate them into the steps that need them

sub initToxoAnalysis {
  my ($propertyFile, $optionalArgs) = @_;

  my $allSpecies = 'Tgondii';

  my $taxId = ["Tgondii:5811","TgondiiApicoplast:5811","TgondiiGT1:5811","TgondiiVeg:398031","TgondiiRH:383379"];

  my ($mgr, $projectDir, $release)
    = &initToxoPlasmoAnalysis($propertyFile, $optionalArgs,
			      $allSpecies, $taxId);

  return ($mgr, $projectDir, $release, $allSpecies);
}

sub initPlasmoAnalysis {
  my ($propertyFile, $optionalArgs) = @_;

  my $allSpecies = 'Pfalciparum,Pyoelii,Pvivax,Pberghei,Pchabaudi';

  my $taxId = ["Pfalciparum:36329","PfalciparumPlastid:36329","PfalciparumMito:36329","Pyoelii:352914","Pvivax:126793","Pberghei:5823","Pchabaudi:31271","Pknowlesi:5851"];

  my ($mgr, $projectDir, $release)
    = &initToxoPlasmoAnalysis($propertyFile, $optionalArgs,
			      $allSpecies, $taxId);

  return ($mgr, $projectDir, $release, $allSpecies);
}


sub initOrthomclAnalysis {
  my ($propertyFile, $optionalArgs) = @_;

  my $allSpecies = 'BAE_all';

  my $taxId = [];

  my ($mgr, $projectDir, $release)
    = &initToxoPlasmoAnalysis($propertyFile, $optionalArgs,
			      $allSpecies, $taxId);

  return ($mgr, $projectDir, $release, $allSpecies);
}

#####################################################################
# Internal subroutines
#####################################################################


sub initToxoPlasmoAnalysis {
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
					$optionalArgs->{printXml},
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

sub usage {
  my $prog = `basename $0`;
  chomp $prog;
  print STDERR "usage: $prog propertiesfile [-printXML -skipCleanup]\n";
  exit 1;
}



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
);

my @orthomclProps = 
(

);

1;
