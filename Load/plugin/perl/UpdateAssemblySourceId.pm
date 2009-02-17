package ApiCommonData::Load::Plugin::UpdateAssemblySourceId;
@ISA = qw(GUS::PluginMgr::Plugin);

use strict;

use GUS::PluginMgr::Plugin;

$| = 1;


# ---------------------------------------------------------------------------
# Load Arguments
# ---------------------------------------------------------------------------

sub getArgumentsDeclaration{
  my $argsDeclaration =
    [
     stringArg({name => 'taxonId',
		descr => 'taxonId',
		constraintFunc => undef,
		reqd => 0,
		isList => 0
	       }),
     stringArg({name => 'prefix',
		descr => 'prefix of updated soure_id',
		constraintFunc=> undef,
		reqd  => 1,
		isList => 0
	       }),
     stringArg({name => 'suffix',
		descr => 'suffix of updated source_id',
		constraintFunc=> undef,
		reqd  => 1,
		isList => 0
	       })
    ];
  return $argsDeclaration;
}

# ----------------------------------------------------------------------
# Documentation
# ----------------------------------------------------------------------

sub getDocumentation {
  my $purposeBrief = "Updates specified table's source_id field";

  my $purpose = "Update the specified table's source_id from prefix and suffix";

  my $tablesAffected = "";

  my $tablesDependedOn = [];

  my $howToRestart = "No extra steps required for restart";

  my $failureCases = "";

  my $notes = "the table to be updated must contain source_id and taxon_id attributes";

  my $documentation = {purpose=>$purpose, purposeBrief=>$purposeBrief, tablesAffected=>$tablesAffected, tablesDependedOn=>$tablesDependedOn, howToRestart=>$howToRestart, failureCases=>$failureCases,notes=>$notes};

  return $documentation;
}

# ----------------------------------------------------------------------
# create and initalize new plugin instance.
# ----------------------------------------------------------------------

sub new {
  my ($class) = @_;
  my $self = {};
  bless($self,$class);

  my $documentation = &getDocumentation();
  my $argumentDeclaration = &getArgumentsDeclaration();


  $self->initialize({requiredDbVersion => 3.5,
		     cvsRevision => '$Revision:  $',
                     name => ref($self),
                     revisionNotes => '',
                     argsDeclaration => $argumentDeclaration,
                     documentation => $documentation});

  return $self;
}

# ----------------------------------------------------------------------
# run method to do the work
# ----------------------------------------------------------------------

sub run {
  my ($self) = @_;

  $self->logAlgInvocationId();
  $self->logCommit();
  $self->logArgs();

  my $resultDescrip;

  if ($self->getArg('prefix') && $self->getArg('suffix') && $self->getArg('taxonId')){
      $resultDescrip = $self->updateSourceIds();
  }else {
    $self->userError("must supply prefix, suffix and taxonId.");
  }

  #$self->getQueryHandle()->commit();

  $resultDescrip.="Committing update\n";

  $self->setResultDescr($resultDescrip);
  $self->logData($resultDescrip);
}

sub updateSourceIds {
  my ($self) = @_;

  my $taxonId = $self->getArg('taxonId');

  my $prefix=$self->getArg('prefix');

  my $suffix=$self->getArg('suffix');

  my $updateSql = "update dots.assembly set source_id = '$prefix' || na_sequence_id || '$suffix' where taxon_id= '$taxonId'";

  my $dbh = $self->getQueryHandle();

  my $stmt = $dbh->prepareAndExecute($updateSql) || die "SQL failed: $updateSql\n";;

  my $resultDescrip="Updating source_id of dots.assembly with SQL: $updateSql\n";

  $self->undefPointerCache();

  return $resultDescrip;
}

sub undoUpdatedTables {
  my ($self) = @_;

  return ('DoTS.Asembly'
	 );
}

1;
