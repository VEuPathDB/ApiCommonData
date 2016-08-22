package ApiCommonData::Load::Plugin::CalculateAASequenceIsoelectricPoint;
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

use strict;
use warnings;

use GUS::PluginMgr::Plugin;
use base qw(GUS::PluginMgr::Plugin);

use GUS::Model::ApiDB::AaSequenceAttribute;
use Bio::Tools::SeqStats;
use Bio::Tools::pICalculator;
use Bio::Seq;

my $argsDeclaration =
  [
   stringArg({ name => 'extDbRlsName',
	       descr => 'External Database Release name of the AA sequences',
	       constraintFunc => undef,
	       isList => 0,
	       reqd => 1,
	     }),

   stringArg({ name => 'extDbRlsVer',
	       descr => 'External Database Release version of the AA sequences',
	       constraintFunc => undef,
	       isList => 0,
	       reqd => 1,
	     }),
   stringArg({ name => 'seqTable',
	       descr => 'where to find the target AA sequences in the form DoTs.tablename',
	       constraintFunc => undef,
	       isList => 0,
	       reqd => 1,
	     })
  ];


my $purposeBrief = <<PURPOSEBRIEF;
Calculates molecular weights of amino acid sequences.
PURPOSEBRIEF

my $purpose = <<PLUGIN_PURPOSE;
Calculates molecular weights of amino acid sequences.
PLUGIN_PURPOSE

my $tablesAffected =
  [
   ['ApiDB.AASequenceAttribute' =>
    'molecular weight fields are updated if the entry exists, otherwise a new entry for the sequence is added with the molecular weight fields filled in'
   ],
  ];

my $tablesDependedOn = [];

my $howToRestart = <<PLUGIN_RESTART;
PLUGIN_RESTART

my $failureCases = <<PLUGIN_FAILURE_CASES;
PLUGIN_FAILURE_CASES

my $notes = <<PLUGIN_NOTES;
PLUGIN_NOTES

my $documentation = { purposeBrief => $purposeBrief,
		      purpose => $purpose,
		      tablesAffected => $tablesAffected,
		      tablesDependedOn => $tablesDependedOn,
		      howToRestart => $howToRestart,
		      failureCases => $failureCases,
		      notes => $notes,
		    };

sub new {

  my $class = shift;
  $class = ref $class || $class;
  my $self = {};

  bless $self, $class;

  $self->initialize({ requiredDbVersion => 3.6,
		      cvsRevision =>  '$Revision: 10096 $',
		      name => ref($self),
		      argsDeclaration   => $argsDeclaration,
		      documentation     => $documentation
		    });
  return $self;
}

sub run {

  my ($self) = @_;

  my $extDbRlsName = $self->getArg("extDbRlsName");
  my $extDbRlsVer = $self->getArg("extDbRlsVer");

  my $extDbRlsId = $self->getExtDbRlsId($extDbRlsName, $extDbRlsVer);

  unless ($extDbRlsId) {
    die "No such External Database Release / Version:\n $extDbRlsName / $extDbRlsVer\n";
  }

  my $dbh = $self->getQueryHandle();

  my $sth = $dbh->prepare(<<EOSQL);

  SELECT aa_sequence_id, sequence
  FROM   @{[$self->getArg('seqTable')]}
  WHERE  external_database_release_id = ?

EOSQL

  $sth->execute($extDbRlsId);

  my $count = 0;
  my $pIcalc = Bio::Tools::pICalculator->new();
  while (my ($aaSeqId, $seq) = $sth->fetchrow_array()) {
    $seq = Bio::Seq->new(-seq => $seq, -alphabet => "protein");
    $pIcalc->seq($seq);
    my $isoelectricPoint = $pIcalc->iep();

    my $newSeqAttr =
      GUS::Model::ApiDB::AaSequenceAttribute->new({aa_sequence_id => $aaSeqId});

    $newSeqAttr->retrieveFromDB();

    $newSeqAttr->setIsoelectricPoint($isoelectricPoint);

    $newSeqAttr->submit();
    $count++;
    $self->undefPointerCache();

    if($count % 100 == 0) {
      $self->log("Updated $count sequences.");
      $self->undefPointerCache();
    }

  }

  $self->log("Done updated $count sequences");
}

1;
