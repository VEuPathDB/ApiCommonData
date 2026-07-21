package ApiCommonData::Load::Plugin::InsertGeneCoexpression;
use lib "$ENV{GUS_HOME}/lib/perl";
@ISA = qw(GUS::PluginMgr::Plugin);

use strict;
use warnings;

use GUS::PluginMgr::Plugin;
use GUS::Supported::GusConfig;
use ApiCommonData::Load::GeneCoexpressionLoader qw/
  geneCoexpressionColumns transformGeneCoexpression
/;
use File::Temp qw/tempdir/;

sub getArgsDeclaration {
  return [
    fileArg({ name => 'inputFile', descr => 'tab-delimited file: gene_id, associated_gene_id, coefficient (with header)',
              constraintFunc => undef, reqd => 1, isList => 0, mustExist => 1, format => 'file' }),
    stringArg({ name => 'extDbRlsSpec', descr => 'ExternalDatabaseRelease spec, name|version',
                constraintFunc => undef, reqd => 1, isList => 0 }),
    stringArg({ name => 'targetSchema', descr => 'schema to load into (default apidb)',
                constraintFunc => undef, reqd => 0, isList => 0, default => 'apidb' }),
  ];
}

sub getDocumentation {
  my $purpose = "Load gene coexpression pairs (gene_id, associated_gene_id, coefficient) into ApiDB.GeneCoexpression in a single transaction.";
  return {
    purpose          => $purpose,
    purposeBrief     => $purpose,
    notes            => "Undo via undoPreprocess (no row_alg_invocation_id on this table).",
    tablesAffected   => "ApiDB.GeneCoexpression",
    tablesDependedOn => "sres.ExternalDatabaseRelease",
    howToRestart     => "Re-run; the load deletes existing rows for this external_database_release_id first.",
    failureCases     => "Unresolvable extDbRlsSpec; malformed header; wrong field count; blank coefficient.",
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

1;
