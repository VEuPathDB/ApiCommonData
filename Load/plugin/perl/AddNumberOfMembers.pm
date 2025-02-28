package ApiCommonData::Load::Plugin::AddNumberOfMembers;

@ISA = qw(GUS::PluginMgr::Plugin);

# ----------------------------------------------------------------------

use strict;
use GUS::PluginMgr::Plugin;
use FileHandle;

use GUS::Model::ApiDB::OrthologGroup;
use GUS::Model::ApiDB::OrthologGroupAaSequence;
use GUS::Model::SRes::ExternalDatabase;
use GUS::Model::SRes::ExternalDatabaseRelease;

my $argsDeclaration = [];

my $purpose = <<PURPOSE;
update ApiDB::OrthologGroup table.
PURPOSE

my $purposeBrief = <<PURPOSE_BRIEF;
update apidb.orthologgroup number_of_members.
PURPOSE_BRIEF

my $notes = <<NOTES;
NOTES

my $tablesAffected = <<TABLES_AFFECTED;
ApiDB.OrthologGroup
TABLES_AFFECTED

my $tablesDependedOn = <<TABLES_DEPENDED_ON;
ApiDB.OrthologGroup,
ApiDB.OrthologGroupAASequence
TABLES_DEPENDED_ON

my $howToRestart = <<RESTART;
The plugin can been restarted, update should only affect rows that have not been updated.
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

    my $unfinished = $self->getUnfinishedOrthologGroups();

    my ($numUpdatedGroups) = $self->processUnfinishedGroups($unfinished);

    $self->log("$numUpdatedGroups apidb.OrthologGroups rows updated\n");
}


sub getUnfinishedOrthologGroups {
  my ($self) = @_;

  $self->log ("Getting the ids of groups to add number_of_members\n");

  my @unfinished;

  my $sqlGetUnfinishedGroups = <<"EOF";
     SELECT group_id
     FROM apidb.OrthologGroup
EOF

  my $dbh = $self->getQueryHandle();

  my $sth = $dbh->prepareAndExecute($sqlGetUnfinishedGroups);

  while (my @row = $sth->fetchrow_array()) {
      push(@unfinished, $row[0]);
  }

  my $num = scalar @unfinished;

  $self->log ("   There are $num groups\n");

  return \@unfinished;
}

sub processUnfinishedGroups {
  my ($self, $unfinished) = @_;

  my $numUpdatedGroups=0;

  my $dbh = $self->getQueryHandle();

  my $sqlNumProteinsInGroup = <<"EOF";
  SELECT COUNT(aa_sequence_id), group_id
  FROM apidb.orthologgroupaasequence
  GROUP BY group_id
EOF

  my $sqlCoreNumProteinsInGroup = <<"EOF";
  SELECT COUNT(core.aa_sequence_id), group_id
  FROM (SELECT ogas.aa_sequence_id as aa_sequence_id, ogas.group_id as group_id
        FROM apidb.organism og, dots.externalaasequence deas, apidb.orthologgroupaasequence ogas 
        WHERE ogas.aa_sequence_id = deas.aa_sequence_id 
        AND deas.taxon_id = og.taxon_id 
        AND og.core_peripheral = 'core'
        UNION 
        SELECT ogas.aa_sequence_id as aa_sequence_id, ogas.group_id as group_id
        FROM apidb.organism og, dots.aasequence das, apidb.orthologgroupaasequence ogas 
        WHERE ogas.aa_sequence_id = das.aa_sequence_id 
        AND das.taxon_id = og.taxon_id 
        AND og.core_peripheral = 'core') as core
  GROUP BY group_id
EOF

  my $sqlPeripheralNumProteinsInGroup = <<"EOF";
  SELECT COUNT(peripheral.aa_sequence_id), group_id
  FROM (SELECT ogas.aa_sequence_id as aa_sequence_id, ogas.group_id as group_id
        FROM apidb.organism og, dots.externalaasequence deas, apidb.orthologgroupaasequence ogas 
        WHERE ogas.aa_sequence_id = deas.aa_sequence_id 
        AND deas.taxon_id = og.taxon_id 
        AND og.core_peripheral = 'peripheral'
        UNION 
        SELECT ogas.aa_sequence_id as aa_sequence_id, ogas.group_id as group_id
        FROM apidb.organism og, dots.aasequence das, apidb.orthologgroupaasequence ogas 
        WHERE ogas.aa_sequence_id = das.aa_sequence_id 
        AND das.taxon_id = og.taxon_id 
        AND og.core_peripheral = 'peripheral') as peripheral
  GROUP BY group_id
EOF

  $self->log("Calculating total group number of members");
  my %totalMembers;
  my $totalQry = $dbh->prepare($sqlNumProteinsInGroup);
  $totalQry->execute();
  while (my ($numMembers,$groupId) = $totalQry->fetchrow_array) {
    if ($numMembers == 0) {
	die "No proteins were found in group with id '$groupId'\n";
    }
    $totalMembers{$groupId}=$numMembers;
  }
  
  $self->log("Calculating core group number of members");
  my %coreMembers;
  my $coreQry = $dbh->prepare($sqlCoreNumProteinsInGroup);
  $coreQry->execute();
  while (my ($coreNumMembers,$coreGroupId) = $coreQry->fetchrow_array) {
    $coreMembers{$coreGroupId}=$coreNumMembers;
  }   

  $self->log("Calculating peripheral group number of members");
  my %peripheralMembers;
  my $peripheralQry = $dbh->prepare($sqlPeripheralNumProteinsInGroup);
  $peripheralQry->execute();
  while (my ($peripheralNumMembers,$peripheralGroupId) = $peripheralQry->fetchrow_array) {
    $peripheralMembers{$peripheralGroupId}=$peripheralNumMembers;
  }   

  foreach my $groupId (@{$unfinished}) {

    if ($coreMembers{$groupId} + $peripheralMembers{$groupId} != $totalMembers{$groupId}) {
	die "Number of core and peripheral members do not add up to total number of members for group '$groupId'\n";
    }

    my $orthologGroup = GUS::Model::ApiDB::OrthologGroup->new({'group_id'=>$groupId});
    $orthologGroup->retrieveFromDB();
    $orthologGroup->set('number_of_members', $totalMembers{$groupId});
    $orthologGroup->set('number_of_core_members', $coreMembers{$groupId});
    $orthologGroup->set('number_of_peripheral_members', $peripheralMembers{$groupId});
    my $submit = $orthologGroup->submit();
    $self->undefPointerCache();

    $numUpdatedGroups++;
  }

  return $numUpdatedGroups;
}

# ----------------------------------------------------------------------

sub undoTables {
  my ($self) = @_;
  return ();
}

sub undoPreprocess {
    my ($self, $dbh) = @_;

    my $sql = "UPDATE apidb.OrthologGroup SET number_of_members = -1";
    my $sql = "UPDATE apidb.OrthologGroup SET number_of_core_members = -1";
    my $sql = "UPDATE apidb.OrthologGroup SET number_of_peripheral_members = -1";

    my $sh = $dbh->prepareAndExecute($sql);
    $sh->finish();
}


1;
