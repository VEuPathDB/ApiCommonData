package ApiCommonData::Load::Plugin::InsertMegaEntityGraph;

use base qw(ApiCommonData::Load::Plugin::InsertEntityGraph);

use GUS::PluginMgr::Plugin;

use strict;
use warnings;

use ApiCommonData::Load::StudyUtils qw(parseMegaStudyConfig);

use YAML::Tiny;
use JSON;
use POSIX qw/strftime/;


use Data::Dumper;

my $argsDeclaration =
  [

   stringArg({name           => 'extDbRlsSpec',
            descr          => 'external database release spec',
            reqd           => 1,
            constraintFunc => undef,
            isList         => 0, }),

   stringArg({name           => 'studyStableId',
            descr          => 'name the mega study',
            reqd           => 1,
            constraintFunc => undef,
            isList         => 0, }),

   fileArg({name           => 'megaStudyYaml',
            descr          => 'optional yaml file which specifies which studies will be grouped (union) into mega study.  study stable id is for the mega study.  Specify a project (Core.Projectinfo.name) which will get all studies for a project AND/OR list study stable_ids ',
            reqd           => 0,
        mustExist      => 1,
        format         => '',
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

# ----------------------------------------------------------------------
our @UNDO_TABLES =qw(
  ProcessAttributes
  EntityAttributes
  AttributeUnit
  ProcessTypeComponent
  EntityType
  Study
); ## undo is not run on ProcessType

my @REQUIRE_TABLES = qw(
  Study
  EntityAttributes
  EntityType
  AttributeUnit
  ProcessAttributes
  ProcessType
  ProcessTypeComponent
);

# ----------------------------------------------------------------------

my $SCHEMA = '__SCHEMA__'; # must be replaced with real schema name

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


sub run {
  my ($self) = @_;

  $SCHEMA = $self->getArg('schema');

  $self->requireModelObjects();
  $self->resetUndoTables(); # for when logRowsInserted() is called after loading

  my $gusStudy = $self->loadStudy();
  my $gusEntityType = $self->loadEntityType($gusStudy);
  my $gusProcessType = $self->loadProcessType();
  $gusProcessType->submit();

  my $subStudies = $self->getSubStudies();

  my $entityTypes = {};

  foreach my $studyId (keys %$subStudies) {
    my $studyStableId = $subStudies->{$studyId};
    my $attsJson = $self->makeStudyAttributes($studyId);

    my $gusEntityAttribute = $self->getGusModelClass('EntityAttributes')->new({stable_id => $studyStableId, atts => $attsJson});
    $gusEntityAttribute->setParent($gusEntityType);
    $gusEntityAttribute->submit();

    $self->connectSubStudyToEntityGraph($studyId, $gusEntityAttribute, $gusProcessType);
    $self->addToEntityTypes($entityTypes, $studyId);
  }

  $self->loadEntityTypes($gusStudy, $entityTypes);

  $self->logRowsInserted() if($self->getArg('commit'));

  $self->log("Added MEGA Study");

}

sub loadEntityTypes {
  my ($self, $gusStudy, $entityTypes) = @_;

  foreach my $typeId (keys %$entityTypes) {
    my $name = $entityTypes->{$typeId}->{name};
    my $internalAbbrev = $entityTypes->{$typeId}->{internal_abbrev};

    my $gusEntityType = $self->getGusModelClass('EntityType')->new({type_id => $typeId, name => $name, internal_abbrev => $internalAbbrev});

    $gusEntityType->setParent($gusStudy);
    $gusEntityType->submit();

    $self->undefPointerCache();
  }
}

sub addToEntityTypes {
  my ($self, $entityTypes, $studyId) = @_;

  my $dbh = $self->getQueryHandle();

  my $sql = "select etg.PARENT_STABLE_ID, et.name, et.type_id, et.internal_abbrev
             from ${SCHEMA}.entitytypegraph etg
                , ${SCHEMA}.entitytype et
             where etg.study_id = ?
             and etg.entity_type_id = et.entity_type_id";

  my $sh = $dbh->prepare($sql);
  $sh->execute($studyId);


  while(my ($parentStableId, $name, $typeId, $internalAbbrev) = $sh->fetchrow_array()) {

    # if we've seen this entity type before check the parent is the same. 
    # an entity type can only have one parent type
    if($parentStableId && $entityTypes->{$typeId} && $entityTypes->{$typeId}->{parent_stable_id}) {
      my $prevParent = $entityTypes->{$typeId}->{parent_stable_id};
      unless($parentStableId eq $prevParent) {
        $self->error("Type ID [$typeId] can only have one parent.  Found $prevParent and $parentStableId");
      }
    }

    $entityTypes->{$typeId}->{parent_stable_id} = $parentStableId if($parentStableId);
    $entityTypes->{$typeId}->{name} = $name;
    $entityTypes->{$typeId}->{internal_abbrev} = $internalAbbrev;
  }
  return $entityTypes;
}

sub connectSubStudyToEntityGraph {
  my ($self, $studyId, $gusEntityAttribute, $gusProcessType) = @_;

  my $dbh = $self->getQueryHandle();

  my $inEntityId = $gusEntityAttribute->getId();
  my $processTypeId = $gusProcessType->getId();

  my $sql = "select ea.entity_attributes_id
             from ${SCHEMA}.entitytypegraph etg
                , ${SCHEMA}.entityattributes ea
             where etg.study_id = ?
             and etg.parent_stable_id is null
             and etg.entity_type_id = ea.entity_type_id";

  my $sh = $dbh->prepare($sql);
  $sh->execute($studyId);

  while(my ($outEntityId) = $sh->fetchrow_array()) {
    
    my $gusProcessAttribute = $self->getGusModelClass('ProcessAttributes')->new({in_entity_id => $inEntityId, out_entity_id => $outEntityId, process_type_id => $processTypeId });
    $gusProcessAttribute->submit();

    $self->undefPointerCache();
  }

}


sub makeStudyAttributes {
  my ($self, $studyId) = @_;

  my $sql = "select ot.source_id, sc.value
from ${SCHEMA}.studycharacteristic sc
   , sres.ontologyterm ot
where sc.attribute_id = ot.ontology_term_id
and study_id = ?
order by ot.source_id, sc.value";

  my $dbh = $self->getQueryHandle();

  my $sh = $dbh->prepare($sql);
  $sh->execute($studyId);


  my $atts = {};
  while(my ($otSourceId, $value) = $sh->fetchrow_array()) {
    push @{$atts->{$otSourceId}}, $value;
  }

  return encode_json($atts);
}


sub getSubStudies {
  my ($self) = @_;

  my $megaStudyStableId = $self->getArg('studyStableId');
  my $megaStudyYaml = $self->getArg('megaStudyYaml');
  my $megaStudyConfig = ApiCommonData::Load::StudyUtils::parseMegaStudyConfig($megaStudyYaml, $megaStudyStableId);

  my $subquery = "select s.study_id, s.stable_id from ${SCHEMA}.study s where s.study_id is null";

  if(my $project = $megaStudyConfig->{project}) {
    $subquery = $subquery . "\nUNION\nselect s.study_id, s.stable_id from ${SCHEMA}.study s, core.projectinfo p where s.row_project_id = p.project_id and p.name = '$project'";
  }
  if(my $substudies = $megaStudyConfig->{studies}) {
    my $substudiesString = join(",", map { "'" . $_ . "'" } @$substudies);
      
    $subquery = $subquery . "\nUNION\nselect s.study_id, s.stable_id from ${SCHEMA}.study s where s.stable_id in ($substudiesString)";
  }

  my $sql = "select * from ($subquery)";

  return $self->sqlAsDictionary( Sql  => $sql );
}

sub loadProcessType {
  my ($self) = @_;

  my $name = "Study";
  my $typeStableId = "OBI_0000066";

  my @ontologyTerms = $self->sqlAsArray( Sql  => "select ontology_term_id from sres.ontologyterm where source_id = '$typeStableId'");
  my $typeId = $ontologyTerms[0];

  unless($typeId) {
    $self->error("Could not find ontologyterm for source_id: $typeStableId");
  }
  
  return $self->getGusModelClass('ProcessType')->new({name => $name, type_id => $typeId});
}



sub loadEntityType {
  my ($self, $gusStudy) = @_;

  my $name = "Study";
  my $typeStableId = "EUPATH_0000605"; # summary information of investigation

  my @ontologyTerms = $self->sqlAsArray( Sql  => "select ontology_term_id from sres.ontologyterm where source_id = '$typeStableId'");
  my $typeId = $ontologyTerms[0];

  unless($typeId) {
    $self->error("Could not find ontologyterm for source_id: $typeStableId");
  }
  
  my $gusEntityType = $self->getGusModelClass('EntityType')->new({name => $name, type_id => $typeId, internal_abbrev => $name});

  $gusEntityType->setParent($gusStudy);

  return $gusEntityType;
}

sub loadStudy {
  my ($self) = @_;

  my $extDbRlsSpec = $self->getArg('extDbRlsSpec');
  my $extDbRlsId = $self->getExtDbRlsId($extDbRlsSpec);
  my $studyStableId = $self->getArg('studyStableId');

  my $internalAbbrev = $studyStableId;
  $internalAbbrev =~ s/-/_/g; #clean name/id for use in oracle table name

  my $gusStudy = $self->getGusModelClass('Study')->new({stable_id => $studyStableId, external_database_release_id => $extDbRlsId, internal_abbrev => $internalAbbrev});

  return $gusStudy;
}


1;
