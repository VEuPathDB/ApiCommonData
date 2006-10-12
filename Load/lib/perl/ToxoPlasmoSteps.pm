use lib "$ENV{GUS_HOME}/lib/perl";

use GUS::Pipeline::NfsCluster;
use GUS::Pipeline::SshCluster;
use CBIL::Util::PropertySet;
use GUS::Pipeline::Manager;

use strict;

sub initPlasmoAnalysis {
  my ($propertyFile, $printXML, $pipelineName) = @_;

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

  my $allSpecies = 'Pfalciparum,Pyoelii,Pvivax,Pberghei,Pchabaudi';

  my ($mgr, $buildDir, $release)
    = &initToxoPlasmoAnalysis(\@plasmoProps, $propertyFile, $printXML,
			      $allSpecies);

  my $taxId = ["Pfalciparum:36329","PfalciparumPlastid:36329","PfalciparumMito:36329","Pyoelii:352914","Pvivax:126793","Pberghei:5821","Pchabaudi:5825"];

  my $taxonHsh = &getTaxonIdFromTaxId($mgr,$taxId);

  $mgr->{taxonHsh} = $taxonHsh;

  return ($mgr, $buildDir, $release, $allSpecies);
}


sub initToxoPlasmoAnalysis {
  my ($projProps, $propertiesFile, $printXML, $allSpecies) = @_;

  $| = 1;
  umask 002;

  &usage unless -e $propertiesFile;
  &usage if ($printXML && $printXML ne "-printXML");

  # [name, default (or null if reqd), comment]
  my @properties = 
    (
     # universal analysis pipeline properties
     ["buildDir",   "",  "root of the build's directory tree"],
     ["clusterServer", "",  "full name of cluster server"],
     ["gusConfigFile",  "",  "gus configuration file"],
     ["nodePath",             "",  "full path of scratch dir on cluster node"],
     ["nodeClass", "","cluster management protocol"],
     ["externalDbDir", "", "fill in"],
     ["serverPath", "",  "full path of update dir on cluster server"],
     ["stopBefore",   "none",  "the step to stop before.  uses the signal name"],
     ["commit", "", "fill in"],
     ["testNextPlugin", "", "fill in"],
     ["projectName", "", " project name from projectinfo.name"],
     @$projProps
    );

  my $propertySet  = CBIL::Util::PropertySet->new($propertiesFile, \@properties, 1);
  my $myPipelineName = $propertySet->getProp('myPipelineName');
  my $buildDir = $propertySet->getProp('buildDir');
  my $release = $propertySet->getProp('projectRelease');
  my $dataDir = "$buildDir/$release/analysis_pipeline/primary/data";
  my $buildName = "$release/analysis_pipeline/$myPipelineName";
  my $pipelineDir = "$buildDir/$buildName";

print STDERR "pd: $pipelineDir\n";

  my $cluster;
  if ($propertySet->getProp('clusterServer') ne "none") {
    $cluster = GUS::Pipeline::SshCluster->new($propertySet->getProp('clusterServer'),
					      $propertySet->getProp('clusterUser') );
  } else {
    $cluster = GUS::Pipeline::NfsCluster->new();
  }

  my $mgr = GUS::Pipeline::Manager->new($pipelineDir, $propertySet,
					$propertiesFile, $cluster,
					$propertySet->getProp('testNextPlugin'),
					$printXML);

  $mgr->addCleanupCommand("updateMaterializedView --mview GeneAlias --owner apidb");

  $mgr->addCleanupCommand("updateMaterializedView --mview SequenceAlias --owner apidb");

  $mgr->{buildName} = $buildName;

  $mgr->{dataDir} = $dataDir;

  $mgr->{propertiesFile} = $propertiesFile;

  &createPipelineDir($mgr,$allSpecies);

  &makeUserProjectGroup($mgr);

#  &copyPipelineDirToComputeCluster($mgr);

  return ($mgr, $buildDir, $release);
}

1;
