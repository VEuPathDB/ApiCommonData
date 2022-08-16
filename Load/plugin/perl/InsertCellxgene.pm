package ApiCommonData::Load::Plugin::InsertCellxgene;
@ISA = qw(GUS::PluginMgr::Plugin);

use strict;
use warnings;

use GUS::PluginMgr::Plugin;

use GUS::Model::ApiDB::Cellxgene;

use GUS::Supported::Util;

# ----------------------------------------------------------
# Load Arguments
# ----------------------------------------------------------

sub getArgsDeclaration {
  my $argsDeclaration  =
    [
     fileArg({ name => 'file',
         descr => 'tab delimited file',
         constraintFunc=> undef,
         reqd  => 1,
         isList => 0,
         mustExist => 1,
         format => 'Two column tab delimited file in the order geneid, other_id',
       }),

   stringArg({name           => 'extDbRlsSpec',
            descr          => 'external database release spec',
            reqd           => 1,
            constraintFunc => undef,
            isList         => 0, }),


    ];

  return $argsDeclaration;
}

# ----------------------------------------------------------
# Documentation
# ----------------------------------------------------------

sub getDocumentation {

  my $description = <<DESCR;
Plugin to load gene mapping for cellxgene
DESCR

  my $purpose = <<PURPOSE;
Plugin to load gene mapping for cellxgene
PURPOSE

  my $purposeBrief = <<PURPOSEBRIEF;
Plugin to load gene mapping for cellxgene
PURPOSEBRIEF

  my $notes = <<NOTES;
NOTES

  my $tablesAffected = <<AFFECT;
ApiDB.Cellxgene
AFFECT

  my $tablesDependedOn = <<TABD;
DoTS.NAFeature, SRes.ExternalDatabaseRelease
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

  my $extDbRlsId = $self->getExtDbRlsId($self->getArg('extDbRlsSpec'));

  my ($processed, $skipped);

  open(FILE, $self->getArg('file'));

  <FILE>; # remove header

  while(<FILE>) {
    chomp;
    my($geneSourceId, $otherSourceId) = split(/\t/, $_);
   
    my $naFeatureId = GUS::Supported::Util::getGeneFeatureId($self, $geneSourceId);

    unless($naFeatureId) {
      $self->log("WARNING:  Could not find na feature id for gene:  $geneSourceId\n");
      $skipped++;
      next;
    }

    my $cellxgene = GUS::Model::ApiDB::Cellxgene->new({'na_feature_id' => $naFeatureId,
                                                       'source_id' => $otherSourceId,
                                                       'external_database_release_id' => $extDbReleaseId
                                                      });

    $cellxgene->submit();
    $self->undefPointerCache();
    $processed++;
  }

  return "$processed data lines parsed and loaded.  $skipped data lines skipped because we could not map gene id";
}

sub undoTables {
  qw(
    ApiDB.Cellxgene
  );
}

1;
