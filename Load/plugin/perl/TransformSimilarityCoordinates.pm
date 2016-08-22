package ApiCommonData::Load::Plugin::TransformSimilarityCoordinates;
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
@ISA = qw( GUS::PluginMgr::Plugin);

use strict;
use warnings;

use GUS::PluginMgr::Plugin;

use GUS::Model::DoTS::Similarity;
use GUS::Model::DoTS::SimilaritySpan;

use ApiCommonData::Load::VirtualSequenceMap;

my $argsDeclaration =
  [
   stringArg({name => 'extDbRlsSpec',
	      descr => 'where do we find the source_ids of the sequences to be transformed',
	      constraintFunc => undef,
	      reqd => 1,
	      isList => 0
	     }),

   stringArg({name => 'virtExtDbRlsSpec',
	      descr => 'External database release specification of the virtual sequences',
	      constraintFunc => undef,
	      reqd => 1,
	      isList => 0
	     }),

   enumArg({name => 'sequenceRole',
	    descr => 'The role the sequence played in the analysis.',
	    constraintFunc => undef,
	    reqd => 1,
	    isList => 0,
	    enum => "query, subject",
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

  $self->initialize({ requiredDbVersion => 3.6,
		      cvsRevision => '$Revision$', # cvs fills this in!
		      name => ref($self),
		      argsDeclaration => $argsDeclaration,
		      documentation => $documentation
		    });

  return $self;
}

sub run {

  my ($self) = @_;

  my $extDbRlsId = $self->getExtDbRlsId($self->getArg('extDbRlsSpec'));
  my $virtExtDbRlsId = $self->getExtDbRlsId($self->getArg('virtExtDbRlsSpec'));

  my $dbh = $self->getQueryHandle();

  my $map =
    ApiCommonData::Load::VirtualSequenceMap->new({ extDbRlsId  => $extDbRlsId,
						   virtDbRlsId => $virtExtDbRlsId,
						   dbh         => $dbh
						 });

  my $extNaSeqTableId = $self->className2TableId("DoTS::ExternalNaSequence");
  my $virtSeqTableId = $self->className2TableId("DoTS::VirtualSequence");

  my $seqRole = $self->getArg('sequenceRole');

  my $sql = <<EOSQL;
SELECT s.similarity_id,
         ens.source_id,
         s.min_${seqRole}_start,
         s.max_${seqRole}_end,
         s.is_reversed
  FROM   DoTS.Similarity s,
         DoTS.ExternalNASequence ens
  WHERE  s.${seqRole}_id = ens.na_sequence_id
    AND  s.${seqRole}_table_id = $extNaSeqTableId
    AND  ens.external_database_release_id = $extDbRlsId
EOSQL

  my $spansSql = <<EOSQL;
 SELECT s.similarity_span_id,
         s.${seqRole}_start,
         s.${seqRole}_end,
         s.is_reversed
  FROM   DoTS.SimilaritySpan s
  WHERE  s.similarity_id = ?
EOSQL

  my $sth = $dbh->prepareAndExecute($sql);
  my $spans = $dbh->prepare($spansSql);

  my %lookup; # source_id to sequence_id mapping
  my $simCount = 0;
  my $spanCount = 0;

  while (my @row = $sth->fetchrow_array()) {

    my ($simId, $sourceId, $start, $end, $isReversed) = @row;
    my $result =
      $map->map(Bio::Location::Simple->new(-seq_id => $sourceId,
					   -start  => $start,
					   -end    => $end,
					   -strand => $isReversed ? -1 : +1,
					  )
	       );

    if ($result) {
      my $newloc = $result->match();

      my $sim = GUS::Model::DoTS::Similarity->new({ similarity_id => $simId });
      unless ($sim->retrieveFromDB()) {
	  $self->error("Couldn't retrieve similarity $simId from db");
      }

      my $virtSourceId = $newloc->seq_id();

      my ($virtSeqId) =
	($lookup{$virtSourceId}) ||= $dbh->selectrow_array(<<EOSQL, undef, $virtSourceId, $virtExtDbRlsId);

  SELECT na_sequence_id
  FROM   DoTS.VirtualSequence
  WHERE  source_id = ?
    AND  external_database_release_id = ?

EOSQL

      if ($seqRole eq 'query'){

	$sim->setQueryId($virtSeqId);
	$sim->setQueryTableId($virtSeqTableId);

	$sim->setMinQueryStart($newloc->start());
	$sim->setMaxQueryEnd($newloc->end());

      }elsif($seqRole eq 'subject'){

	$sim->setSubjectId($virtSeqId);
	$sim->setSubjectTableId($virtSeqTableId);

	$sim->setMinSubjectStart($newloc->start());
	$sim->setMaxSubjectEnd($newloc->end());
      }

      if($newloc->strand() == -1){
	$sim->setIsReversed(1);
      }else{
	$sim->setIsReversed(0);
      }

      $sim->submit();

      $simCount ++;
      $self->log("$simCount Similarities corrected") if $simCount % 1000 == 0;

      $spans->execute($simId);

      while (my @span = $spans->fetchrow_array()) {
        my ($spanId, $start, $end, $isReversed) = @span;

	my $simSpan = GUS::Model::DoTS::SimilaritySpan->new({ similarity_span_id => $spanId });
	unless ($simSpan->retrieveFromDB()) {
	  $self->error("Couldn't retrieve similarity span $spanId from db");
	}

	if($seqRole eq 'query'){

	  $simSpan->setQueryStart($newloc->start());
	  $simSpan->setQueryEnd($newloc->end());

	}elsif($seqRole eq 'subject'){

	  $simSpan->setSubjectStart($newloc->start());
	  $simSpan->setSubjectEnd($newloc->end());
	}

	if($newloc->strand() == -1){
	  $sim->setIsReversed(1);
	}else{
	  $sim->setIsReversed(0);
	}

	$simSpan->submit();

	$spanCount ++;

      }
    }
    $self->undefPointerCache();
  }

  return "Updated $simCount Similarities and $spanCount SimilaritySpans.\n";
}


sub undoTables {
  return qw( DoTS.SimilaritySpan
	     DoTS.Similarity
	   );
}

1;
