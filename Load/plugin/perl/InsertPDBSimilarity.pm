package ApiDB::Load::Plugin::InsertPDBSimilarity;
@ISA = qw(GUS::PluginMgr::Plugin);

use strict;
use GUS::PluginMgr::Plugin;
use GUS::Model::ApiDB::PDBSimilarity;
use GUS::Supported::Util;
use GUS::Model::SRes::ExternalDatabaseRelease;

sub getArgumentsDeclaration {
    my $argsDeclaration =
      [
       fileArg({name => 'diamondFile',
                descr => 'DIAMOND BLAST tabular output file (format -f 6)',
                reqd => 1,
                mustExist => 1,
                format => 'Text'
               }),
       stringArg({name           => 'extDbRlsSpec',
                  descr          => 'external database release spec',
                  reqd           => 1,
                  constraintFunc => undef,
                  isList         => 0, }),
      ];
    return $argsDeclaration;
}

sub getDocumentation {
  my $description = <<DESCR;
Inserts records into ApiDB.PDBSimilarity from a DIAMOND BLAST tabular output file.
DESCR

  my $purpose = <<PURPOSE;
Inserts records into ApiDB.PDBSimilarity from a DIAMOND BLAST tabular output file.
PURPOSE

  my $purposeBrief = <<PURPOSEBRIEF;
Inserts records into ApiDB.PDBSimilarity from a DIAMOND BLAST tabular output file.
PURPOSEBRIEF

  my $notes = <<NOTES;
This plugin uses the DIAMOND output file in tabular format (-f 6) to insert records into the ApiDB.PDBSimilarity table.
NOTES

  my $tablesAffected = <<AFFECT;
ApiDB.PDBSimilarity
AFFECT

  my $tablesDependedOn = <<TABD;
ApiDB.ProteinDataBank, Dots.AASequence, SRes.ExternalDatabaseRelease
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

sub new {
    my ($class) = @_;
    my $self = {};
    bless($self, $class);

    my $documentation = &getDocumentation();
    my $argsDeclaration = &getArgumentsDeclaration();

    $self->initialize({
        requiredDbVersion => 4.0,
        cvsRevision => '$Revision$', 
        name => ref($self),
        argsDeclaration => $argsDeclaration,
        documentation => $documentation
    });

    return $self;
}

sub run {
    my ($self) = @_;

    my $diamondFile = $self->getArg('diamondFile');
    my $extDbRlsId = $self->getExtDbRlsId($self->getArg('extDbRlsSpec'));
    my ($processed);

    open my $fh, '<', $diamondFile or $self->userError("Unable to open file: $diamondFile");

    while (my $line = <$fh>) {
        chomp $line;
        my ($query_id, $subject_id, $pident, $length, $mismatch, $query_start, $query_end, $subject_start, $subject_end, $evalue_mant, $evalue_exp, $bit_score) = split "\t", $line;

        my $protein_data_bank_id = $self->getProteinDataBankId($query_id);

        my $aa_sequence_id = &GUS::Supported::Util::getAASequenceId($self, $subject_id);

        my $pdb_similarity = GUS::Model::ApiDB::PDBSimilarity->new({
            protein_data_bank_id              => $protein_data_bank_id,
            aa_sequence_id                    => $aa_sequence_id,
            pident                            => $pident,
            length                            => $length,
            mismatch                          => $mismatch,
            query_start                       => $query_start,
            query_end                         => $query_end,
            subject_start                     => $subject_start,
            subject_end                       => $subject_end,
            evalue_mant                       => $evalue_mant,
            evalue_exp                        => $evalue_exp,
            bit_score                         => $bit_score,
            external_database_release_id      => $extDbRlsId,
        });
        $pdb_similarity->submit();
        $self->undefPointerCache();
        $processed++;
    }

    close $fh;

    $self->log("$processed data lines parsed and inserted successfully from file: $diamondFile.");
}

sub getProteinDataBankId {
    my ($self, $sourceId) = @_;

    my $dbh = $self->getQueryHandle();
    my $stmt = $dbh->prepare("SELECT protein_data_bank_id FROM ApiDB.ProteinDataBank WHERE source_id = ?");
    $stmt->execute($sourceId);
    my ($protein_data_bank_id) = $stmt->fetchrow_array();

    return $protein_data_bank_id;
}

sub undoTables {
  qw(
    ApiDB.PDBSimilarity
  );
}

1;

