package ApiCommonData::Load::Plugin::InsertResidualOrthoGroups;

@ISA = qw(GUS::PluginMgr::Plugin);

# ----------------------------------------------------------------------

use strict;
use GUS::PluginMgr::Plugin;
use FileHandle;

use GUS::Model::ApiDB::OrthologGroup;
use GUS::Model::SRes::ExternalDatabase;
use GUS::Model::SRes::ExternalDatabaseRelease;

my $argsDeclaration =
[
    fileArg({name           => 'orthoFile',
            descr          => 'Ortholog Data (ortho.mcl). OrthologGroupName(gene and taxon count) followed by a colon then the ids for the members of the group',
            reqd           => 1,
            mustExist      => 1,
	    format         => 'OG2_1009: osa|ENS1222992 pfa|PF11_0844...',
            constraintFunc => undef,
            isList         => 0, }),

 stringArg({ descr => 'orthoVersion (7)',
	     name  => 'orthoVersion',
	     isList    => 0,
	     reqd  => 1,
	     constraintFunc => undef,
	   }),

 stringArg({ descr => 'Name of the External Database',
	     name  => 'extDbName',
	     isList    => 0,
	     reqd  => 1,
	     constraintFunc => undef,
	   }),


 stringArg({ descr => 'Version of the External Database Release',
	     name  => 'extDbVersion',
	     isList    => 0,
	     reqd  => 1,
	     constraintFunc => undef,
	   }),

];

my $purpose = <<PURPOSE;
Insert an ApiDB::OrthologGroup from an orthomcl groups file.
PURPOSE

my $purposeBrief = <<PURPOSE_BRIEF;
Load an orthoMCL group.
PURPOSE_BRIEF

my $notes = <<NOTES;
Need a script to create the mapping file.
NOTES

my $tablesAffected = <<TABLES_AFFECTED;
ApiDB.OrthologGroup
TABLES_AFFECTED

my $tablesDependedOn = <<TABLES_DEPENDED_ON;
Sres.ExternalDatabase,
Sres.ExternalDatabaseRelease
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

    my $orthoVersion = $self->getArg('orthoVersion');

    my $dbReleaseId = $self->getDbRls();

    open ORTHO_FILE, "<$orthologFile";
    my $groupCount = 0;
    my $lineCount = 0;
    while (<ORTHO_FILE>) {
        chomp;
        $lineCount++;

        if ($self->_parseGroup($_, $orthoVersion, $dbReleaseId)) {
            $groupCount++;
            if (($groupCount % 1000) == 0) {
                $self->log("$groupCount ortholog groups loaded.");
            }
        } else {
            $self->log("line cannot be parsed:\n#$lineCount '$_'.");
        }
    }
    $self->log("total $lineCount lines processed, and $groupCount groups loaded.");
}

sub _parseGroup {
    my ($self, $line, $orthoVersion, $dbReleaseId) = @_;

    # example line: OG2_1009: osa|ENS1222992 pfa|PF11_0844
    my $groupId;
    if ($line = /^(OGR\d+_\d+):\s.*/) {
        $groupId = $1;
    }
    else {
        die "Improper group file format";
    }
         
    # create a OrthlogGroup instance
    my $orthoGroup = GUS::Model::ApiDB::OrthologGroup->new({group_id => $groupId,
                                                            is_residual => 1,
                                                            external_database_release_id => $dbReleaseId,
                                                           });
    $orthoGroup->submit();
    $orthoGroup->undefPointerCache();
    return 1;
}

sub getDbRls {
  my ($self) = @_;

  my $name = $self->getArg('extDbName');

  my $version = $self->getArg('extDbVersion');

  my $externalDatabase = GUS::Model::SRes::ExternalDatabase->new({"name" => $name});
  $externalDatabase->retrieveFromDB();

  if (! $externalDatabase->getExternalDatabaseId()) {
    $externalDatabase->submit();
  }
  my $external_db_id = $externalDatabase->getExternalDatabaseId();

  my $externalDatabaseRel = GUS::Model::SRes::ExternalDatabaseRelease->new ({'external_database_id'=>$external_db_id,'version'=>$version});

  $externalDatabaseRel->retrieveFromDB();

  if (! $externalDatabaseRel->getExternalDatabaseReleaseId()) {
    $externalDatabaseRel->submit();
  }

  my $external_db_rel_id = $externalDatabaseRel->getExternalDatabaseReleaseId();

  return $external_db_rel_id;
}

# ----------------------------------------------------------------------

sub undoTables {
  my ($self) = @_;
  return ('ApiDB.OrthologGroup');
}

sub undoPreprocess {
  my ($self, $dbh, $rowAlgInvocationList) = @_;
  my $sql = "DELETE FROM apidb.orthologgroup WHERE IS_RESIDUAL = 1";
  my $sh = $dbh->prepare($sql); 
  $sh->execute();
  $sh->finish();
} 

1;
