package ApiCommonData::Load::Plugin::InsertSimilarOrthologGroups;

@ISA = qw(GUS::PluginMgr::Plugin);

# ----------------------------------------------------------------------

use strict;
use GUS::PluginMgr::Plugin;
use FileHandle;

use GUS::Model::ApiDB::SimilarOrthologGroup;

my $argsDeclaration =
[
    fileArg({name           => 'similarGroups',
            descr          => 'File containing groups and the names of orthers groups that shared a significant blast results between the groups best representative sequences',
            reqd           => 1,
            mustExist      => 1,
            format         => 'OG7_0001265 OG7_0000323 2.03e-19',
            constraintFunc => undef,
            isList         => 0, }),

];

my $purpose = <<PURPOSE;
Insert an ApiDB::SimilarOrthologGroups from an similar groups file.
PURPOSE

my $purposeBrief = <<PURPOSE_BRIEF;
Load orthoMCL similar groups.
PURPOSE_BRIEF

my $notes = <<NOTES;
Need a script to create the mapping file.
NOTES

my $tablesAffected = <<TABLES_AFFECTED;
ApiDB.SimilarOrthologGroups
TABLES_AFFECTED

my $tablesDependedOn = <<TABLES_DEPENDED_ON;
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

    my $dbh = $self->getQueryHandle();
    my %validGroupIds;
    my $groupQuery = $dbh->prepare("SELECT group_id FROM apidb.orthologgroup");
    $groupQuery->execute();
    while (my ($gId) = $groupQuery->fetchrow_array()) {
        $validGroupIds{$gId} = 1;
    }

    my $similarGroupsFile = $self->getArg('similarGroups');

    open GROUPS_FILE, "<$similarGroupsFile";
    my $lineCount = 0;
    my $skippedCount = 0;
    while (<GROUPS_FILE>) {
        chomp;
        $lineCount++;

        my ($groupId,$similarGroup,$evalue) = split(/\t/,$_);

        unless ($validGroupIds{$groupId} && $validGroupIds{$similarGroup}) {
            $self->log("Skipping similar group pair $groupId / $similarGroup: one or both not found in apidb.orthologgroup");
            $skippedCount++;
            next;
        }

        my $similarOrthologGroup = GUS::Model::ApiDB::SimilarOrthologGroup->new({group_id => $groupId,
                                                                                 similar_group_id => $similarGroup,
                                                                                 evalue => $evalue
                                                                                });
        $similarOrthologGroup->submit();
        $similarOrthologGroup->undefPointerCache();
    }
    $self->log("total $lineCount lines processed, $skippedCount skipped.");
}

# ----------------------------------------------------------------------

sub undoTables {
  my ($self) = @_;
  return ('ApiDB.SimilarOrthologGroup');
}

1;
