package ApiCommonData::Load::Plugin::InsertGenePhenotype;
@ISA = qw(GUS::PluginMgr::Plugin);

use strict;
use warnings;

use GUS::PluginMgr::Plugin;
use GUS::Model::ApiDB::GenePhenotype;
use GUS::Model::SRes::ExternalDatabase;
use GUS::Model::SRes::ExternalDatabaseRelease;

# ----------------------------------------------------------
# Load Arguments
# ----------------------------------------------------------

sub getArgsDeclaration {
  my $argsDeclaration  =
    [
     fileArg({ name => 'file',
         descr => 'tab delimited file with columns: gene_source_id, phenotype_stable_id, property, text_value',
         constraintFunc=> undef,
         reqd  => 1,
         isList => 0,
         mustExist => 1,
         format => 'Four column tab delimited file: gene_source_id, phenotype_stable_id, property, text_value',
       }),
     stringArg({ name => 'extDbRlsSpec',
         descr => 'external database release spec in format "name|version"',
         constraintFunc=> undef,
         reqd  => 1,
         isList => 0
       }),
    ];

  return $argsDeclaration;
}

# ----------------------------------------------------------
# Documentation
# ----------------------------------------------------------

sub getDocumentation {

  my $description = <<DESCR;
Plugin to load gene phenotype data into apidb.GenePhenotype table
DESCR

  my $purpose = <<PURPOSE;
Plugin to load gene phenotype data with long text values into apidb.GenePhenotype table
PURPOSE

  my $purposeBrief = <<PURPOSEBRIEF;
Plugin to load gene phenotype data into apidb.GenePhenotype table
PURPOSEBRIEF

  my $notes = <<NOTES;
This plugin loads gene phenotype data that supplements EDA tables.
Long text values are not handled well in EDA, so they are stored here.
NOTES

  my $tablesAffected = <<AFFECT;
ApiDB.GenePhenotype
AFFECT

  my $tablesDependedOn = <<TABD;
SRes.ExternalDatabaseRelease
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
  my $class = shift;
  my $self = {};
  bless($self, $class);

  my $documentation = &getDocumentation();

  my $args = &getArgsDeclaration();

  my $configuration = { requiredDbVersion => 4.0,
                        cvsRevision => '$Revision$',
                        name => ref($self),
                        argsDeclaration => $args,
                        documentation => $documentation
                      };

  $self->initialize($configuration);

  return $self;
}

sub run {
  my $self = shift;

  my $extDbSpec = $self->getArg('extDbRlsSpec');
  my $extDbRlsId = $self->getExtDbRlsId($extDbSpec) or die "Couldn't find source db: $extDbSpec\n";

  my $processed = 0;

  open(my $inputFile, '<', $self->getArg('file')) or die "Cannot open file: " . $self->getArg('file') . "\n";

  while(<$inputFile>) {
    chomp;
    next if /^##/;
    next if /^\s*$/;  # skip empty lines

    my($geneSourceId, $phenotypeStableId, $property, $textValue) = split /\t/, $_, 4;

    # Skip if required fields are missing
    unless($geneSourceId && $phenotypeStableId && $property) {
      $self->log("Skipping line with missing required fields: $_\n");
      next;
    }

    my $genePhenotype = GUS::Model::ApiDB::GenePhenotype->new({
      'gene_source_id'                => $geneSourceId,
      'phenotype_stable_id'           => $phenotypeStableId,
      'property'                      => $property,
      'text_value'                    => $textValue,
      'external_database_release_id'  => $extDbRlsId
    });

    $genePhenotype->submit();
    $self->undefPointerCache();
    $processed++;
  }

  close($inputFile);

  return "$processed gene phenotype records parsed and loaded";
}

sub undoTables {
  qw(
    ApiDB.GenePhenotype
  );
}

1;
