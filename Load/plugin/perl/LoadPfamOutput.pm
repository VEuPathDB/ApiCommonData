package ApiCommonData::Load::Plugin::LoadPfamOutput;
@ISA = qw(GUS::PluginMgr::Plugin);

#######################################
#       LoadPfamOutput.pm
#
# Written for Pfam and HMMer
# Ed Robinson, May, 2005
# Updated by Aaron Mackey, November 2005
#######################################

use strict;
use warnings;

use GUS::PluginMgr::Plugin;

use GUS::Model::Core::Algorithm;
use GUS::Model::DoTS::DomainFeature;
use GUS::Model::DoTS::PfamEntry;
use GUS::Model::DoTS::AALocation;

use Bio::SearchIO;

# ----------------------------------------------------------
# Load Arguments
# ----------------------------------------------------------

sub getArgsDeclaration {
  my $argsDeclaration  =
    [
     fileArg({ name => 'data_file',
	       descr => 'text file containing external sequence annotation data',
	       constraintFunc=> undef,
	       reqd  => 1,
	       isList => 0,
	       mustExist => 1,
	       format=>'Text'
	     }),

     fileArg({ name => 'restart_file',
	       descr => 'log file containing/for storing entries from last run/this run',
	       constraintFunc=> undef,
	       reqd  => 0,
	       mustExist => 0,
	       isList => 0,
	       format=>'Text'
	     }),

     stringArg({ name => 'algName',
		 descr => 'Name of algorithm used For predictions',
		 constraintFunc=> undef,
		 reqd  => 1,
		 isList => 0
	       }),

     stringArg({ name => 'algVer',
		 descr => 'Version of algorithm used For predictions',
		 constraintFunc=> undef,
		 reqd  => 1,
		 isList => 0
	       }),

     stringArg({ name => 'algDesc',
		 descr => 'Detailed description of use',
		 constraintFunc=> undef,
		 reqd  => 1,
		 isList => 0
	       }),

     stringArg({ name => 'queryTable',
		 descr => 'Table source of AA sequences used in Pfam search',
		 constraintFunc => undef,
		 reqd  => 1,
		 isList => 0,
	       }),

     stringArg({ name => 'extDbRlsName',
		 descr => 'External database from whence the data file you are loading came (original source of data)',
		 constraintFunc=> undef,
		 reqd  => 0,
		 isList => 0
	       }),

     stringArg({ name => 'extDbRlsVer',
		 descr => 'Version of external database from whence the data file you are loading came (original source of data)',
		 constraintFunc=> undef,
		 reqd  => 0,
		 isList => 0
	       }),
    ];

  return $argsDeclaration;
}


# ----------------------------------------------------------
# Documentation
# ----------------------------------------------------------

sub getDocumentation {

  my $description = <<DESCR;
Application to load text files of hmmpfam output run against fasta
files of GUS AA sequences; uses BioPerl HMMER parser
DESCR

  my $purpose = <<PURPOSE;
Load Pfam analysis into GUS.
PURPOSE

  my $purposeBrief = <<PURPOSEBRIEF;
Load Pfam analysis.
PURPOSEBRIEF

  my $notes = <<NOTES;
None.
NOTES

  my $tablesAffected = <<AFFECT;
DoTS.DomainFeature, DoTS.AALocation
AFFECT

  my $tablesDependedOn = <<TABD;
DoTS.AASequenceImp (various views), DoTS.PfamEntry
TABD

  my $howToRestart = <<RESTART;
Make sure to use the argument restart_file and to correctly point to
the correct file output by the last run.
RESTART

  my $failureCases = <<FAIL;
It will dump processed ids to log if there is a failure at the point
of submiting the analysis data into GUS.
FAIL

  my $documentation = { purpose          => $purpose,
			purposeBrief     => $purposeBrief,
			tablesAffected   => $tablesAffected,
			tablesDependedOn => $tablesDependedOn,
			howToRestart     => $howToRestart,
			failureCases     => $failureCases,
			notes            => $notes
		      };

  return ($documentation);

}


sub new {
  my $class = shift;
  my $self = {};
  bless($self, $class);

  my $documentation = &getDocumentation();

  my $args = &getArgsDeclaration();

  my $configuration = { requiredDbVersion => 3.5,
			cvsRevision => '$Revision$',
			name => ref($self),
			argsDeclaration => $args,
			documentation => $documentation
		      };

  $self->initialize($configuration);

  return $self;
}


##############################################################
#Cache Objects
##############################################################
sub setContext{
  my $self = shift;

  my $seqCache = loadSeqLog();
  $self->log("Lines in seq cache: $seqCache \n");
}


sub loadSeqLog {
  my $self = shift;

  my $lnsCach = 0;
  open(MYLOG, "<@{[$self->getArg('restart_file')]}");
  while (my $entry = <MYLOG>)   {
    $self->{'seqs'}->{$entry} = {'1'};
    $lnsCach++;
  }

  return $lnsCach;
}

###############################################################
#Main Routine
##############################################################

sub run {
  my $self = shift;

  my $io = Bio::SearchIO->new(-file => $self->getArg('data_file'),
			      -format => "hmmer");

  my $seqsProc = 0;
  while (my $result = $io->next_result()) {

    my $seqid = $self->_lookupSeqId($result->query_name());

    while (my $hit = $result->next_hit()) {

      my $model  = $hit->name();
      my $desc   = $hit->description();

      my $score  = $hit->score();
      my $evalue = $hit->significance();
      my $start  = $hit->start("query");
      my $stop   = $hit->end("query");

      my $n = $hit->num_hsps();

      my $hitFeature = $self->buildGusFeature($seqid, $model, $score, $evalue, $n);
      my $hitLocation = $self->buildGusLocation($start, $stop);
      $hitFeature->addChild($hitLocation);

      my $i = 1;
      while (my $hsp = $hit->next_hsp()) {
	my $domainScore  = $hsp->score();
	my $domainEvalue = $hsp->significance();
	my $domainStart  = $hsp->start("query");
	my $domainStop   = $hsp->end("query");

	my $hspFeature = $self->buildGusFeature($seqid, $model, $domainScore, $domainEvalue, 1);
	my $hspLocation = $self->buildGusLocation($domainStart, $domainStop);
	$hspFeature->addChild($hspLocation);

	$hitFeature->addChild($hspFeature);
	$i++;
      }

      $hitFeature->submit();
    }
    $seqsProc++;
    $self->undefPointerCache();
  }

  $self->log("LoadPfamOutput Run Complete!\nSeqs Loaded: $seqsProc");
}

sub _lookupSeqId {
  my ($self, $source_id) = @_;

  my $extDbRlsId = $self->{_extDbRlsId} ||= $self->getExtDbRlsId($self->getArg('extDbRlsName'),
								 $self->getArg('extDbRlsVer'));

  my $sth = $self->{_getSeqIdBySourceId} ||= $self->getQueryHandle()->prepare(<<EOSQL);
  SELECT aa_sequence_id
  FROM   @{[$self->getArg('queryTable')]}
  WHERE  source_id = ?
EOSQL

  $sth->execute($source_id);

  my ($seqId) = $sth->fetchrow_array();

  unless ($seqId) {
    $self->error("Couldn't find sequence in @{[$self->getArg('queryTable')]} for: $source_id\n");
  }

  return $seqId;
}

#####################################################################
#Sub-routines
#####################################################################

# ----------------------------------------------------------
# Parse Data and Build GUS Object
# ----------------------------------------------------------

sub buildGusFeature {
  my ($self, $seqId, $model, $score, $evalue, $numDomains) = @_;

  my $pfamId = GUS::Model::DoTS::PfamEntry->new();
  $pfamId->setAccession($model);
  $pfamId->retrieveFromDB();
  my $gusId = $pfamId->getId();

  $self->error("Could not find PfamEntry for : $model\n")
    unless $gusId;

  my $gusFeature = GUS::Model::DoTS::DomainFeature->new();
  $gusFeature->setAaSequenceId($seqId);
  $gusFeature->setScore($score);
  $gusFeature->setEValue($evalue);
  $gusFeature->setPfamEntryId($gusId);
  $gusFeature->setNumberOfDomains($numDomains);
  $gusFeature->setIsPredicted(1);

  return $gusFeature;
}

sub buildGusLocation {
  my ($self, $start, $stop) = @_;

  my $gusLocation = GUS::Model::DoTS::AALocation->new();
  $gusLocation->setStartMax($start);
  $gusLocation->setStartMin($start);
  $gusLocation->setEndMax($stop);
  $gusLocation->setEndMin($stop);

  return $gusLocation;
}

sub undoTables {
  return qw(DoTS.AALocation
	    DoTS.DomainFeature
	   );
}

# ----------------------------------------------------------
# Build an algorithm entry for this data set. 
# ----------------------------------------------------------

sub getSetAlgorithm {
  my ($algName, $algDesc) = @_;

  my $algEntry = GUS::Model::Core::Algorithm->new({'name' => $algName, 'description' => $algDesc});
  unless ($algEntry->retrieveFromDB()) {
    $algEntry->submit();
  }
  my $algId = $algEntry->getId();

  return $algId;
}


# ----------------------------------------------------------
# make a checksum digest
# ----------------------------------------------------------
sub ckSumDgst {
  my ($self, $gusObj) = @_;
   #note, we need to implement overloading of \"\" at the plugin level so it can b
   #infact, the cksum digest should be a plugin callable fucntion
   #my $md5 = Digest::MD5->new;
   #foreach $item ($gusObj) {
   #    $md5->add($item);
   #    }
   #my $digest = $md5->b64digest;
  my $digest=$gusObj;

  return $digest;
}


# ----------------------------------------------------------
# Loaded last run?
# ----------------------------------------------------------
sub ckSumInCache {
  my ($self, $ckSum) = @_;

  my $qed=0;
  if ($self->{'seqs'}->{$ckSum} eq '1') {
    $qed = 1;
  }

  return $qed;
}


# ----------------------------------------------------------
# Dump your process log to file. 
# ----------------------------------------------------------
sub dumpLog {
  my ($self) = @_;

  open(MYLOG, ">$self->getArg('restart_file')");
  foreach my $item ($self->{'seqs'}) {
    print MYLOG "$item\n";
  }
}


# ----------------------------------------------------------
# Failure handler
# ----------------------------------------------------------
sub handleFailure {
  my ($self, $err, $seq) = @_;

  print "Failure Processing $seq \n\n";
  print $err;
  $self->dumpLog();
  exit;
}


return 1;
