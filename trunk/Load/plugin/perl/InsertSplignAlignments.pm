package ApiCommonData::Load::Plugin::InsertSplignAlignments;
@ISA = qw( GUS::PluginMgr::Plugin);

use strict;
use warnings;

use GUS::PluginMgr::Plugin;

use GUS::Model::DoTS::Similarity;
use GUS::Model::DoTS::SimilaritySpan;

use List::Util qw(min max sum);

my $argsDeclaration = 
  [
   fileArg({ name           => 'inputFile',
	     descr          => 'Splign output',
	     reqd           => 1,
	     mustExist      => 1,
	     format         => 'custom',
	     constraintFunc => undef,
	     isList         => 0,
	   }),

   stringArg({name => 'estTable',
	      descr => 'where do we find the ESTs',
	      constraintFunc => undef,
	      reqd => 1,
	      isList => 0
	     }),

   stringArg({name => 'seqTable',
	      descr => 'where do we find the genomic/contig sequences',
	      constraintFunc => undef,
	      reqd => 1,
	      isList => 0
	     }),

   stringArg({name => 'estExtDbRlsSpec',
	      descr => 'where do we find source_id\'s for the ESTs',
	      constraintFunc => undef,
	      reqd => 1,
	      isList => 0
	     }),
 
   stringArg({name => 'seqExtDbRlsSpec',
	      descr => 'where do we find source_id\'s for the genomic/contig sequences',
	      constraintFunc => undef,
	      reqd => 1,
	      isList => 0
	     }),

  ];

my $purposeBrief = <<PURPOSEBRIEF;
PURPOSEBRIEF
    
my $purpose = <<PLUGIN_PURPOSE;
PLUGIN_PURPOSE

my $tablesAffected = <<TABLES_AFFECTED;
TABLES_AFFECTED

my $tablesDependedOn = [];

my $howToRestart = <<PLUGIN_RESTART;
PLUGIN_RESTART

my $failureCases = <<PLUGIN_FAILURE_CASES;
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

sub new {
    my ($class) = @_;
    my $self = {};
    bless($self,$class);

    $self->initialize({requiredDbVersion => 3.5,
		       cvsRevision => '$Revision: 9982 $', # cvs fills this in!
		       name => ref($self),
		       argsDeclaration => $argsDeclaration,
		       documentation => $documentation
		      });

    return $self;
}

sub run {

  my ($self) = @_;

  my $file = $self->getArg('inputFile');

  my $estExtDbRlsId = $self->getExtDbRlsId($self->getArg('estExtDbRlsSpec'));
  my $seqExtDbRlsId = $self->getExtDbRlsId($self->getArg('seqExtDbRlsSpec'));

  my $estTable = $self->getArg('estTable');
  my $seqTable = $self->getArg('seqTable');

  my $estTableId = $self->className2TableId($estTable);
  my $seqTableId = $self->className2TableId($seqTable);

  $estTable = "GUS::Model::$estTable";
  $seqTable = "GUS::Model::$seqTable";

  open(IN, "<$file") or $self->error("Couldn't open file '$file': $!\n");

  my @hsps;
  my $lastId;
  my $count = 0;
  while (<IN>) {
    chomp;
    next if m/Gap/;
    my ($hspId,
	$estSourceId, $seqSourceId,
	$percId, $alnLen,
	$estStart, $estEnd,
	$seqStart, $seqEnd,
	$splice, $alnInfo) = split(" ", $_);

    if ($lastId && $hspId ne $lastId) {
      $self->_processSimilarity($estTableId, $seqTableId, \@hsps) if @hsps;
      $count++;
      @hsps = ();
    }

    $lastId = $hspId;

    my $estId = $self->_getSeqId($estSourceId, $estTable, $estExtDbRlsId);
    my $seqId = $self->_getSeqId($seqSourceId, $seqTable, $seqExtDbRlsId);

    my $isReversed = 0;
    if ($seqStart > $seqEnd) {
      ($seqStart, $seqEnd) = ($seqEnd, $seqStart);
      $isReversed = 1;
    }

    push @hsps, { estId => $estId,
		  seqId => $seqId,
		  percId => $percId,
		  alnLen => $alnLen,
		  estStart => $estStart,
		  estEnd => $estEnd,
		  seqStart => $seqStart,
		  seqEnd => $seqEnd,
		  isReversed => $isReversed,
		  alnInfo => $alnInfo,
		  splice => $splice,
		};
    
  }
  close(IN);

  $self->_processSimilarity($estTableId, $seqTableId, \@hsps) if @hsps;
  $count++;

  return "done (inserted $count similarities)";
}

sub _getSeqId {

  my ($self, $sourceId, $tableName, $extDbRlsId) = @_;

  return $self->{_seqIdCache}->{$tableName}->{$extDbRlsId}->{$sourceId} ||= do {
    eval "require $tableName"; $self->error($@) if $@;

    my $seq = $tableName->new({ source_id => $sourceId,
				external_database_release_id => $extDbRlsId,
			      });
    unless ($seq->retrieveFromDB()) {
      $self->error("Couldn't find a $tableName with id of $sourceId");
    }
    $seq->getId();
  }
}

sub _processSimilarity {

  my ($self, $estTableId, $seqTableId, $hsps) = @_;

  my $sim =
    GUS::Model::DoTS::Similarity->new(
     {
      subject_table_id   => $seqTableId,
      subject_id         => $hsps->[0]->{seqId},
      query_table_id     => $estTableId,
      query_id           => $hsps->[0]->{estId},
      min_subject_start  => min(map { $_->{seqStart} } @$hsps),
      max_subject_end    => max(map { $_->{seqEnd} } @$hsps),
      min_query_start    => min(map { $_->{estStart} } @$hsps),
      max_query_end      => max(map { $_->{estEnd} } @$hsps),
      number_of_matches  => scalar(@$hsps),
      total_match_length => sum(map { $_->{alnLen} } @$hsps),
      number_identical   => sprintf("%d", sum(map { $_->{percId} * $_->{alnLen} } @$hsps)),
      number_positive    => sprintf("%d", sum(map { $_->{percId} * $_->{alnLen} } @$hsps)),
      is_reversed        => $hsps->[0]->{isReversed},
     });

  for my $hsp (@$hsps) {
    my $simSpan =
      GUS::Model::DoTS::SimilaritySpan->new(
       {
	match_length => $hsp->{alnLen},
	number_identical => sprintf("%d", $hsp->{alnLen} * $hsp->{percId}),
	number_positive => sprintf("%d", $hsp->{alnLen} * $hsp->{percId}),
	subject_start => $hsp->{seqStart},
	subject_end => $hsp->{seqEnd},
	query_start => $hsp->{estStart},
	query_end => $hsp->{estEnd},
	is_reversed => $hsp->{isReversed},
       });
    $sim->addChild($simSpan);
  }

  $sim->submit();
  $self->undefPointerCache();
}

sub undoTables {
  return qw( DoTS.SimilaritySpan
	     DoTS.Similarity
	   );
}

1;
