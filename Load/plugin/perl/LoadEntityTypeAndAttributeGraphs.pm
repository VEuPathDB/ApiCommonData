package ApiCommonData::Load::Plugin::LoadEntityTypeAndAttributeGraphs;

@ISA = qw(GUS::PluginMgr::Plugin ApiCommonData::Load::Plugin::ParameterizedSchema);
use strict;
use warnings;
use GUS::PluginMgr::Plugin;
use ApiCommonData::Load::Plugin::ParameterizedSchema;

use ApiCommonData::Load::StudyUtils qw(queryForOntologyHierarchyAndAnnotationProperties);

use YAML::Tiny;

my $purposeBrief = 'Read ontology and study tables and insert tables which store parent child relationships for entitytypes and attributes';
my $purpose = $purposeBrief;

my $tablesAffected =
    [ ['__SCHEMA__::AttributeGraph', ''],
      ['__SCHEMA__::EntityTypeGraph', '']
    ];

# TODO
my $tablesDependedOn =
    [['__SCHEMA__::Study',''],
     ['__SCHEMA__::EntityAttributes',  ''],
     ['__SCHEMA__::ProcessAttributes',  ''],
     ['__SCHEMA__::ProcessType',  ''],
     ['__SCHEMA__::EntityType',  ''],
     ['__SCHEMA__::AttributeUnit',  ''],
     ['SRes::OntologyTerm',  ''],
     ['__SCHEMA__::ProcessType',  ''],
    ];

my $howToRestart = ""; 
my $failureCases = "";
my $notes = "";

my $documentation = { purpose => $purpose,
                      purposeBrief => $purposeBrief,
                      tablesAffected => $tablesAffected,
                      tablesDependedOn => $tablesDependedOn,
                      howToRestart => $howToRestart,
                      failureCases => $failureCases,
                      notes => $notes
};

my $argsDeclaration =
[
   fileArg({name           => 'logDir',
            descr          => 'directory where to log sqlldr output',
            reqd           => 1,
            mustExist      => 1,
            format         => '',
            constraintFunc => undef,
            isList         => 0, }),

   fileArg({name           => 'collectionsYamlFile',
            descr          => 'optional file describing collections for this dataset',
            reqd           => 0,
            mustExist      => 1,
            format         => '',
            constraintFunc => undef,
            isList         => 0, }),


 stringArg({ name            => 'extDbRlsSpec',
	     descr           => 'ExternalDatabaseSpec for the Entity Graph',
	     reqd            => 1,
	     constraintFunc  => undef,
	     isList          => 0 }),

 stringArg({ name            => 'ontologyExtDbRlsSpec',
	     descr           => 'ExternalDatabaseSpec for the Associated Ontology',
	     reqd            => 1,
	     constraintFunc  => undef,
	     isList          => 0 }),
   stringArg({name           => 'schema',
            descr          => 'GUS::Model schema for entity tables',
            reqd           => 1,
            constraintFunc => undef,
            isList         => 0, }),
 booleanArg({ descr => 'never use the common ontology term definition',
       name  => 'noCommonDef',
       isList    => 0,
       reqd  => 0,
       constraintFunc => undef,
     }),


];

my $SCHEMA = '__SCHEMA__'; # must be replaced with real schema name
my $TERM_SCHEMA = "SRES";

my @UNDO_TABLES = qw(
  AttributeGraph
  EntityTypeGraph
);
my @REQUIRE_TABLES = qw(
  AttributeGraph
  EntityTypeGraph
);

sub new {
  my ($class) = @_;
  my $self = {};
  bless($self,$class);

  $self->initialize({requiredDbVersion => 4.0,
		     cvsRevision => '$Revision$', # cvs fills this in!
		     name => ref($self),
		     argsDeclaration   => $argsDeclaration,
		     documentation     => $documentation
		    });
  $self->{_require_tables} = \@REQUIRE_TABLES;
  $self->{_undo_tables} = \@UNDO_TABLES;
  return $self;
}


$| = 1;

sub run {
  my $self  = shift;

  ## ParameterizedSchema
  $self->requireModelObjects();
  $self->resetUndoTables(); # for when logRowsInserted() is called after loading
  $SCHEMA = $self->getArg('schema');
  if(uc($SCHEMA) eq 'APIDBUSERDATASETS') {
    $TERM_SCHEMA = 'APIDBUSERDATASETS';
  }

  ##

  chdir $self->getArg('logDir');
  my $noCommonDef = $self->getArg('noCommonDef');

  my $extDbRlsId = $self->getExtDbRlsId($self->getArg('extDbRlsSpec'), undef, $TERM_SCHEMA);
  my $ontologyExtDbRlsId = $self->getExtDbRlsId($self->getArg('ontologyExtDbRlsSpec'), undef, $TERM_SCHEMA);

  my $studies = $self->sqlAsDictionary( Sql  => "select study_id, max_attr_length from $SCHEMA.study where external_database_release_id = $extDbRlsId");

  $self->error("Expected one study row.  Found ". scalar keys %{$studies}) unless(scalar keys %$studies == 1);

  $self->getQueryHandle()->do("alter session set nls_date_format = 'yyyy-mm-dd hh24:mi:ss'") or die $self->getQueryHandle()->errstr;

  my ($attributeGraphCount, $entityTypeGraphCount);
  while(my ($studyId, $maxAttrLength) = each (%$studies)) {

    my $ontologyTerms = &queryForOntologyHierarchyAndAnnotationProperties($self->getQueryHandle(), $ontologyExtDbRlsId, $extDbRlsId, $SCHEMA, $TERM_SCHEMA, $noCommonDef);

    $self->updateDisplayTypesForGeoVariables($ontologyTerms);

    $attributeGraphCount += $self->constructAndSubmitAttributeGraphsForOntologyTerms($studyId, $ontologyTerms);

    $attributeGraphCount += $self->constructAndSubmitAttributeGraphsForNonontologicalLeaves($studyId, $ontologyTerms);

    $entityTypeGraphCount += $self->constructAndSubmitEntityTypeGraphsForStudy($studyId, $noCommonDef);
  }

  return "Loaded $attributeGraphCount rows into $SCHEMA.AttributeGraph and $entityTypeGraphCount rows into $SCHEMA.EntityTypeGraph";
}

sub updateDisplayTypesForGeoVariables {
  my ($self, $ontologyTerms) = @_;

  my $latitudeSourceId = ${ApiCommonData::Load::StudyUtils::latitudeSourceId};
  my $longitudeSourceId = ${ApiCommonData::Load::StudyUtils::longitudeSourceId};
  my $GEOHASH_PRECISION = ${ApiCommonData::Load::StudyUtils::GEOHASH_PRECISION};

  my $hiddenEverywhere = '[ "everywhere" ]';

  if(my $ontologyTerm = $ontologyTerms->{$latitudeSourceId}) {
    $ontologyTerm->{DISPLAY_TYPE} = 'latitude';
    $ontologyTerm->{HIDDEN} //= $hiddenEverywhere;
  }
  if(my $ontologyTerm = $ontologyTerms->{$longitudeSourceId}) {
    $ontologyTerm->{DISPLAY_TYPE} = 'longitude';
    $ontologyTerm->{HIDDEN} //= $hiddenEverywhere;
  }

  foreach(keys %$GEOHASH_PRECISION) {
    if(my $ontologyTerm = $ontologyTerms->{$_}) {
      $ontologyTerm->{DISPLAY_TYPE} = 'geoaggregator';
      $ontologyTerm->{HIDDEN} = $hiddenEverywhere;
    }
  }

}

sub constructAndSubmitAttributeGraphsForNonontologicalLeaves {
  my ($self, $studyId, $ontologyTerms) = @_;

  my $sql = "select distinct a.stable_id as source_id, a.parent_stable_id, a.non_ontological_name
from $SCHEMA.attribute a, $SCHEMA.entitytype et
where a.entity_type_id = et.entity_type_id
and et.study_id = ?
and a.ontology_term_id is null";

  my $dbh = $self->getQueryHandle();
  my $sh = $dbh->prepare($sql);
  $sh->execute($studyId);

  my $attributeGraphCount;
  NONONTOLOGICAL_LEAF:
  while(my $hash = $sh->fetchrow_hashref()) {
    my $sourceId = $hash->{SOURCE_ID};
    my $parentSourceId = $hash->{PARENT_STABLE_ID};
    my $displayName = $hash->{NON_ONTOLOGICAL_NAME};
    my $parentOntologyTerm =  $ontologyTerms->{$parentSourceId};
    $self->error("Parent $parentSourceId of nonontological leaf $sourceId not found ")
      unless $parentOntologyTerm;

    if($ontologyTerms->{$sourceId}) {
      $self->log("WARNING: Stable Id $sourceId found in BOTH ontology AND nonontological leaf; using parent relation from the latter");
      next NONONTOLOGICAL_LEAF;
    }
    my $attributeGraph = $self->createAttributeGraphForNonontologicalLeaf($studyId, $sourceId, $displayName, $parentOntologyTerm);
    
    $attributeGraph->submit();
    $attributeGraphCount++;
    if ($attributeGraphCount % 1000 == 0){
      $self->undefPointerCache();
    }
  }

  $self->undefPointerCache();
  $sh->finish();
  return $attributeGraphCount;
}

sub createAttributeGraph {
  my ($self, $studyId, $stableId, $ontologyTermId, $parentStableId, $parentOntologyTermId, $displayName, $ontologyTerm) = @_;
  return $self->getGusModelClass('AttributeGraph')->new({study_id => $studyId,
                                                                 stable_id => $stableId,
                                                                 ontology_term_id => $ontologyTermId,
                                                                 parent_stable_id => $parentStableId,
                                                                 parent_ontology_term_id => $parentOntologyTermId,
                                                                 provider_label => $ontologyTerm->{PROVIDER_LABEL},
                                                                 display_name => $displayName,
                                                                 display_type => $ontologyTerm->{DISPLAY_TYPE}, 
                                                                 hidden => $ontologyTerm->{HIDDEN}, 
                                                                 display_range_min => $ontologyTerm->{DISPLAY_RANGE_MIN},
                                                                 display_range_max => $ontologyTerm->{DISPLAY_RANGE_MAX},
                                                                 bin_width_override => $ontologyTerm->{BIN_WIDTH_OVERRIDE},
                                                                 is_temporal => $ontologyTerm->{IS_TEMPORAL},
                                                                 is_featured => $ontologyTerm->{IS_FEATURED},
                                                                 is_repeated => $ontologyTerm->{IS_REPEATED},
                                                                 is_merge_key => $ontologyTerm->{IS_MERGE_KEY},
                                                                 impute_zero => $ontologyTerm->{IMPUTE_ZERO},
                                                                 variable_spec_to_impute_zeroes_for => $ontologyTerm->{VARIABLE_SPEC_TO_IMPUTE_ZEROES_FOR},
                                                                 has_study_dependent_vocabulary => $ontologyTerm->{HAS_STUDY_DEPENDENT_VOCABULARY},
                                                                 weighting_variable_spec => $ontologyTerm->{WEIGHTING_VARIABLE_SPEC},
                                                                 display_order => $ontologyTerm->{DISPLAY_ORDER},
                                                                 force_string_type => $ontologyTerm->{FORCE_STRING_TYPE},
                                                                 definition => $ontologyTerm->{DEFINITION},
                                                                 ordinal_values => $ontologyTerm->{ORDINAL_VALUES},
                                                                 scale => $ontologyTerm->{SCALE}
                                                                });
}
sub createAttributeGraphForTerm {
  my ($self, $studyId, $sourceId, $ontologyTerm) = @_;
  return $self->createAttributeGraph($studyId, $sourceId, $ontologyTerm->{ONTOLOGY_TERM_ID}, $ontologyTerm->{PARENT_STABLE_ID}, $ontologyTerm->{PARENT_ONTOLOGY_TERM_ID}, $ontologyTerm->{DISPLAY_NAME}, $ontologyTerm);
}
sub createAttributeGraphForNonontologicalLeaf {
  my ($self, $studyId, $sourceId, $displayName, $parentOntologyTerm) = @_;
  my %parentCopy = %$parentOntologyTerm;
  if(defined($parentCopy{DISPLAY_TYPE}) && ($parentCopy{DISPLAY_TYPE} eq 'multifilter')){
    delete($parentCopy{DISPLAY_TYPE}); 
    printf STDERR ("DEBUG: removed multifilter from $sourceId\n");
  }
  return $self->createAttributeGraph($studyId, $sourceId, undef, $parentCopy{SOURCE_ID}, $parentCopy{ONTOLOGY_TERM_ID}, $displayName, \%parentCopy);
}
sub constructAndSubmitAttributeGraphsForOntologyTerms {
  my ($self, $studyId, $ontologyTerms) = @_;

  my $attributeGraphCount;

  foreach my $sourceId (keys %$ontologyTerms) {
    my $ontologyTerm = $ontologyTerms->{$sourceId};
    my $attributeGraph = $self->createAttributeGraphForTerm($studyId, $sourceId, $ontologyTerm);
    
    $attributeGraph->submit();
    $attributeGraphCount++;
    if ($attributeGraphCount % 1000 == 0){
      $self->undefPointerCache();
    }
  }

  $self->undefPointerCache();
  return $attributeGraphCount;
}




sub constructAndSubmitEntityTypeGraphsForStudy {
  my ($self, $studyId, $noCommonDef) = @_;

  my $dbh = $self->getQueryHandle();
  $dbh->{FetchHashKeyName} = 'NAME_lc';

  my $extDbRlsId = $self->getExtDbRlsId($self->getArg('extDbRlsSpec'), undef, $TERM_SCHEMA);
  my $ontologyExtDbRlsId = $self->getExtDbRlsId($self->getArg('ontologyExtDbRlsSpec'), undef, $TERM_SCHEMA);

  if(my $collectionsYamlFile = $self->getArg('collectionsYamlFile')) {
    my $yaml = YAML::Tiny->read();
    foreach my $collection (@$yaml) {}
  }

  my $definitionSql = "nvl(json_value(ap.props, '\$.definition[0]'), nvl(os.definition, ot.definition)) as description";
  if($noCommonDef){
    $definitionSql = "nvl(json_value(ap.props, '\$.definition[0]'), os.definition) as description";
  }

  my $sql = "
with process as (
select s.study_id
     , iot.source_id as in_stable_type_id
     , it.ENTITY_TYPE_ID as in_entity_type_id
     , p.in_entity_id as in_entity_id
     , p.out_entity_id as out_entity_id
     , ot.entity_type_id out_entity_type_id
from $SCHEMA.processattributes p
   , $SCHEMA.entityclassification i
   , $SCHEMA.entityclassification o
   , $SCHEMA.entitytype it
   , $SCHEMA.study s
   , $SCHEMA.entitytype ot
   , ${TERM_SCHEMA}.ontologyterm iot
where s.study_id = $studyId
and it.STUDY_ID = s.study_id
and ot.STUDY_ID = s.study_id
and it.ENTITY_TYPE_ID = i.entity_type_id
and ot.entity_type_id = o.entity_type_id
and p.in_entity_id = i.ENTITY_ATTRIBUTES_ID
and p.OUT_ENTITY_ID = o.ENTITY_ATTRIBUTES_ID
and it.type_id = iot.ontology_term_id (+)
),
processCounts as (select in_entity_type_id
                       , out_entity_type_id
                       , in_entity_id
                       , count(*) as ct
                  from process
                  group by in_entity_type_id
                         , out_entity_type_id
                         , in_entity_id
)
select DISTINCT p.parent_id
     , p.parent_stable_id
     , nvl(json_value(ap.props, '\$.displayName[0]'), nvl(json_value(ap.props, '\$.label[0]'), nvl(os.ontology_synonym, t.name))) as display_name
     , t.entity_type_id
     , t.internal_abbrev
     , ot.source_id as stable_id
     , $definitionSql
     , s.study_id
     , s.stable_id as study_stable_id
     , nvl(json_value(ap.props, '\$.display_name_plural[0]'), nvl(json_value(ap.props, '\$.plural[0]'), os.plural)) as display_name_plural
     , t.cardinality
     , 0 as has_attribute_collections
     , case when maxProcessCountPerEntity.maxOutputCount is null then null
            when maxProcessCountPerEntity.maxOutputCount = 0 then null
            when maxProcessCountPerEntity.maxOutputCount = 1 then 0
           else 1 end as is_many_to_one_with_parent
from  (select distinct study_id
                     , in_stable_type_id as parent_stable_id
                     , in_entity_type_id as parent_id
                     , out_entity_type_id as entity_type_id
       from process) p
   , (select in_entity_type_id
                       , out_entity_type_id
                       , max(ct) as maxOutputCount
     from processCounts
     group by in_entity_type_id
            , out_entity_type_id) maxProcessCountPerEntity
   , $SCHEMA.entitytype t
   , $SCHEMA.study s
   , ${TERM_SCHEMA}.ontologyterm ot
   , (select * from ${TERM_SCHEMA}.ontologysynonym where external_database_release_id = $ontologyExtDbRlsId) os
   , (select * from ${SCHEMA}.annotationproperties where external_database_release_id = $extDbRlsId) ap
where s.study_id = $studyId 
 and s.study_id = t.study_id
 and t.entity_type_id = maxProcessCountPerEntity.out_entity_type_id (+)
 and t.entity_type_id = p.entity_type_id (+)
and t.entity_type_id = out_entity_type_id (+)
 and t.type_id = ot.ontology_term_id (+)
 and ot.ontology_term_id = os.ontology_term_id (+)
 and ot.ontology_term_id = ap.ontology_term_id (+)
";

  my $sh = $dbh->prepare($sql);
  $sh->execute();
  my $ct;

  while(my $row= $sh->fetchrow_hashref()) {
    $row->{'study_id'} = $studyId;

    # the default for this is zero; will be updated by later steps
    $row->{'has_attribute_collections'} = 0;

    my $etg = $self->getGusModelClass('EntityTypeGraph')->new($row);

    $etg->submit();
    $ct++
  }

  return $ct;
}


1;
