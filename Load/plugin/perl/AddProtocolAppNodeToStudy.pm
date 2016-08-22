package ApiCommonData::Load::Plugin::AddProtocolAppNodeToStudy;
@ISA = qw(GUS::PluginMgr::Plugin);

use strict;
use GUS::PluginMgr::Plugin;

use GUS::Model::Study::Study;
use GUS::Model::Study::StudyLink;
use GUS::Model::Study::ProtocolAppNode;
use GUS::Model::SRes::TaxonName;

my $argsDeclaration =
[
   stringArg({name => 'type',
	      descr => 'Ontology term for Type of appnode',
	      constraintFunc=> undef,
	      reqd  => 0,
	      isList => 0
	     }),
   stringArg({name => 'subtype',
	      descr => 'Ontology term for subtype of appnode;  no sense in having this unless you have a type',
	      constraintFunc=> undef,
	      reqd  => 0,
	      isList => 0
	     }),

   stringArg({name => 'name',
	      descr => 'Name of the app node',
	      constraintFunc=> undef,
	      reqd  => 1,
	      isList => 0
	     }),

   stringArg({name => 'description',
	      descr => 'describe the protocolappnode',
	      constraintFunc=> undef,
	      reqd  => 0,
	      isList => 0
	     }),

   stringArg({name => 'uri',
	      descr => 'uri for the  protocolappnode',
	      constraintFunc=> undef,
	      reqd  => 0,
	      isList => 0
	     }),

   stringArg({name => 'extDbSpec',
	      descr => 'External database from whence this data came|version',
	      constraintFunc=> undef,
	      reqd  => 0,
	      isList => 0
	     }),

   stringArg({name => 'sourceId',
	      descr => 'sourceId for the  protocolappnode',
	      constraintFunc=> undef,
	      reqd  => 0,
	      isList => 0
	     }),


   stringArg({name => 'taxonName',
	      descr => 'taxonName for the  protocolappnode;  should match sres.taxonname row',
	      constraintFunc=> undef,
	      reqd  => 0,
	      isList => 0
	     }),


   stringArg({name => 'studyName',
	      descr => 'Name of the Study;  Will be added if it does not already exist',
	      constraintFunc=> undef,
	      reqd  => 1,
	      isList => 0
	     }),
];

my $purpose = <<PURPOSE;
Insert a protocol app node and link to a study
PURPOSE

my $purposeBrief = <<PURPOSE_BRIEF;
Insert a protocol app node and link to a study
PURPOSE_BRIEF

my $notes = <<NOTES;
NOTES

my $tablesAffected = <<TABLES_AFFECTED;
TABLES_AFFECTED

my $tablesDependedOn = <<TABLES_DEPENDED_ON;
TABLES_DEPENDED_ON

  my $howToRestart = <<RESTART;
There are no restart facilities for this plugin
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

sub run {
  my ($self) = @_;

  my $extDbRlsId;
  if(my $extDbSpec = $self->getArg('extDbSpec')) {
    $extDbRlsId = $self->getExtDbRlsId($extDbSpec);
  }

  my $studyName = $self->getArg('studyName');
  my $gusStudy = GUS::Model::Study::Study->new({name => $studyName});
  unless($gusStudy->retrieveFromDB()) {
    $self->userError("Study $studyName does not exist");
  }

  my $name = $self->getArg('name');
  my $description = $self->getArg('description');
  my $uri = $self->getArg('uri');
  my $sourceId = $self->getArg('sourceId');

  my $taxonId;
  if(my $taxonName = $self->getArg('taxonName')) {
    my $gusTaxonName = GUS::Model::SRes::TaxonName->new({name => $taxonName});
    $self->userError("Taxon name $taxonName does not exist in SRes::TaxonName") unless($gusTaxonName->retrieveFromDB());
    $taxonId = $gusTaxonName->getTaxonId();
  }

  my ($typeId, $subtypeId);
  if(my $type = $self->getArg('type')) {
    my @typeIds = $self->sqlAsArray(Sql => "select ontology_term_id from sres.ontologyterm where name = '$type' ");
    $self->userError("type $type does not resolve to exactly one ontologyterm") unless(scalar @typeIds == 1);
    $typeId = $typeIds[0];
  }
  if(my $subtype = $self->getArg('subtype')) {
    my @subtypeIds = $self->sqlAsArray(Sql => "select ontology_term_id from sres.ontologyterm where name = '$subtype' ");
    $self->userError("subtype $subtype does not resolve to exactly one ontologyterm") unless(scalar @subtypeIds == 1);
    $subtypeId = $subtypeIds[0];
  }

  my $pan = GUS::Model::Study::ProtocolAppNode->new({name => $name});
  $pan->setTypeId($typeId) if($typeId);
  $pan->setDescription($description) if($description);
  $pan->setUri($uri) if($uri);
  $pan->setExternalDatabaseReleaseId($extDbRlsId) if($extDbRlsId);
  $pan->setSourceId($sourceId) if($sourceId);
  $pan->setSubtypeId($subtypeId) if($subtypeId);
  $pan->setTaxonId($taxonId) if($taxonId);

  # Try to retrieve from DB
  $pan->retrieveFromDB();

  my $studyLink = GUS::Model::Study::StudyLink->new();
  $studyLink->setParent($gusStudy);
  $studyLink->setParent($pan);

  $pan->submit();

  return("Inserted one row in Study::ProtocolAppNode");
}

sub undoTables {
  my ($self) = @_;

  return ('Study.StudyLink',
          'Study.ProtocolAppNode',
	 );
}

1;
