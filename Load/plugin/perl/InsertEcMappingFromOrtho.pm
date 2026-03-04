#^^^^^^^^^^^^^^^^^^^^^^^^^ End GUS4_STATUS ^^^^^^^^^^^^^^^^^^^^
##                 InsertEcMappingFromOrtho.pm
##
## Creates new entries in the table DoTS.AASequenceEnzymeClass from the
## TSV output produced by assignEcByOrthologs.pl
##
#######################################################################

package ApiCommonData::Load::Plugin::InsertEcMappingFromOrtho;
@ISA = qw( GUS::PluginMgr::Plugin);

use strict 'vars';

use GUS::PluginMgr::Plugin;
use lib "$ENV{GUS_HOME}/lib/perl";
use GUS::Model::DoTS::AASequenceEnzymeClass;
use GUS::Model::SRes::EnzymeClass;


my $purposeBrief = <<PURPOSEBRIEF;
Creates new entries in table DoTS.AASequenceEnzymeClass from transitive EC
assignments produced by assignEcByOrthologs.pl.
PURPOSEBRIEF

my $purpose = <<PLUGIN_PURPOSE;
Reads the TSV output of assignEcByOrthologs.pl and inserts EC assignments
into DoTS.AASequenceEnzymeClass.  The aa_sequence_id is taken directly from
the file, so no identifier lookup is required.  Cluster- and group-level
statistics from the file are stored alongside each assignment.
PLUGIN_PURPOSE

my $tablesAffected =
    [['DoTS.AASequenceEnzymeClass', 'New aa_sequence/enzyme class mappings are inserted here']];

my $tablesDependedOn =
    [['SRes.EnzymeClass',     'EC numbers must already exist in this table'],
     ['DoTS.AASequenceImp',   'aa_sequence_id values must already exist in this table']];

my $howToRestart = <<PLUGIN_RESTART;
Re-running the plugin is safe: existing rows are detected via retrieveFromDB
and skipped.
PLUGIN_RESTART

my $failureCases = <<PLUGIN_FAILURE_CASES;
Rows whose EC number is not present in SRes.EnzymeClass are skipped and logged.
PLUGIN_FAILURE_CASES

my $notes = <<PLUGIN_NOTES;
Both novel (is_novel=1) and already-annotated (is_novel=0) rows are loaded.
PLUGIN_NOTES

my $documentation = { purpose          => $purpose,
                      purposeBrief     => $purposeBrief,
                      tablesAffected   => $tablesAffected,
                      tablesDependedOn => $tablesDependedOn,
                      howToRestart     => $howToRestart,
                      failureCases     => $failureCases,
                      notes            => $notes
                    };

my $argsDeclaration =
  [
   fileArg({ name           => 'ECMappingFile',
             descr          => 'TSV file produced by assignEcByOrthologs.pl',
             constraintFunc => undef,
             reqd           => 1,
             isList         => 0,
             mustExist      => 1,
             format         => 'Tab-delimited with header row'
           }),
   stringArg({ name           => 'evidenceCode',
               descr          => 'Evidence code to store in AASequenceEnzymeClass (e.g. OrthoMCLDerived)',
               reqd           => 1,
               constraintFunc => undef,
               isList         => 0,
             }),
  ];

sub new {
    my ($class) = @_;
    my $self = {};
    bless($self, $class);

    $self->initialize({ requiredDbVersion => 4.0,
                        cvsRevision       => '$Revision$',
                        name              => ref($self),
                        argsDeclaration   => $argsDeclaration,
                        documentation     => $documentation
                      });
    return $self;
}

#######################################################################
# Main Routine
#######################################################################

sub run {
    my ($self) = @_;

    my $mappingFile = $self->getArg('ECMappingFile');
    my $evidCode    = $self->getArg('evidenceCode');

    $self->getAlgInvocation()->setMaximumNumberOfObjects(100000);

    my %ecCache;   # ec_number => enzyme_class_id
    my ($inserted, $skipped_existing, $skipped_no_ec) = (0, 0, 0);

    open(my $FH, '<', $mappingFile) or die "Cannot open '$mappingFile': $!\n";

    my $header = <$FH>;   # skip header line

    while (my $line = <$FH>) {
        chomp $line;
        my @row = split('\t', $line);

        # Expected columns (0-based):
        #  0  group_id
        #  1  aa_sequence_id
        #  2  source_id
        #  3  protein_length
        #  4  assigned_ec_number
        #  5  is_novel
        #  6  confidence_score
        #  7  n_supporting
        #  8  n_annotated_in_cluster
        #  9  cluster_size
        # 10  cluster_mean_length
        # 11  length_vs_cluster_mean
        # 12  cluster_profile
        # 13  group_size
        # 14  n_annotated_in_group
        # 15  n_supporting_in_group

        next unless scalar @row == 16;

        my ($group_id, $aa_sequence_id, $source_id, $protein_length,
            $ec_number, $is_novel, $confidence_score,
            $n_supporting, $n_annotated_in_cluster, $cluster_size,
            $cluster_mean_length, $length_vs_cluster_mean, $cluster_profile,
            $group_size, $n_annotated_in_group, $n_supporting_in_group) = @row;

        my $enzyme_class_id = $self->getEnzymeClassId($ec_number, \%ecCache);
        unless ($enzyme_class_id) {
            $self->log("WARNING: EC number '$ec_number' not found in SRes.EnzymeClass — skipping $source_id");
            $skipped_no_ec++;
            next;
        }

        my $newRow = GUS::Model::DoTS::AASequenceEnzymeClass->new({
            aa_sequence_id         => $aa_sequence_id,
            enzyme_class_id        => $enzyme_class_id,
            evidence_code          => $evidCode,
            domain_score           => $confidence_score,
            length_score           => $length_vs_cluster_mean,
            length_mean            => $cluster_mean_length,
            num_supporting_cluster => $n_supporting,
            num_protein_cluster    => $cluster_size,
            num_any_ec_cluster     => $n_annotated_in_cluster,
            num_supporting_group   => $n_supporting_in_group,
            num_protein_group      => $group_size,
            num_any_ec_group       => $n_annotated_in_group,
        });

        if ($newRow->retrieveFromDB()) {
            $skipped_existing++;
        } else {
            $newRow->submit();
            $self->log("Inserted EC=$ec_number for $source_id (aa_sequence_id=$aa_sequence_id, group=$group_id)");
            $inserted++;
        }

        $self->undefPointerCache();
    }

    close($FH);

    return "Inserted $inserted rows. Skipped: $skipped_existing already in DB, $skipped_no_ec unknown EC.\n";
}

sub getEnzymeClassId {
    my ($self, $ecNumber, $cache) = @_;
    unless (exists $cache->{$ecNumber}) {
        my $ec = GUS::Model::SRes::EnzymeClass->new({ ec_number => $ecNumber });
        $ec->retrieveFromDB();
        $cache->{$ecNumber} = $ec->getId();
    }
    return $cache->{$ecNumber};
}

sub undoTables {
    my ($self) = @_;
    return ('DoTS.AASequenceEnzymeClass');
}

1;
