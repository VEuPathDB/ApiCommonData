package ApiCommonData::Load::Plugin::InsertPreviousGroupMapping;

@ISA = qw(GUS::PluginMgr::Plugin);

use GUS::Model::ApiDB::GroupMapping;
use GUS::PluginMgr::Plugin;
use strict;
# ----------------------------------------------------------------------
my $argsDeclaration =
  [
   fileArg({name           => 'mappingFile',
            descr          => 'file for the mapping data',
            reqd           => 1,
            mustExist      => 1,
            format         => '',
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

    my $fileName = $self->getArg('mappingFile');
    my $rowCount = 0;
    my $skippedCount = 0;
    my $groupCount = 0;

    $self->getDb()->manageTransaction(0, 'begin');

    open(my $data, '<', $fileName) || die "Could not open file $fileName: $!";
    while (my $line = <$data>) {
	chomp $line;

        # Format is like "OG8_0000000    OG6_0000000:110/120 OG7_0000001:10/120"
        # First column is the current group (in apidb.orthologgroup); remaining columns are previous/old groups
	my ($currentGroupId, $prevGroupIdsLine) = split(/\t/, $line);
	my @prevGroupIds = split(/\s/, $prevGroupIdsLine);

        unless ($validGroupIds{$currentGroupId}) {
            $self->log("Skipping mapping for $currentGroupId: not found in apidb.orthologgroup");
            $skippedCount++;
            next;
        }

	foreach my $prevGroupIdInfo (@prevGroupIds) {

	    if ($prevGroupIdInfo =~ /(OG\S+):(\d+)\/(\d+)/) {
                # Previous (old) group Id
		my $prevGroupId = $1;
                # Number of sequences from old group that are found in the current group
		my $overlapCount = $2;
                # Number of sequences in the old group
		my $groupSize = $3;

                my $row = GUS::Model::ApiDB::GroupMapping->new({OLD_GROUP_ID => $prevGroupId, NEW_GROUP_ID => $currentGroupId, OVERLAP_COUNT => $overlapCount, GROUP_SIZE => $groupSize});
		$row->submit(undef, 1);
		$row->undefPointerCache();

		if(++$rowCount % 1000 == 0) {
		    $self->getDb()->manageTransaction(0, 'commit');
		    $self->getDb()->manageTransaction(0, 'begin');
		}

	    }
	    else {
		die "Improper previous group info format: $prevGroupIdInfo\n";
	    }
	}

	$groupCount+=1;
	if ($groupCount % 10000 == 0) {
     	    print "Processed $groupCount groups\n";
	}
    }
    $self->getDb()->manageTransaction(0, 'commit');
    print "$rowCount rows added, $skippedCount rows skipped.\n"
}

sub undoTables {
    my ($self) = @_;

  return ('ApiDB.GroupMapping'
      );
}

1;
