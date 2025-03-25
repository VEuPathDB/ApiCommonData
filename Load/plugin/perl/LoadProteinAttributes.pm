package ApiCommonData::Load::Plugin::LoadProteinAttributes;

use strict;
use warnings;

use GUS::PluginMgr::Plugin;
use base qw(GUS::PluginMgr::Plugin);

use GUS::Model::ApiDB::AaSequenceAttribute;

my $argsDeclaration =
  [
   stringArg({ name => 'extDbRlsName',
	       descr => 'External Database Release name of the AA sequences',
	       constraintFunc => undef,
	       isList => 0,
	       reqd => 1,
	     }),

   stringArg({ name => 'extDbRlsVer',
	       descr => 'External Database Release version of the AA sequences',
	       constraintFunc => undef,
	       isList => 0,
	       reqd => 1,
	     }),
   stringArg({ name => 'seqTable',
	       descr => 'where to find the target AA sequences in the form DoTs.tablename',
	       constraintFunc => undef,
	       isList => 0,
	       reqd => 1,
	     }),

   fileArg({name => 'inputFile',
         descr => 'tab file for with protein stats',
         constraintFunc=> undef,
         reqd  => 1,
         isList => 0,
         mustExist => 1,
         format         => '',
        }),

  ];


my $purposeBrief = <<PURPOSEBRIEF;
Loads molecular weights MinMax and IsoelectricPoint of amino acid sequences.
PURPOSEBRIEF

my $purpose = <<PLUGIN_PURPOSE;
Loads molecular weights  MinMax and IsoelectricPoint of amino acid sequences.
PLUGIN_PURPOSE

my $tablesAffected =
  [
   ['ApiDB.AASequenceAttribute' =>
    'min_molecular_weight,max_molecular_weight,isoelectric_point fields are updated if the entry exists, otherwise a new entry for the sequence is added with those fields filled in'
   ],
  ];

my $tablesDependedOn = [];

my $howToRestart = <<PLUGIN_RESTART;
PLUGIN_RESTART

my $failureCases = <<PLUGIN_FAILURE_CASES;
PLUGIN_FAILURE_CASES

my $notes = <<PLUGIN_NOTES;
PLUGIN_NOTES

my $documentation = { purposeBrief => $purposeBrief,
		      purpose => $purpose,
		      tablesAffected => $tablesAffected,
		      tablesDependedOn => $tablesDependedOn,
		      howToRestart => $howToRestart,
		      failureCases => $failureCases,
		      notes => $notes,
		    };

sub new {

  my $class = shift;
  $class = ref $class || $class;
  my $self = {};

  bless $self, $class;

  $self->initialize({ requiredDbVersion => 4.0,
		      cvsRevision =>  '$Revision$',
		      name => ref($self),
		      argsDeclaration   => $argsDeclaration,
		      documentation     => $documentation
		    });
  return $self;
}


sub run {

  my ($self) = @_;

  my $extDbRlsName = $self->getArg("extDbRlsName");
  my $extDbRlsVer = $self->getArg("extDbRlsVer");

  my $extDbRlsId = $self->getExtDbRlsId($extDbRlsName, $extDbRlsVer);

  unless ($extDbRlsId) {
    die "No such External Database Release / Version:\n $extDbRlsName / $extDbRlsVer\n";
  }

  my $inputFile = $self->getArg("inputFile");
  open(FILE, $inputFile) or die "Cannot open input file $inputFile for reading: $!";

  my $proteinIds = $self->getProteinIds($extDbRlsId);

  my $count = 0;

  while(<FILE>) {
    chomp;
    my ($id, $isoelectricPoint, $minWeight, $maxWeight) = split(/\t/, $_);

    my $aaSeqId = $proteinIds->{$id};

    my $newSeqAttr =
      GUS::Model::ApiDB::AaSequenceAttribute->new({aa_sequence_id => $aaSeqId,
                                                   min_molecular_weight => $minWeight,
                                                   max_molecular_weight => $maxWeight,
                                                   isoelectric_point => $isoelectricPoint,
                                                  });

    $newSeqAttr->submit();

    $count++;

    $self->undefPointerCache();

    if($count % 100 == 0) {
      $self->log("Inserted $count sequences.");
      $self->undefPointerCache();
    }

  }

  $self->log("Done inserted $count attributes");
}


sub getProteinIds {
  my ($self, $extDbRlsId) = @_;

  my $dbh = $self->getQueryHandle();

  my $sql = <<EOSQL;
  SELECT aa_sequence_id, source_id
  FROM   @{[$self->getArg('seqTable')]}
  WHERE  external_database_release_id = ?

EOSQL

  my $sth = $dbh->prepare($sql);

  $sth->execute($extDbRlsId);

  my %proteinIds;

  while (my ($aaSeqId, $sourceId) = $sth->fetchrow_array()) {
    $proteinIds{$sourceId} = $aaSeqId;
  }


  return \%proteinIds;
}


sub undoTables {
  my ($self) = @_;

  return ('ApiDB.AASequenceAttribute',
	 );
}

1;
