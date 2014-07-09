package ApiCommonData::Load::Plugin::InsertRUMIntronFeature;
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
  # GUS4_STATUS | RNASeq Junctions               | auto   | broken
  # GUS4_STATUS | Simple Rename                  | auto   | absent
  # GUS4_STATUS | ApiDB Tuning Gene              | auto   | absent
  # GUS4_STATUS | Rethink                        | auto   | absent
  # GUS4_STATUS | dots.gene                      | manual | unreviewed
die 'This file has broken or unreviewed GUS4_STATUS rules.  Please remove this line when all are fixed or absent';
#^^^^^^^^^^^^^^^^^^^^^^^^^ End GUS4_STATUS ^^^^^^^^^^^^^^^^^^^^

@ISA = qw(GUS::PluginMgr::Plugin);

# ----------------------------------------------------------
# Plugin to load date in apidb.RUMIntronFeature table
# ----------------------------------------------------------

use strict;
use warnings;

use GUS::PluginMgr::Plugin;
use GUS::Model::DoTS::NASequence;
use GUS::Model::ApiDB::RUMIntronFeature;


# ----------------------------------------------------------
# Load Arguments
# ----------------------------------------------------------

sub getArgsDeclaration {
  my $argsDeclaration  =
    [
     stringArg({ name => 'inputFile',
		 descr => 'RUM result file that the plugin has to be run on',
		 constraintFunc=> undef,
		 reqd  => 1,
		 isList => 0,
		 mustExist => 1,
	       }),
     stringArg({ name => 'extDbName',
		 descr => 'externaldatabase name',
		 constraintFunc=> undef,
		 reqd  => 1,
		 isList => 0
	       }),
     stringArg({ name => 'extDbVer',
		 descr => 'externaldatabaserelease version',
		 constraintFunc=> undef,
		 reqd  => 1,
		 isList => 0
	       }),
     stringArg({ name => 'sampleName',
		 descr => 'sample Name',
		 constraintFunc=> undef,
		 reqd  => 1,
		 isList => 0
	       })
    ];

  return $argsDeclaration;
}


# ----------------------------------------------------------
# Documentation
# ----------------------------------------------------------

sub getDocumentation {

  my $description = <<DESCR;
Plugin to load RUM Exon Junction Calls in apidb.RUMIntronFeature table
DESCR

  my $purpose = <<PURPOSE;
Plugin to load RUM Exon Junction Calls in apidb.RUMIntronFeature table
PURPOSE

  my $purposeBrief = <<PURPOSEBRIEF;
Plugin to load RUM Exon Junction Calls in apidb.RUMIntronFeature table
PURPOSEBRIEF

  my $notes = <<NOTES;
NOTES

  my $tablesAffected = <<AFFECT;
ApiDB.RUMIntronFeature
AFFECT

  my $tablesDependedOn = <<TABD;
DoTS.NASequence, SRes.ExternalDatabaseRelease, SRes.ExternalDatabase
TABD

  my $howToRestart = <<RESTART;
No restart provided. Must undo and reload.
RESTART

  my $failureCases = <<FAIL;
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

# ----------------------------------------------------------

sub new {
  my $class = shift;
  my $self = {};
  bless($self, $class);

  my $documentation = &getDocumentation();

  my $args = &getArgsDeclaration();

  my $configuration = { requiredDbVersion => 3.6,
                        cvsRevision => '$Revision$',
                        name => ref($self),
                        argsDeclaration => $args,
                        documentation => $documentation
                      };

  $self->initialize($configuration);

  return $self;
}

# ----------------------------------------------------------

sub run {
  my $self = shift;

  my $extDbReleaseId = $self->getExtDbRlsId($self->getArg('extDbName'),$self->getArg('extDbVer'))
    || $self->error("Cannot find external_database_release_id for the data source");

  my $file = $self->getArg('inputFile');

  my $sampleName = $self->getArg('sampleName');

  $self->processFileAndInsertRUMIntronFeatures($file, $extDbReleaseId, $sampleName);

  return "Processed $file.";
}



sub processFileAndInsertRUMIntronFeatures {
  my ($self, $file, $extDbReleaseId, $sampleName) = @_;

  open (FILE, $file);

  my $count = 0; 

  while (<FILE>){
    chomp;

    next if (/^intron/);

    # -----------------------------------------------------------------------------------------------------------------------
    # intron  score   known   standard_splice_signal  signal_not_canonical    ambiguous       long_overlap_unique_reads       short_overlap_unique_reads      long_overlap_nu_reads short_overlap_nu_reads
    # Tb927_10_v5:2096882-2096896     0       0       0       0       1       0       0       0       1
    #
    # -----------------------------------------------------------------------------------------------------------------------

    my @temp = split("\t", $_);

    my ($seqSourceId,$location) = split(":", $temp[0]);

    my $naSeqId = $self->getNaSequenceFromSourceId($seqSourceId);

    my ($mapping_start,$mapping_end) = split("\-", $location);

    my $rifeature = GUS::Model::ApiDB::RUMIntronFeature->new({external_database_release_id => $extDbReleaseId,
							       sample_name => $sampleName,
							       na_sequence_id => $naSeqId,
							       mapping_start => $mapping_start,
							       mapping_end => $mapping_end,
							       score => $temp[1],
							       known_intron => $temp[2],
							       standard_splice_signal => $temp[3],
							       signal_not_canonical => $temp[4],
							       ambiguous => $temp[5],
							       long_overlap_unique_reads => $temp[6],
							       short_overlap_unique_reads => $temp[7],
							       long_overlap_nu_reads => $temp[8],
							       short_overlap_nu_reads => $temp[9],
							      });
    $rifeature->submit();
    $count++;
    $self->undefPointerCache() if $count % 1000 == 0;
  }
  close (FILE);

  $self->log("Inserted $count features from $file");

}

sub getNaSequenceFromSourceId {
  my ($self, $srcId) = @_;
  if (my $id = $self->{naSequence}->{$srcId}) {
    return $id;
  }

  my $naSeq = GUS::Model::DoTS::NASequence->new({source_id => $srcId});
  unless ($naSeq->retrieveFromDB) {
    $self->error("Can't find na_sequence_id for sequence $srcId");
  }
  my $naSeqId = $naSeq->getNaSequenceId();
  $self->{naSequence}->{$srcId} = $naSeqId;

  return $naSeqId;
}


sub undoTables {
  my ($self) = @_;

  return ('ApiDB.RUMIntronFeature');
}


return 1;
