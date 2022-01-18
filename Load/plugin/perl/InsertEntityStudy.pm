package ApiCommonData::Load::Plugin::InsertEntityStudy;

@ISA = qw(GUS::PluginMgr::Plugin ApiCommonData::Load::Plugin::ParameterizedSchema);
use GUS::PluginMgr::Plugin;
use ApiCommonData::Load::Plugin::ParameterizedSchema;
use strict;
use warnings;

my $argsDeclaration =
  [

   stringArg({name           => 'extDbRlsSpec',
            descr          => 'external database release spec',
            reqd           => 1,
            constraintFunc => undef,
            isList         => 0, }),
   stringArg({name           => 'stableId',
            descr          => 'Study stable ID',
            reqd           => 1,
            constraintFunc => undef,
            isList         => 0, }),
   stringArg({name           => 'schema',
            descr          => 'GUS::Model schema for entity tables',
            reqd           => 1,
            constraintFunc => undef,
            isList         => 0, }),
];



my $documentation = { purpose          => "",
                      purposeBrief     => "",
                      notes            => "",
                      tablesAffected   => "",
                      tablesDependedOn => "",
                      howToRestart     => "",
                      failureCases     => "" };

our @UNDO_TABLES =qw(
  Study
); ## undo is not run on ProcessType

my @REQUIRE_TABLES = qw(
  Study
);


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
  $self->{_require_tables} = \@REQUIRE_TABLES;
  $self->{_undo_tables} = \@UNDO_TABLES;
  return $self;
}

# ======================================================================
 
sub run {
  my ($self) = @_;
  $self->requireModelObjects();
  $self->resetUndoTables(); # for when logRowsInserted() is called after loading

  my $extDbRlsSpec = $self->getArg('extDbRlsSpec');
  my $extDbRlsId = $self->getExtDbRlsId($extDbRlsSpec);
  my $stableId = $self->getArg('stableId');

  my $gusStudy = $self->getGusModelClass('Study')->new({stable_id => $stableId, external_database_release_id => $extDbRlsId});
  $gusStudy->submit() unless ($gusStudy->retrieveFromDB());
}

1;
