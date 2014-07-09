package ApiCommonData::Load::Plugin::InsertPfamEntries;
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

use strict;
use warnings;

use GUS::PluginMgr::Plugin;

use GUS::Model::DoTS::PfamEntry;

my $argsDeclaration =
  [
   fileArg({ name           => 'inputFile',
	     descr          => 'The Pfam file',
	     reqd           => 1,
	     mustExist      => 1,
	     format         => 'Stockholm format',
	     constraintFunc => undef,
	     isList         => 0,
	   }),

   stringArg({ name           => 'pfamRelease',
	       descr          => 'The PFAM database release number this file corresponds to',
	       reqd           => 1,
	       constraintFunc => undef,
	       isList         => 0,
	     }),

  ];

my $purpose = <<PURPOSE;
Insert all PFAM domains from a PFAM database file.
PURPOSE

my $purposeBrief = <<PURPOSE_BRIEF;
Insert all PFAM domains from a PFAM database file.
PURPOSE_BRIEF

my $notes = <<NOTES;
None.
NOTES

my $tablesAffected = <<TABLES_AFFECTED;
DoTS.PfamEntry
TABLES_AFFECTED

my $tablesDependedOn = <<TABLES_DEPENDED_ON;
None.
TABLES_DEPENDED_ON

my $howToRestart = <<RESTART;
Just reexecute the plugin; all existing domains of the specified
version will be removed.
RESTART

my $failureCases = <<FAIL_CASES;
If PfamEntry associations have been made, this plugin won't be able to
delete the domains (integrity violation), and the plugin will die;
you'll need to first delete the associations before reexecuting this
plugin.
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

  $self->initialize({ requiredDbVersion => 3.6,
		      cvsRevision       => '$Revision: 9717 $',
		      name              => ref($self),
		      argsDeclaration   => $argsDeclaration,
		      documentation     => $documentation
		    });

  return $self;
}

sub run {
  my ($self) = @_;

  my $inputFile = $self->getArg('inputFile');
  open(PFAM, "<$inputFile") or $self->error("Couldn't open '$inputFile': $!\n");

  my $sth = $self->getQueryHandle()->prepare(<<EOSQL);
  DELETE
  FROM DoTS.PfamEntry
  WHERE release = ?
EOSQL

  $sth->execute($self->getArg('pfamRelease'));

  my ($name, $acc, $def, $nseq);
  my $ct = 0;
  while (<PFAM>) {
    chomp;
    if (m/^NAME\s+(\S+)/) {
      $name = $1;
    } elsif (m/ACC\s+(\S+)/) {
      $acc = $1;
    } elsif (m/DESC\s+(.*)/) {
      $def = $1;
    } elsif (m/^NSEQ\s+(\d+)/) {
      $nseq = $1;
      my $pfamEntry = GUS::Model::DoTS::PfamEntry->new();
      $pfamEntry->setRelease($self->getArg('pfamRelease'));
      $pfamEntry->setIdentifier($name);
      $pfamEntry->setAccession($acc);
      $pfamEntry->setDefinition($def);
      $pfamEntry->setNumberOfSeqs($nseq);
      $pfamEntry->submit();
      $ct++;
      $name = $acc = $def = $nseq = "NA";
    }
  }
  close(PFAM);

  warn "Loaded $ct PfamEntries\n";

}

sub undoTables {
  my ($self) = @_;
  return ("Dots.PfamEntry");
}
