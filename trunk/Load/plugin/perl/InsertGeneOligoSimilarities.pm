package ApiCommonData::Load::Plugin::InsertGeneOligoSimilarities;

@ISA = qw(GUS::PluginMgr::Plugin);

use strict;
use warnings;

use GUS::PluginMgr::Plugin;

use GUS::Model::DoTS::Similarity;

my $argsDeclaration =
  [
   fileArg({ name           => 'inputFile',
	     descr          => 'Tab file with first column oligo source id, second column gene source id',
	     reqd           => 1,
	     mustExist      => 1,
	     format         => '',
	     constraintFunc => undef,
	     isList         => 0,
	   }),

   stringArg({name => 'oligosExternalDatabase',
	      descr => 'External database for the oligos',
	      constraintFunc=> undef,
	      reqd  => 1,
	      isList => 0
	     }),

   stringArg({name => 'oligosExternalDatabaseRls',
	      descr => 'Version of external database for the oligos',
	      constraintFunc=> undef,
	      reqd  => 1,
	      isList => 0
	     }),

  ];

my $purpose = <<PURPOSE;
Insert an externally provided mapping between genes and oligo sequences.
(EG, for use in expression profile averaging.  Use the similarity table 
because that is the way such relations are usually formed)
PURPOSE

my $purposeBrief = <<PURPOSE_BRIEF;
Insert an externally provided mapping between genes and oligo sequences.
PURPOSE_BRIEF

my $notes = <<NOTES;
None.
NOTES

my $tablesAffected = <<TABLES_AFFECTED;
DoTS.Similarity
TABLES_AFFECTED

my $tablesDependedOn = <<TABLES_DEPENDED_ON;
None.
TABLES_DEPENDED_ON

my $howToRestart = <<RESTART;
Just reexecute the plugin; all existing domains of the specified
version will be removed.
RESTART

my $failureCases = <<FAIL_CASES;
FAIL_CASES

my $documentation =
  { purpose          => $purpose,
    purposeBrief     => $purposeBrief,
    notes            => $notes,
    tablesAffected   => $tablesAffected,
    tablesDependedOn => $tablesDependedOn,
    howToRestart     => $howToRestart,
    failureCases     => $failureCases
  };

sub new {
  my ($class) = @_;
  $class = ref $class || $class;

  my $self = bless({}, $class);

  $self->initialize({ requiredDbVersion => 3.5,
		      cvsRevision       => '$Revision: 11246 $',
		      name              => ref($self),
		      argsDeclaration   => $argsDeclaration,
		      documentation     => $documentation
		    });

  return $self;
}

sub run {
  my ($self) = @_;

  my $inputFile = $self->getArg('inputFile');
  open(FILE, "<$inputFile") or $self->error("Couldn't open '$inputFile': $!\n");
  # build map of oligo source id to oligo na_sequence_id

  $self->makeOligoIdMap();
  $self->makeTranscriptIdMap();
  my $extNaSeqTableId = $self->className2TableId('DoTS::ExternalNaSequence');
  my $transcriptTableId = $self->className2TableId('DoTS::Transcript');

  my $count = 0;
  while (<FILE>) {
    /^(\S+)\t(\S+)$/ || die "can't parse line '$_'\n";
    my $seqSourceId = $1;
    my $transcriptSourceId = $2."-1";
    my $seqId = $self->{sourceIdSeqIdMap}->{$seqSourceId};
    my $transcriptId = $self->{sourceIdFeatureIdMap}->{$transcriptSourceId};
    die "can't find na_sequence_id for '$seqSourceId'" unless $seqId;
    die "can't find na_feature_id for '$transcriptSourceId'" unless $transcriptId;
    my $similarity = GUS::Model::DoTS::Similarity->new();
    $similarity->setSubjectTableId($transcriptTableId);
    $similarity->setSubjectId($transcriptId);
    $similarity->setQueryTableId($extNaSeqTableId);
    $similarity->setQueryId($seqId);
    $similarity->setScore(0);
    $similarity->setPvalueExp(0);
    $similarity->setMinSubjectStart(0);
    $similarity->setMaxSubjectEnd(0);
    $similarity->setMinQueryStart(0);
    $similarity->setMaxQueryEnd(0);
    $similarity->setNumberOfMatches(0);
    $similarity->setTotalMatchLength(0);
    $similarity->setNumberIdentical(0);
    $similarity->setNumberPositive(0);
    $similarity->setIsReversed(0);
    $similarity->submit()
      || die "couldn't submit similarity between $transcriptSourceId and $seqSourceId";
    $count++;
  }

  return "Loaded $count Similarities";
}

sub makeOligoIdMap {
  my ($self) = @_;

  my $oligosDbRlsId = 
    $self->getExtDbRlsId($self->getArg('oligosExternalDatabase'),
			 $self->getArg('oligosExternalDatabaseRls'));

  my $sql = "
select source_id, na_sequence_id
from dots.externalnasequence
where external_database_release_id = $oligosDbRlsId
";

  my $stmt = $self->prepareAndExecute($sql);
    while ( my($sourceId, $na_sequence_id) = $stmt->fetchrow_array()) {
      $self->{sourceIdSeqIdMap}->{$sourceId} = $na_sequence_id;
    }
}

sub makeTranscriptIdMap {
  my ($self) = @_;

  my $sql = "
select source_id, na_feature_id
from dots.transcript
";

  my $stmt = $self->prepareAndExecute($sql);
    while ( my($sourceId, $na_feature_id) = $stmt->fetchrow_array()) {
      $self->{sourceIdFeatureIdMap}->{$sourceId} = $na_feature_id;
    }
}

sub undoTables {
  my ($self) = @_;
  return ("Dots.Similarity");
}
