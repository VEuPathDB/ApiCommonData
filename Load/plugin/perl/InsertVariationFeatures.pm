package ApiCommonData::Load::Plugin::InsertVariationFeatures;
use lib "$ENV{GUS_HOME}/lib/perl";
@ISA = qw(GUS::PluginMgr::Plugin);

use strict;
use warnings;

use GUS::PluginMgr::Plugin;
use GUS::Supported::GusConfig;
use ApiCommonData::Load::VariationLoader qw/
  variationFeatureColumns transcriptProductColumns variationEffectColumns
  transformVariationFeature transformTranscriptProduct transformVariationEffect
/;
use File::Temp qw/tempdir/;

sub getArgsDeclaration {
  return [
    fileArg({ name => 'inputDir', descr => 'mergeExperiments output dir with the .dat files',
              constraintFunc => undef, reqd => 1, isList => 0, mustExist => 1, format => 'directory' }),
    stringArg({ name => 'extDbRlsSpec', descr => 'ExternalDatabaseRelease spec, name|version',
                constraintFunc => undef, reqd => 1, isList => 0 }),
    stringArg({ name => 'organismAbbrev', descr => 'apidb.organism.abbrev to scope the transcript lookup',
                constraintFunc => undef, reqd => 1, isList => 0 }),
    stringArg({ name => 'targetSchema', descr => 'schema to load into (default apidb; tests use jbrestel)',
                constraintFunc => undef, reqd => 0, isList => 0, default => 'apidb' }),
  ];
}

sub getDocumentation {
  my $purpose = "Load mergeExperiments variationFeature.dat, transcript_product.dat, and snpeff.dat into ApiDB variation tables in a single transaction.";
  return {
    purpose          => $purpose,
    purposeBrief     => $purpose,
    notes            => "Undo via undoPreprocess (no row_alg_invocation_id on these tables).",
    tablesAffected   => "ApiDB.VariationFeature, ApiDB.VariationTranscriptProduct, ApiDB.VariationEffect",
    tablesDependedOn => "dots.Transcript, dots.ExternalNaSequence, apidb.Organism, sres.ExternalDatabaseRelease",
    howToRestart     => "Re-run; the load deletes existing rows for this external_database_release_id first.",
    failureCases     => "Unknown organismAbbrev; sequence id not in genome; transcript id unresolved for a coding effect.",
  };
}

sub new {
  my $class = shift;
  my $self = {};
  bless($self, $class);
  $self->initialize({
    requiredDbVersion => 4.0,
    cvsRevision       => '$Revision$',
    name              => ref($self),
    argsDeclaration   => getArgsDeclaration(),
    documentation     => getDocumentation(),
  });
  return $self;
}

sub run { die "not yet implemented\n"; }

1;
