package ApiCommonData::Load::Plugin::LoadMegaDatasetSpecificEntityGraph;
@ISA = qw(ApiCommonData::Load::Plugin::LoadDatasetSpecificEntityGraph;);

use lib "$ENV{GUS_HOME}/lib/perl";
use ApiCommonData::Load::Plugin::LoadDatasetSpecificEntityGraph;;
use GUS::PluginMgr::Plugin;

use ApiCommonData::Load::StudyUtils qw(parseMegaStudyConfig);

use Data::Dumper;
use YAML::Tiny;
use strict;
use warnings;

my $purposeBrief = 'Populate MEGA Study ';
my $purpose = $purposeBrief;

my $tablesAffected = [];

my $tablesDependedOn = [];

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

 stringArg({ name            => 'extDbRlsSpec',
	     descr           => 'ExternalDatabaseSpec for the Entity Graph',
	     reqd            => 1,
	     constraintFunc  => undef,
	     isList          => 0 }),
   stringArg({name           => 'schema',
            descr          => 'GUS::Model schema for entity tables',
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


];

my $SCHEMA = '__SCHEMA__'; # must be replaced with real schema name
my @UNDO_TABLES;
my @REQUIRE_TABLES;



sub getMegaStudyConfig {
  my ($self, $studyId) = @_;

  my $megaStudyYaml = $self->getArg('megaStudyYaml');

  return unless($megaStudyYaml); # nothing to see here

  my @studies = $self->sqlAsArray(Sql => "select stable_id from ${SCHEMA}.study where study_id = $studyId");  

  my $megaStudyStableId = $studies[0];

  return ApiCommonData::Load::StudyUtils::parseMegaStudyConfig($megaStudyYaml, $megaStudyStableId);
}



sub setEntityTypeInfoFromStudyId {
  my ($self, $studyId) = @_;

  my $megaStudyConfig = $self->getMegaStudyConfig($studyId);

  my $subquery = "select type_id, entity_type_id from ${SCHEMA}.entitytype where study_id = $studyId";

  if($megaStudyConfig) {
    if(my $project = $megaStudyConfig->{project}) {
      $subquery = $subquery . "\nUNION\nselect et.type_id, et.entity_type_id from ${SCHEMA}.entitytype et, core.projectinfo p where et.row_project_id = p.project_id and p.name = '$project'";
    }
    if(my $substudies = $megaStudyConfig->{studies}) {
      my $substudiesString = join(",", map { "'" . $_ . "'" } @$substudies);
      
      $subquery = $subquery . "\nUNION\nselect et.type_id, et.entity_type_id from ${SCHEMA}.entitytype et, ${SCHEMA}.study s where et.study_id = s.study_id and s.stable_id in ($substudiesString)";
    }
  }

  # For MEGA study, the internal_entity_type_ids will be a list from all sub studies
  my $sql = "select t.entity_type_id, t.internal_abbrev, t.type_id, internal_et.internal_entity_type_ids from ${SCHEMA}.entitytype t, (
select type_id, listagg(entity_type_id, ',') within group (order by type_id) internal_entity_type_ids
from (
$subquery
) group by type_id
) internal_et
where internal_et.type_id = t.type_id
and t.study_id = $studyId";

  my $dbh = $self->getQueryHandle();
  my $sh = $dbh->prepare($sql);
  $sh->execute();

  my $entityTypeInfo = {};
  my $entityTypeIdMap = {};
  while(my ($entityTypeId, $internalAbbrev, $typeId, $internalEntityTypeIds) = $sh->fetchrow_array()) {
    $entityTypeInfo->{$entityTypeId}->{internal_abbrev} = $internalAbbrev;
    $entityTypeInfo->{$entityTypeId}->{type_id} = $typeId;
    $entityTypeInfo->{$entityTypeId}->{internal_entity_type_ids} = $internalEntityTypeIds;

    foreach my $internalEntityTypeId (split(',', $internalEntityTypeIds)) {
      $entityTypeIdMap->{$internalEntityTypeId} = $entityTypeId; 
    }

  }
  $sh->finish();

  $self->{_entity_type_info} = $entityTypeInfo;
  $self->{_entity_type_id_map} = $entityTypeIdMap;

  return $entityTypeInfo, $entityTypeIdMap
}


1;
