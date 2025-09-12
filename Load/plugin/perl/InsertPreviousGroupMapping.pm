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

    my $fileName = $self->getArg('mappingFile');
    my $rowCount = 0;
    my $groupCount = 0;

    $self->getDb()->manageTransaction(0, 'begin');

    open(my $data, '<', $fileName) || die "Could not open file $fileName: $!";
    while (my $line = <$data>) {
	chomp $line;

        # Format is like "OG6_0000000    OG7_0000000:110/120 OG7_0000001:10/120"
	my ($oldGroupId, $newGroupIdsLine) = split(/\t/, $line);
	my @newGroupIds = split(/\s/, $newGroupIdsLine);
	foreach my $newGroupIdInfo (@newGroupIds) {

	    if ($newGroupIdInfo =~ /(OG\S+):(\d+)\/(\d+)/) {
                # New group Id
		my $newGroupId = $1;
                # Number of sequences from old group that are found in the new group
		my $overlapCount = $2;
                # Number of sequences in the old group
		my $groupSize = $3;

                my $row = GUS::Model::ApiDB::GroupMapping->new({OLD_GROUP_ID => $oldGroupId,NEW_GROUP_ID => $newGroupId,OVERLAP_COUNT => $overlapCount, GROUP_SIZE => $groupSize});
		$row->submit(undef, 1);
		$row->undefPointerCache();

		if(($count++ % 1000) == 0) {
		    $self->getDb()->manageTransaction(0, 'commit');
		    $self->getDb()->manageTransaction(0, 'begin');
		}

	    }
	    else {
		die "Improper new group info format: $newGroupIdInfo\n";
	    }
	}

	$groupCount+=1;
	if ($groupCount % 10000 == 0) {
     	    print "Processed $groupCount groups\n";
	}
    }
    $self->getDb()->manageTransaction(0, 'commit');
    print "$rowCount rows added.\n"
}

sub undoTables {
    my ($self) = @_;

  return ('ApiDB.GroupMapping'
      );
}

1;
