package ApiCommonData::Load::Plugin::InsertEcNumberGenus;
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

@ISA = qw(GUS::PluginMgr::Plugin);

# ----------------------------------------------------------------------
use strict;
use GUS::PluginMgr::Plugin;
use GUS::Model::ApiDB::EcNumberGenus;

my $argsDeclaration =
  [

   fileArg({name           => 'ecNumberGenusFile',
            descr          => 'file with EC Number and Genus info',
            reqd           => 1,
            mustExist      => 1,
	    format         => '',
            constraintFunc => undef,
            isList         => 0, }),

  ];

my $purpose = <<PURPOSE;
To load ApiDB.EcNumberGenus table
PURPOSE

my $purposeBrief = <<PURPOSE_BRIEF;
To load ApiDB.EcNumberGenus table
PURPOSE_BRIEF

my $notes = <<NOTES;

NOTES

my $tablesAffected = <<TABLES_AFFECTED;
ApiDB::EcNumberGenus
TABLES_AFFECTED

my $tablesDependedOn = <<TABLES_DEPENDED_ON;
TABLES_DEPENDED_ON

my $howToRestart = <<RESTART;
There are no restart facilities for this plugin
RESTART

my $failureCases = <<FAIL_CASES;
FAIL_CASES

my $documentation = { purpose          => $purpose,
                      purposeBrief     => $purposeBrief,
                      notes            => $notes,
                      tablesAffected   => $tablesAffected,
                      tablesDependedOn => $tablesDependedOn,
                      howToRestart     => $howToRestart,
                      failureCases     => $failureCases };

# ----------------------------------------------------------------------

sub new {
  my ($class) = @_;
  my $self = {};
  bless($self,$class);

  $self->initialize({ requiredDbVersion => 3.6,
                      cvsRevision       => '$Revision$',
                      name              => ref($self),
                      argsDeclaration   => $argsDeclaration,
                      documentation     => $documentation});

  return $self;
}

# ======================================================================

sub run {
  my ($self) = @_;

  open(FILE, $self->getArg('ecNumberGenusFile')) || die "Could Not open ecNumberGenusFile for reading: $!\n";

  my $count;

  while(<FILE>) {
      chomp;
      next unless $_;

      my ($ecNumber, $genus) = split(/\t/, $_);

      my $ecgenus= GUS::Model::ApiDB::EcNumberGenus->
	       new({ecNumber => $ecNumber,
		    genus => $genus
		   });
      $ecgenus->submit();

	  $count++;
	  if ($count % 1000 == 0) {
	      $self->log("Inserted $count Entries into EcNumberGenus");
	      $self->undefPointerCache();
	  }
  }
  return("Loaded $count ApiDB::EcNumberGenus");
}

sub undoTables {
  my ($self) = @_;

  return ('ApiDB.EcNumberGenus',
	 );
}

1;
