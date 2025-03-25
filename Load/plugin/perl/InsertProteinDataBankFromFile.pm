package ApiCommonData::Load::Plugin::InsertProteinDataBankFromFile;
@ISA = qw(GUS::PluginMgr::Plugin);
use strict;
use GUS::PluginMgr::Plugin;
use GUS::Model::ApiDB::ProteinDataBank;
use GUS::Supported::Util;
use GUS::Model::SRes::TaxonName;

sub getArgumentsDeclaration {
    my $argsDeclaration =
      [
       fileArg({name => 'inputFile',
                descr => 'Tab-delimited file with source_id, description, and taxon name',
                constraintFunc=> undef,
                reqd => 1,
                isList => 0,
                mustExist => 1,
                format => 'Text'
               }),
       stringArg({name           => 'extDbSpec',
                descr          => 'external database release spec',
                constraintFunc=> undef,
                reqd           => 1,
                isList => 0,
               }),
      ];
    return $argsDeclaration;
}

sub getDocumentation {
  my $description = <<DESCR;
Inserts records into ApiDB.ProteinDataBank from a tab-delimited file
DESCR

  my $purpose = <<PURPOSE;
Inserts records into ApiDB.ProteinDataBank from a tab-delimited file
PURPOSE

  my $purposeBrief = <<PURPOSEBRIEF;
Inserts records into ApiDB.ProteinDataBank from a tab-delimited file
PURPOSEBRIEF

  my $notes = <<NOTES;
NOTES

  my $tablesAffected = <<AFFECT;
ApiDB.ProteinDataBank
AFFECT

  my $tablesDependedOn = <<TABD;
SRes.TaxonName, SRes.ExternalDatabaseRelease
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

    my $file = $self->getArg('inputFile');
    my $extDbRlsId = $self->getExtDbRlsId($self->getArg('extDbSpec'));
    my $taxon_cache = $self->preloadTaxonCache();
    my $processed = 0;

    open my $fh, '<', $file or $self->userError("Unable to open file: $file");

    while (my $line = <$fh>) {
        chomp $line;
        my ($source_id, $description, $taxon_name) = split "\t", $line;
        my $taxon_id = $taxon_cache->{lc($taxon_name)};

        if (!defined $taxon_id) {
          $taxon_id = $taxon_cache->{'unknown'};
        }

        my $protein_data_bank = GUS::Model::ApiDB::ProteinDataBank->new({
            source_id => $source_id,
            description => $description,
            taxon_id => $taxon_id,
            external_database_release_id => $extDbRlsId,
        });
        $protein_data_bank->submit();
        $self->undefPointerCache();
        $processed++;
        $self->log("  Processed $processed data lines") if $processed % 10000 == 0;
    }

    close $fh;

    $self->log("$processed data lines parsed and inserted successfully from file: $file.");
}

sub preloadTaxonCache {
    my ($self) = @_;
    my $dbh = $self->getQueryHandle();
    my $stmt = $dbh->prepare("SELECT lower(name) AS name, taxon_id FROM sres.taxonname");
    $stmt->execute();

    my %cache;
    while (my ($name, $taxon_id) = $stmt->fetchrow_array()) {
        $cache{$name} = $taxon_id;
    }
    return \%cache;
}


sub undoTables {
  qw(
    ApiDB.ProteinDataBank
  );
}
1;

