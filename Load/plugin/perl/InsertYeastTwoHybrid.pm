package ApiCommonData::Load::Plugin::InsertYeastTwoHybrid;
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

@ISA = qw(GUS::PluginMgr::Plugin);

=pod -------------------------------------------------------------------

=head1 Purpose

This plugin inserts Gene Interaction data from Yeast Two Hybrid data 
into a GUS Table.

=over 4

=item interactionFile

This is a tab-delimited file.  The First line is the Header and should contain each of the following exactly: (bait_ORF, bait_start, bait_end, prey_ORF, prey_start, prey_end, number_observed, number_searches_which_found_int, number_prey_int_with_bait, number_bait_int_with_prey).

=back

=cut

# ----------------------------------------------------------------------

use strict;
use GUS::PluginMgr::Plugin;
use FileHandle;

use GUS::Supported::Util;

use GUS::Model::ApiDB::GeneInteraction;

my $argsDeclaration =
[

   fileArg({name           => 'interactionFile',
	    descr          => 'A tab delimeted file containing the gene interaction (Y2H) set.',
	    reqd           => 1,
	    mustExist      => 1,
	    format         => 'Column Headers must be exact.',
	    constraintFunc => undef,
	    isList         => 0, }),

   stringArg({name => 'organismAbbrev',
	      descr => 'if supplied, use a prefix to use for tuning manager tables',
	      reqd => 0,
	      constraintFunc => undef,
	      isList => 0,
	     }),
];

my $purpose = <<PURPOSE;
Insert a table of Yeast Two Hybrid data into geneInteraction.  
PURPOSE

my $purposeBrief = <<PURPOSE_BRIEF;
Insert a table of Yeast Two Hybrid data into geneInteraction.
PURPOSE_BRIEF

my $notes = <<NOTES;
This is a tab-delimited file.  The First line is the Header and should contain each of the following exactly: (bait_ORF, bait_start, bait_end, prey_ORF, prey_start, prey_end, number_observed, number_searches_which_found_int, number_prey_int_with_bait, number_bait_int_with_prey).
NOTES

my $tablesAffected = <<TABLES_AFFECTED;
ApiDB::GeneInteraction
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

  $self->initialize({ requiredDbVersion => 4.0,
		      cvsRevision       => '$Revision$',
		      name              => ref($self),
		      argsDeclaration   => $argsDeclaration,
		      documentation     => $documentation});

  return $self;
}

# ======================================================================

sub run {
  my ($self) = @_;

  open(FILE, $self->getArg('interactionFile')) || die "Could Not open File for reading: $!\n";

  my $header = <FILE>;
  chomp $header;

  my $line = 1;

  my @expectedHeaders = ('bait_ORF', 'bait_start', 'bait_end', 'prey_ORF', 'prey_start', 
			 'prey_end', 'number_observed', 'number_searches_which_found_int', 
			 'number_prey_int_with_bait', 'number_bait_int_with_prey');

  my %index = %{$self->_getHeaderMapping($header, \@expectedHeaders)};

  while(<FILE>) {
    chomp;

    my @features = split("\t", $_);

    # Check that every line has a value for each header
    foreach(@expectedHeaders) {
      if(!$features[$index{$_}] && $_ ne 'self_int') {
	die "Missing Value on Line $line (AFTER HEADER) of input File: $!";
      }
    }

    my $baitGeneFeatureId = GUS::Supported::Util::getGeneFeatureId($self, $features[$index{bait_ORF}], 0, $self->getArg('organismAbbrev'));
    my $preyGeneFeatureId = GUS::Supported::Util::getGeneFeatureId($self, $features[$index{prey_ORF}], 0, $self->getArg('organismAbbrev'));

    next if(!$baitGeneFeatureId || !$preyGeneFeatureId);

    print STDERR "Inserting:  bait=$baitGeneFeatureId, prey=$preyGeneFeatureId\n";

    my $interaction = GUS::Model::ApiDB::GeneInteraction->
      new({ bait_gene_feature_id => $baitGeneFeatureId,
	    prey_gene_feature_id => $preyGeneFeatureId,
	    bait_start => $features[$index{bait_start}],
	    bait_end => $features[$index{bait_end}],
	    prey_start => $features[$index{prey_start}],
	    prey_end => $features[$index{prey_end}],
	    times_observed => $features[$index{number_observed}],
	    number_of_searches => $features[$index{number_searches_which_found_int}],
	    prey_number_of_baits => $features[$index{number_prey_int_with_bait}],
	    bait_number_of_preys => $features[$index{number_bait_int_with_prey}]
          });

    $interaction->submit();

    $line++;
  }

  close(FILE);

  return("Inserted $line lines into GeneFeatures");
}

=pod

=head2 subroutine _getHeaderMapping

Takes a tab delimeted line from a file and converts into a mapping of which
column that data appears.

=cut

# ----------------------------------------------------------------------

sub _getHeaderMapping {
  my ($self, $header, $expHeader) = @_;

  my %map;

  my @colNames = split("\t", $header);

  for(my $i = 0; $i < scalar @colNames; $i++) {
    $map{$colNames[$i]} = $i;
  }

  foreach(@$expHeader) {
    if(! exists $map{$_}) {
      die "Header is not in the Correct Format (should be $_) !\n$!\n";
    }
  }

  return(\%map);
}

sub undoTables {
  my ($self) = @_;

  return ('ApiDB.GeneInteraction');
}

1;

