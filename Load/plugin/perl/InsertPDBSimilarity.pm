package ApiCommonData::Load::Plugin::InsertPDBSimilarity;
@ISA = qw(GUS::PluginMgr::Plugin);

use strict;
use GUS::PluginMgr::Plugin;
use GUS::Model::ApiDB::PDBSimilarity;
use GUS::Supported::Util;
use GUS::Model::SRes::ExternalDatabaseRelease;

sub getArgumentsDeclaration {
    my $argsDeclaration =
      [
       fileArg({name => 'inputFile',
                descr => 'DIAMOND BLAST tabular output file (format -f 6)',
                constraintFunc=> undef,
                reqd => 1,
                isList => 0,
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

    my $inputFile = $self->getArg('inputFile');
    my $extDbRlsId = $self->getExtDbRlsId($self->getArg('extDbRlsSpec'));
    my ($processed,$fh);
    my $proteinDataBankIDs = $self->preloadProteinDataBankIdCache();

    open($fh, "gunzip -c $inputFile |") || die "Can't open $inputFile for reading";

    while (my $line = <$fh>) {
        chomp $line;
        my ($query_id, $subject_id, $pident, $length, $alignedLength, $mismatch, $query_start, $query_end, $subject_start, $subject_end, $evalue, $bit_score) = split "\t", $line;

        my $protein_data_bank_id = $proteinDataBankIDs->{$subject_id};

        my $aa_sequence_id = &GUS::Supported::Util::getAASequenceId($self, $query_id);

	my ($evalue_mant, $evalue_exp) = split (/e/, $evalue);
	if ($evalue == 0) {$evalue_mant = 0; $evalue_exp = -1; }

        my $pdb_similarity = GUS::Model::ApiDB::PDBSimilarity->new({
            protein_data_bank_id              => $protein_data_bank_id,
            aa_sequence_id                    => $aa_sequence_id,
            pident                            => $pident,
            length                            => $alignedLength,
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
        $self->log("  Processed $processed data lines") if $processed % 10000 == 0;
    }

    close $fh;

    $self->log("$processed data lines parsed and inserted successfully from file: $inputFile.");
}

sub preloadProteinDataBankIdCache {
    my ($self) = @_;
    my $dbh = $self->getQueryHandle();
    my $stmt = $dbh->prepare("SELECT protein_data_bank_id,source_id FROM ApiDB.ProteinDataBank");
    $stmt->execute();

    my %cache;
    while (my ($protein_data_bank_id, $source_id) = $stmt->fetchrow_array()) {
        $cache{$source_id} = $protein_data_bank_id;
    }
    return \%cache;
}


sub undoTables {
  qw(
    ApiDB.PDBSimilarity
  );
}

1;

