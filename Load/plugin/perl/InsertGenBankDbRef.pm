#############################################################################
#vvvvvvvvvvvvvvvvvvvvvvvvv GUS4_STATUS vvvvvvvvvvvvvvvvvvvvvvvvv
  # GUS4_STATUS | SRes.OntologyTerm              | auto   | absent
  # GUS4_STATUS | SRes.SequenceOntology          | auto   | absent
  # GUS4_STATUS | Study.OntologyEntry            | auto   | absent
  # GUS4_STATUS | SRes.GOTerm                    | auto   | absent
  # GUS4_STATUS | Dots.RNAFeatureExon            | auto   | absent
  # GUS4_STATUS | RAD.SageTag                    | auto   | absent
  # GUS4_STATUS | RAD.Analysis                   | auto   | absent
  # GUS4_STATUS | ApiDB.Profile                  | auto   | absent
  # GUS4_STATUS | Study.Study                    | auto   | absent
  # GUS4_STATUS | Dots.Isolate                   | auto   | absent
  # GUS4_STATUS | DeprecatedTables               | auto   | absent
  # GUS4_STATUS | Pathway                        | auto   | absent
  # GUS4_STATUS | DoTS.SequenceVariation         | auto   | absent
  # GUS4_STATUS | RNASeq Junctions               | auto   | absent
  # GUS4_STATUS | Simple Rename                  | auto   | absent
  # GUS4_STATUS | ApiDB Tuning Gene              | auto   | absent
  # GUS4_STATUS | Rethink                        | auto   | absent
  # GUS4_STATUS | dots.gene                      | manual | unreviewed
die 'This file has broken or unreviewed GUS4_STATUS rules.  Please remove this line when all are fixed or absent';
#^^^^^^^^^^^^^^^^^^^^^^^^^ End GUS4_STATUS ^^^^^^^^^^^^^^^^^^^^
##                    InsertGenBankDbRef.pm
##
## Plugin to insert associations between GenBank and AA or NA sequences
## from a file into SRes.DBRef, and either DoTS.AASequenceDBRef or
## DoTS.DBRefNASequence
##
## $Id$
##
## created August 10, 2005  by Jennifer Dommer
#############################################################################

package ApiCommonData::Load::Plugin::InsertGenBankDbRef;
@ISA = qw(GUS::PluginMgr::Plugin);


use strict;

use GUS::PluginMgr::Plugin;
use GUS::Model::SRes::DbRef;
use GUS::Model::DoTS::DbRefNASequence;
use GUS::Model::DoTS::AASequenceDbRef;
use GUS::Model::DoTS::NASequence;
use GUS::Model::DoTS::AASequence;
use GUS::Supported::Util;

my $purposeBrief = <<PURPOSEBRIEF;
Plugin to insert associations between GenBank and AA or NA sequences from a tab delimited file.
PURPOSEBRIEF

my $purpose = <<PLUGIN_PURPOSE;
Plugin to insert associations between GenBank and AA or NA sequences from a file into SRes.DBRef, and either DoTS.AASequenceDBRef or DoTS.DBRefNASequence.  The file should be tab delimited in the form:  sequence_source_id   database_id.
PLUGIN_PURPOSE

my $tablesAffected = [["SRes.DbRef", "The database IDs that are referenced by the associations will go here."], ["DoTS.DbRefNASequence", "The associations will go here if the plugin is using NA sequences."], ["DoTS.AASequenceDbRef", "The associations will go here if the plugin is using AA sequences."]];


my $tablesDependedOn = [["DoTS.NASequence", "If using NA Sequences, the sequence must exist here."], ["DoTS.AASequence", "If using AA Sequences, the sequence must exist here."]];

my $howToRestart = <<PLUGIN_RESTART;
Simply reexecute the plugin.
PLUGIN_RESTART

my $failureCases = <<PLUGIN_FAILURE_CASES;
None known.
PLUGIN_FAILURE_CASES

my $notes = <<PLUGIN_NOTES;

PLUGIN_NOTES

my $documentation = { purpose=>$purpose,
		      purposeBrief=>$purposeBrief,
		      tablesAffected=>$tablesAffected,
		      tablesDependedOn=>$tablesDependedOn,
		      howToRestart=>$howToRestart,
		      failureCases=>$failureCases,
		      notes=>$notes
		    };
my $argsDeclaration = 
  [
   fileArg({name => 'inputFile',
	    descr => 'tab-delimited GenBank association data',
	    reqd => 1,
	    mustExist => 1,
	    format => 'tab-delimited of the form: sequence_identifier   Database_identifier',
	    constraintFunc => undef,
	    isList => 0,
	   }),

   enumArg({name => 'seqType',
	    descr => 'what type of sequences we creating associations for',
	    constraintFunc => undef,
	    reqd => 1,
	    isList => 0,
	    enum => 'NASequence, AASequence'
	   }),

   stringArg({name => 'dbRefExternalDatabaseSpec',
	      descr => 'External database release to tag the new dbRefs with (in "name|version" format)',
	      constraintFunc => undef,
	      reqd => 1,
	      isList => 0
	     })
  ];

sub new {
    my ($class) = @_;
    my $self = {};
    bless($self,$class);

    $self->initialize({requiredDbVersion => 3.6,
		       cvsRevision => '$Revision$', # cvs fills this in!
		       name => ref($self),
		       argsDeclaration => $argsDeclaration,
		       documentation => $documentation
		      });

    return $self;
}


sub run {
  my ($self) = @_;
  my $type = $self->getArg('seqType');
  my $count = 0;
  my %fileHash;

  $self->processFile(\%fileHash);

  if ($type eq 'NASequence'){
    $count = $self->createDbRefNASequence(\%fileHash);
  }elsif($type eq 'AASequence'){
    $count = $self->createAASequenceDbRef(\%fileHash);
  }

  my $msg = "Added $count new $type associations";
  return $msg;
}

sub processFile {
  my ($self, $fileHash) = @_;
  my $fileName = $self->getArg('inputFile');
  my %dbRefsSeen;

  open(FILE, $fileName);
  while(<FILE>){
    chomp;

    my ($sequence, $dbRef) = split (/\t/, $_);

    my $dbRefId = $dbRefsSeen{$dbRef};
    unless($dbRefId){
      $dbRefId = $self->createDbRef($dbRef);
      $dbRefsSeen{$dbRef} = $dbRefId;
    }
    push(@{$$fileHash{$dbRefId}}, [$sequence]);
  }
  close(FILE);
}


sub createDbRef{
  my ($self, $dbRef) = @_;
  my $extDbRlsId = $self->getExtDbRlsId($self->getArg('dbRefExternalDatabaseSpec'));

  my $newDbRef = GUS::Model::SRes::DbRef->new({
	'primary_identifier' => $dbRef,
	'external_database_release_id' => $extDbRlsId
	});
#check for existence in db, if not exists submit before getting Id
  unless($newDbRef->retrieveFromDB()){
    $newDbRef->submit();
  }
  my $dbRefId = $newDbRef->getId();

  $self->undefPointerCache();

  return $dbRefId;
}


sub createDbRefNASequence{
  my ($self, $fileHash) = @_;
  my $count;

  foreach my $dbRef (keys %{$fileHash}){
    foreach my $sourceIdList (@{$$fileHash{$dbRef}}){
      foreach my $sourceId (@{$sourceIdList}){

	my @naSeqIds;
	$self->getNASeqId($sourceId, \@naSeqIds);

	my $length = scalar(@naSeqIds);
	if ($length == 0){
	  $self->log("The source_id $sourceId could not be found");
	  next;
	}

	foreach my $naSeqId (@naSeqIds){

	  my $newDbRefNASeq = GUS::Model::DoTS::DbRefNASequence->new({
		'db_ref_id' => $dbRef,
		'na_sequence_id' => $naSeqId
	        });

	  unless($newDbRefNASeq->retrieveFromDB()){
	    $newDbRefNASeq->submit();

	    $count++;
	    if($count % 100 == 0) {
	      $self->log("$count DbRef-NASequence associations submitted");
	    }
	  }
	      $self->undefPointerCache();

	}
      }
    }
  }

return $count;
}

sub createAASequenceDbRef{
  my ($self, $fileHash) = @_;
  my $count;

    foreach my $dbRef (keys %{$fileHash}){
    foreach my $sourceIdList (@{$$fileHash{$dbRef}}){
      foreach my $sourceId (@{$sourceIdList}){

	my $aaSeqId = 
	  GUS::Supported::Util::getAASeqIdFromGeneId($self, $sourceId);

	if (!$aaSeqId){
	  $self->log("The source_id $sourceId could not be found");
	  next;
	}

	my $newAASeqDbRef = GUS::Model::DoTS::AASequenceDbRef->new({
		'db_ref_id' => $dbRef,
		'aa_sequence_id' => $aaSeqId
	        });

	unless($newAASeqDbRef->retrieveFromDB()){
	  $newAASeqDbRef->submit();

	  $count++;
	  if($count % 100 == 0) {
	    $self->log("$count AASequence-DbRef associations submitted");
	  }
	}
	    $self->undefPointerCache();

      }
    }
  }

return $count;
}


sub getNASeqId{
  my ($self, $locusTag, $naSeqIds) = @_;

my $sql = <<EOSQL;
SELECT distinct subclass_view
      FROM dots.NASequence
EOSQL

  my $queryHandle = $self->getQueryHandle();
  my $sth = $queryHandle->prepareAndExecute($sql);

  while(my $table = $sth->fetchrow_array()){

$sql = <<EOSQL;
SELECT distinct na_sequence_id
      FROM dots.$table
      WHERE source_id = '$locusTag'
EOSQL

    my $st = $queryHandle->prepareAndExecute($sql);

    while(my $naSeqId = $st->fetchrow_array()){
      push(@{$naSeqIds}, $naSeqId);
    }

    $st->finish();
  }

  $sth->finish();
}


sub getAASeqId {
  my ($self, $locusTag) = @_;

  my $aaSeq = GUS::Model::DoTS::AASequence->new({
		'source_id' => $locusTag
	        });

  $aaSeq->retrieveFromDB();
  my $aaSeqId = $aaSeq->getId();

  return $aaSeqId;

}

sub undoTables {
  my ($self) = @_;

  return ('DoTS.DbRefNAFeature',
	  'DoTS.DbRefAAFeature',
	  'DoTS.DbRefNASequence',
	  'DoTS.AASequenceDbRef',
          'SRes.DbRef',
	 );
}


1;
