package ApiCommonData::Load::Plugin::InsertOrthoGroupAASequence;
use lib "$ENV{GUS_HOME}/lib/perl";
@ISA = qw(GUS::PluginMgr::Plugin);

# ----------------------------------------------------------------------

use strict;
use GUS::PluginMgr::Plugin;
use FileHandle;
use GUS::Supported::Util;
use GUS::Model::ApiDB::OrthologGroup;
use GUS::Model::ApiDB::OrthologGroupAASequence;
use GUS::Model::DoTS::ExternalAASequence;
use GUS::Model::DoTS::AASequence;

my $argsDeclaration =
[
    fileArg({name           => 'orthoFile',
            descr          => 'Ortholog Data (ortho.mcl). OrthologGroupName(gene and taxon count) followed by a colon then the ids for the members of the group',
            reqd           => 1,
            mustExist      => 1,
	    format         => 'OG2_1009: osa|ENS1222992 pfa|PF11_0844...',
            constraintFunc => undef,
            isList         => 0, }),
];

my $purpose = <<PURPOSE;
Insert an ApiDB::OrthologGroupAASequence from an orthomcl groups file.
PURPOSE

my $purposeBrief = <<PURPOSE_BRIEF;
Load an orthoMCL group sequence pair.
PURPOSE_BRIEF

my $notes = <<NOTES;
Need a script to create the mapping file.
NOTES

my $tablesAffected = <<TABLES_AFFECTED;
ApiDB.OrthologGroupAASequence
TABLES_AFFECTED

my $tablesDependedOn = <<TABLES_DEPENDED_ON;
ApiDB.OrthologGroup,
DoTS.ExternalAASequence
DoTS.AASequence
TABLES_DEPENDED_ON

my $howToRestart = <<RESTART;
The plugin can been restarted, since the same ortholog group from the same OrthoMCL analysis version will only be loaded once.
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

  $self->initialize({ requiredDbVersion => 4,
                      cvsRevision       => '$Revision$',
                      name              => ref($self),
                      argsDeclaration   => $argsDeclaration,
                      documentation     => $documentation});

  return $self;
}

# ======================================================================

sub run {
    my ($self) = @_;

    my $orthologFile = $self->getArg('orthoFile');

    my %sequenceIdHash;
    my $sql = "SELECT aa_sequence_id, secondary_identifier FROM dots.externalaasequence";
    my $dbh = $self->getQueryHandle();
    my $externalAASequenceQuery = $dbh->prepare($sql);
    $externalAASequenceQuery->execute();

    while (my ($aaSeqId , $seqId)= $externalAASequenceQuery->fetchrow_array()) {
        $sequenceIdHash{$seqId} = $aaSeqId;
    }

    $sql = "SELECT aa_sequence_id, source_id FROM dots.aasequence";
    my $aaSequenceQuery = $dbh->prepare($sql);
    $aaSequenceQuery->execute();

    while (my ($aaSeqId , $seqId)= $aaSequenceQuery->fetchrow_array()) {
        $sequenceIdHash{$seqId} = $aaSeqId;
    }

    my $formattedFile = $self->formatInput($orthologFile, %sequenceIdHash);

    $self->loadGroupSequence($formattedFile);
}

# ---------------------- Subroutines ----------------------

sub formatInput {
    my ($self, $inputFile, %sequenceIds) = @_;

    my $outputFile = "$inputFile\_formatted.txt";

    open(IN, $inputFile) or die "Cannot open input file $inputFile for reading. Please check and try again\n$!\n\n";
    open(OUT, "> $outputFile") or die "Cannot open output file $outputFile for writing. Please check and try again\n$!\n\n";

    while (<IN>) {
        my $line = $_;
       
        my @groupAndSeqs =  split(/:\s/,$line);
        my $groupId = $groupAndSeqs[0];
        my $seqs = $groupAndSeqs[1];
        my @groupSeqs = split(/\s/,$seqs);

        my $numOfSeqs = @groupSeqs;
 
        if ($numOfSeqs == 0) {
            die "No Sequences assigned to group $groupId";
        }

        foreach my $seq (@groupSeqs) {
            if ($sequenceIds{$seq}) {
                print OUT "$groupId,$sequenceIds{$seq}\n";
            }
            else {
                $self->log("$seq before change");
                $seq =~ s/_/:/;
                $self->log("$seq after change");
                if ($sequenceIds{$seq}) {
                    print OUT "$groupId,$sequenceIds{$seq}\n";
                }
                else {
                    die "No aasequenceId for sequence $seq\n";
		}
            }
        }    
        
    }
    close(IN);
    close(OUT);

    return $outputFile;
}

sub loadGroupSequence {
  my ($self, $inputFile) = @_;
  my $count = 0;
  open(my $data, '<', $inputFile) || die "Could not open file $inputFile: $!";
  while (my $line = <$data>) {
      chomp $line;
      $count += 1;
      my ($group_id, $seqId) = split(/,/, $line);
      my $row = GUS::Model::ApiDB::OrthologGroupAASequence->new({group_id => $group_id,aa_sequence_id => $seqId});
      $row->submit();
      $row->undefPointerCache();
      $self->log("Inserted $count rows into ApiDb::OrthologGroupAASequence") if ($count % 1000 == 0);
  }  
  $self->log("Successfully Inserted $count rows into ApiDb::OrthologGroupAASequence");
}

# ----------------------------------------------------------------------

sub undoTables {
  my ($self) = @_;

  return ('ApiDB.OrthologGroupAASequence');
}

1;
