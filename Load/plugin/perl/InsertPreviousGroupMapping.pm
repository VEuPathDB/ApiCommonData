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

    my $dbh = $self->getQueryHandle();

    open(my $data, '<', $fileName) || die "Could not open file $fileName: $!";
    while (my $line = <$data>) {
	my $rowCount++;
	chomp $line;
	my ($oldGroupId, $newGroupIdsLine) = split(/\t/, $line);
	my @newGroupIds = split(/,/, $newGroupIdsLine);
	foreach my $newGroupId (@newGroupIds) {
	    my $row = GUS::Model::ApiDB::GroupMapping->new({OLD_GROUP_ID => $oldGroupId,NEW_GROUP_ID => $newGroupId});
	    $row->submit();
	    $rowCount+=1;
	}
	$self->undefPointerCache();
	$groupCount+=1;
	if ($groupCount % 10000 == 0) {
	    print "Processed $groupCount groups\n";
	}
    }
 print "$rowCount rows added.\n"
}


sub undoTables {
    my ($self) = @_;

  return ('ApiDB.GroupMapping'
      );
}

1;
