package ApiCommonData::Load::Plugin::CalculateAASeqAttributes;
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
  # GUS4_STATUS | dots.gene                      | manual | absent
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
	     }),

   stringArg({name => 'idSql',
		descr => 'sql used to get the target AA sequences',
		constraintFunc=> undef,
		reqd  => 0,
		isList => 0
	       })
  ];


my $purposeBrief = <<PURPOSEBRIEF;
Calculates molecular weights MinMax and IsoelectricPoint of amino acid sequences.
PURPOSEBRIEF

my $purpose = <<PLUGIN_PURPOSE;
Calculates molecular weights  MinMax and IsoelectricPoint of amino acid sequences.
PLUGIN_PURPOSE

my $tablesAffected =
  [
   ['ApiDB.AASequenceAttribute' =>
    'min_molecular_weight,max_molecular_weight,isoelectric_point fields are updated if the entry exists, otherwise a new entry for the sequence is added with those fields filled in'
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

  $self->initialize({ requiredDbVersion => 4.0,
		      cvsRevision =>  '$Revision$',
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

  my $sql = <<EOSQL;
  SELECT aa_sequence_id, sequence
  FROM   @{[$self->getArg('seqTable')]}
  WHERE  external_database_release_id = ?

EOSQL
 
  if ($self->getArg("idSql")){

      $sql = $self->getArg("idSql");
  }

  my $sth = $dbh->prepare($sql);


  $sth->execute($extDbRlsId);

  my $count = 0;

  my $pIcalc = Bio::Tools::pICalculator->new();

  while (my ($aaSeqId, $seq) = $sth->fetchrow_array()) {

    # J is valid IUPAC for leucine/isoleucine ambiguity but apparently
    # Bio::Tools::SeqStats didn't get the memo - J is not allowed.
    $seq =~ s/J/L/g;
    
    my $seq = Bio::Seq->new(-id => $aaSeqId,
				   -seq => $seq,
				   -alphabet => "protein",
				  );
    my ($minWt, $maxWt) =
      @{Bio::Tools::SeqStats->get_mol_wt($seq)};

    $pIcalc->seq($seq);

    my $isoelectricPoint = $pIcalc->iep();

    my $newSeqAttr =
      GUS::Model::ApiDB::AaSequenceAttribute->new({aa_sequence_id => $aaSeqId});

    $newSeqAttr->retrieveFromDB();

    $newSeqAttr->setMinMolecularWeight($minWt);

    $newSeqAttr->setMaxMolecularWeight($maxWt);

    $newSeqAttr->setIsoelectricPoint($isoelectricPoint);

    $newSeqAttr->submit();

    $count++;

    $self->undefPointerCache();

    if($count % 100 == 0) {
      $self->log("Inserted $count sequences.");
      $self->undefPointerCache();
    }

  }

  $self->log("Done inserted $count sequences");
}


sub undoTables {
  my ($self) = @_;

  return ('ApiDB.AASequenceAttribute',
	 );
}

1;
