package ApiCommonData::Load::Plugin::InsertMegaEntityGraph;

use base qw(ApiCommonData::Load::Plugin::InsertEntityGraph);

use GUS::PluginMgr::Plugin;
use ApiCommonData::Load::Plugin::InsertEntityGraph;
use strict;
use warnings;

use Encode;

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

my $SCHEMA = '__SCHEMA__'; # must be replaced with real schema name

sub new {
  my ($class) = @_;
  my $self = bless({},$class);

  $self->initialize({ requiredDbVersion => 4.0,
                      cvsRevision       => '$Revision$',
                      name              => ref($self),
                      argsDeclaration   => $argsDeclaration,
                      documentation     => $documentation});
  $self->{_require_tables} = \@ApiCommonData::Load::Plugin::InsertEntityGraph::REQUIRE_TABLES;
  $self->{_undo_tables} = \@ApiCommonData::Load::Plugin::InsertEntityGraph::UNDO_TABLES;

  return $self;
}


sub run {
  my ($self) = @_;

  $SCHEMA = $self->getArg('schema');

  $self->requireModelObjects();
  $self->resetUndoTables(); # for when logRowsInserted() is called after loading

  my ($subStudies, $maxAttrLength) = $self->getSubStudiesAndMaxAttributeLength();

  my $megaStudy = $self->createStudy($maxAttrLength);
  my $megaStudyEntityType = $self->loadEntityType($megaStudy);
  my $megaProcessType = $self->loadProcessType();
  $megaProcessType->submit();

  my $entityTypes = {};

  foreach my $subStudyId (keys %$subStudies) {
    my $subStudyStableId = $subStudies->{$subStudyId};
    my $attsJson = $self->makeStudyAttributes($subStudyId);

    my $subStudyEntityAttribute = $self->getGusModelClass('EntityAttributes')->new({stable_id => $subStudyStableId, atts => $attsJson});
    $subStudyEntityAttribute->setParent($megaStudyEntityType);

    my $subStudyEntityClassification = $self->getGusModelClass('EntityClassification')->new();
    $subStudyEntityClassification->setParent($subStudyEntityAttribute);
    $subStudyEntityClassification->setParent($megaStudyEntityType);

    $subStudyEntityAttribute->submit();

    $self->connectSubStudyToEntityGraph($subStudyId, $subStudyEntityAttribute, $megaProcessType);
    $self->addToEntityTypes($entityTypes, $subStudyId);
  }

  $self->loadEntityTypesAndAttributeUnits($megaStudy, $entityTypes);

  $self->logRowsInserted() if($self->getArg('commit'));

  $self->log("Added MEGA Study");

}

sub loadEntityTypesAndAttributeUnits {
  my ($self, $megaStudy, $entityTypes) = @_;

  foreach my $typeId (keys %$entityTypes) {
    my $name = $entityTypes->{$typeId}->{name};
    my $internalAbbrev = $entityTypes->{$typeId}->{internal_abbrev};

    my $gusEntityType = $self->getGusModelClass('EntityType')->new({type_id => $typeId, name => $name, internal_abbrev => $internalAbbrev});
    $gusEntityType->setParent($megaStudy);
    $gusEntityType->submit();

    my $subStudyEntityTypeIdsString = join(",", @{$entityTypes->{$typeId}->{internal_entity_type_ids}});

    $self->loadEntityClassificationsFromSubstudy($subStudyEntityTypeIdsString, $gusEntityType->getId());

    foreach my $attOntologyTermId (keys %{$entityTypes->{$typeId}->{units}}) {
      my $unitId = $entityTypes->{$typeId}->{units}->{$attOntologyTermId};

      my $gusAttributeUnit = $self->getGusModelClass('AttributeUnit')->new({ATTR_ONTOLOGY_TERM_ID => $attOntologyTermId, UNIT_ONTOLOGY_TERM_ID => $unitId});
      $gusAttributeUnit->setParent($gusEntityType);
      $gusAttributeUnit->submit();
    }

    $self->undefPointerCache();
  }
}

sub loadEntityClassificationsFromSubstudy {
  my ($self, $entityTypeIdsString, $megaEntityTypeId) = @_;

  my $dbh = $self->getQueryHandle();

  my $sql = "select ec.entity_attributes_id
             from ${SCHEMA}.entityclassification ec
             where ec.entity_type_id in ($entityTypeIdsString)";

  my $sh = $dbh->prepare($sql);
  $sh->execute();

  while(my ($entityAttributesId) = $sh->fetchrow_array()) {
    my $subStudyEntityClassification = $self->getGusModelClass('EntityClassification')->new();
    $subStudyEntityClassification->setEntityTypeId($megaEntityTypeId);
    $subStudyEntityClassification->setEntityAttributesId($entityAttributesId);
    $subStudyEntityClassification->submit();
    $self->undefPointerCache();
  }
  $sh->finish();
}

sub addToEntityTypes {
  my ($self, $entityTypes, $subStudyId) = @_;

  my $dbh = $self->getQueryHandle();

  my $sql = "select etg.PARENT_STABLE_ID, et.name, et.type_id, et.internal_abbrev, et.entity_type_id
             from ${SCHEMA}.entitytypegraph etg
                , ${SCHEMA}.entitytype et
             where etg.study_id = ?
             and etg.entity_type_id = et.entity_type_id";

  my $sh = $dbh->prepare($sql);
  $sh->execute($subStudyId);

  while(my ($parentStableId, $name, $typeId, $internalAbbrev, $entityTypeId) = $sh->fetchrow_array()) {

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
    push @{$entityTypes->{$typeId}->{internal_entity_type_ids}}, $entityTypeId;
  }

  $self->addUnitsToEntityTypes($entityTypes, $subStudyId);

  return $entityTypes;
}

sub addUnitsToEntityTypes {
  my ($self, $entityTypes, $subStudyId) = @_;

  my $dbh = $self->getQueryHandle();

  my $sql = "select et.type_id, au.ATTR_ONTOLOGY_TERM_ID, au.unit_ontology_term_id
             from ${SCHEMA}.attributeunit au
                , ${SCHEMA}.entitytype et
             where et.study_id = ?
             and et.entity_type_id = au.entity_type_id (+)";

  my $sh = $dbh->prepare($sql);
  $sh->execute($subStudyId);

  while(my ($typeId, $attOntologyTermId, $attUnitId) = $sh->fetchrow_array()) {
    next unless($attOntologyTermId);

    # TODO:   add a mechanism to pick a base unit where there are conflicts
    my $existingAttUnitId = $entityTypes->{$typeId}->{units}->{$attOntologyTermId};

    if($existingAttUnitId && $existingAttUnitId != $attUnitId) {
      $self->error("More than one unit found for typeId=$typeId and attribute ontology term id=$attOntologyTermId");
    }
    $entityTypes->{$typeId}->{units}->{$attOntologyTermId} = $attUnitId;
  }

}


sub connectSubStudyToEntityGraph {
  my ($self, $subStudyId, $subStudyEntityAttribute, $megaProcessType) = @_;

  my $dbh = $self->getQueryHandle();

  my $inEntityId = $subStudyEntityAttribute->getId();
  my $processTypeId = $megaProcessType->getId();

  my $sql = "select ec.entity_attributes_id
             from ${SCHEMA}.entitytypegraph etg
                , ${SCHEMA}.entityclassification ec
             where etg.study_id = ?
             and etg.parent_stable_id is null
             and etg.entity_type_id = ec.entity_type_id";

  my $sh = $dbh->prepare($sql);
  $sh->execute($subStudyId);

  while(my ($outEntityId) = $sh->fetchrow_array()) {
    
    my $gusProcessAttribute = $self->getGusModelClass('ProcessAttributes')->new({in_entity_id => $inEntityId, out_entity_id => $outEntityId, process_type_id => $processTypeId });
    $gusProcessAttribute->submit();

    $self->undefPointerCache();
  }

}


sub makeStudyAttributes {
  my ($self, $subStudyId) = @_;

  my $sql = "select ot.source_id, sc.value
from ${SCHEMA}.studycharacteristic sc
   , sres.ontologyterm ot
where sc.attribute_id = ot.ontology_term_id
and study_id = ?
order by ot.source_id, sc.value";

  my $dbh = $self->getQueryHandle();

  my $sh = $dbh->prepare($sql);
  $sh->execute($subStudyId);


  my $atts = {};
  while(my ($otSourceId, $value) = $sh->fetchrow_array()) {
    push @{$atts->{$otSourceId}}, $value;
  }

  return decode("UTF-8", encode_json($atts));
}


sub getSubStudiesAndMaxAttributeLength {
  my ($self) = @_;

  my $megaStudyStableId = $self->getArg('studyStableId');
  my $megaStudyYaml = $self->getArg('megaStudyYaml');
  my $megaStudyConfig = ApiCommonData::Load::StudyUtils::parseMegaStudyConfig($megaStudyYaml, $megaStudyStableId);

  my $subquery = "select s.study_id, s.stable_id, s.max_attr_length from ${SCHEMA}.study s where s.study_id is null";

  if(my $project = $megaStudyConfig->{project}) {
    $subquery = $subquery . "\nUNION\nselect s.study_id, s.stable_id, s.max_attr_length from ${SCHEMA}.study s, core.projectinfo p where s.row_project_id = p.project_id and p.name = '$project'";
  }
  if(my $substudies = $megaStudyConfig->{studies}) {
    my $substudiesString = join(",", map { "'" . $_ . "'" } @$substudies);
      
    $subquery = $subquery . "\nUNION\nselect s.study_id, s.stable_id, s.max_attr_length from ${SCHEMA}.study s where s.stable_id in ($substudiesString)";
  }

  my $maxAttLengthSql = "select max(max_attr_length) from ($subquery)";
  my $dbh = $self->getQueryHandle();
  my $sh = $dbh->prepare($maxAttLengthSql);
  $sh->execute();
  my ($maxAttrLength) = $sh->fetchrow_array();
  $sh->finish();

  my $sql = "select study_id, stable_id from ($subquery)";

  my $subStudies  = $self->sqlAsDictionary( Sql  => $sql );

  return($subStudies, $maxAttrLength);
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
  my ($self, $megaStudy) = @_;

  my $name = "Study";
  my $typeStableId = "EUPATH_0000605"; # summary information of investigation

  my @ontologyTerms = $self->sqlAsArray( Sql  => "select ontology_term_id from sres.ontologyterm where source_id = '$typeStableId'");
  my $typeId = $ontologyTerms[0];

  unless($typeId) {
    $self->error("Could not find ontologyterm for source_id: $typeStableId");
  }
  
  my $megaStudyEntityType = $self->getGusModelClass('EntityType')->new({name => $name, type_id => $typeId, internal_abbrev => $name});

  $megaStudyEntityType->setParent($megaStudy);

  return $megaStudyEntityType;
}

sub createStudy {
  my ($self, $maxAttrLength) = @_;

  my $extDbRlsSpec = $self->getArg('extDbRlsSpec');
  my $extDbRlsId = $self->getExtDbRlsId($extDbRlsSpec);
  my $studyStableId = $self->getArg('studyStableId');

  my $internalAbbrev = $studyStableId;
  $internalAbbrev =~ s/-/_/g; #clean name/id for use in oracle table name

  my $megaStudy = $self->getGusModelClass('Study')->new({stable_id => $studyStableId,
                                                         external_database_release_id => $extDbRlsId,
                                                         internal_abbrev => $internalAbbrev,
                                                         max_attr_length => $maxAttrLength
                                                        });

  return $megaStudy;
}


1;
