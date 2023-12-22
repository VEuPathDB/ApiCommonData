package ApiCommonData::Load::StudyUtils;

use Exporter;
@ISA = qw(Exporter);
@EXPORT = qw(
queryForOntologyTerms
queryForOntologyHierarchyAndAnnotationProperties
getSchemaFromRowAlgInvocationId
getTermsByAnnotationPropertyValue
parseMegaStudyConfig
dropTablesLike
dropViewsLike
);

use strict;
use warnings;

use JSON;
use Data::Dumper;

use YAML::Tiny;


our $GEOHASH_PRECISION = {
    EUPATH_0043203 => 1,
    EUPATH_0043204 => 2,
    EUPATH_0043205 => 3,
    EUPATH_0043206 => 4,
    EUPATH_0043207 => 5,
    EUPATH_0043208 => 6,
#    EUPATH_0043209 => 7,
  };


our $latitudeSourceId = "OBI_0001620";
our $longitudeSourceId = "OBI_0001621";
our $maxAdminLevelSourceId = "POPBIO_8000179";

our @adminLevelSourceIds = qw/OBI_0001627 ENVO_00000005 ENVO_00000006 GAZ_00000013/; # country, admin1, admin2, continent


sub queryForOntologyTerms {
  my ($dbh, $extDbRlsId, $termSchema) = @_;


  my $sql = "select s.source_id
                  , s.ontology_term_id
                  , COALESCE(os.ontology_synonym, s.name) as display_name
from ${termSchema}.ontologyterm s
LEFT JOIN (select ontology_term_id
           , ontology_synonym
      from ${termSchema}.ontologysynonym
      where external_database_release_id = ?) os
ON s.ontology_term_id = os.ontology_term_id
";

  my $sh = $dbh->prepare($sql);
  $sh->execute($extDbRlsId);

  my %ontologyTerms;

  while(my $hash = $sh->fetchrow_hashref()) {
    my $sourceId = $hash->{SOURCE_ID};

    $ontologyTerms{$sourceId} = $hash;
  }
  $sh->finish();

  return \%ontologyTerms;
}


sub queryForOntologyHierarchyAndAnnotationProperties {
  my ($dbh, $ontologyExtDbRlsId, $extDbRlsId, $schema, $termSchema, $noCommonDef) = @_;

  my $definitionSql = "COALESCE((ap.props::json -> 'definition' ->> 0)::text, COALESCE(os.definition, s.definition))";
  if($noCommonDef){
    $definitionSql = "COALESCE((ap.props::json -> 'definition' ->> 0)::text, os.definition)";
  }

  my $sql = "select s.name
                  , s.source_id
                   , s.ontology_term_id
                  , o.name parent_name
                  , o.source_id as parent_stable_id
                  , o.ontology_term_id parent_ontology_term_id
                  -- json values from annprop OR dedicated fields in ontologysyn
                  , COALESCE((ap.props::json -> 'displayName' ->> 0)::text, COALESCE(os.ontology_synonym, s.name)) as display_name
                  , $definitionSql as definition
                  , os.is_preferred
                  -- json values from annprop OR annotation_props field in ontologysynonym
                  , COALESCE((ap.props::json -> 'displayType' ->> 0)::text, (os.annotation_properties::json -> 'displayType' ->> 0)::text) as display_type
                  , COALESCE((ap.props::json -> 'displayOrder' ->> 0)::text, (os.annotation_properties::json -> 'displayOrder' ->> 0)::text) as display_order
                  , COALESCE((ap.props::json -> 'defaultDisplayRangeMin' ->> 0)::text, (os.annotation_properties::json -> 'defaultDisplayRangeMin' ->> 0)::text) as display_range_min
                  , COALESCE((ap.props::json -> 'defaultDisplayRangeMax' ->> 0)::text, (os.annotation_properties::json -> 'defaultDisplayRangeMax' ->> 0)::text) as display_range_max
                  , COALESCE((ap.props::json -> 'defaultBinWidth' ->> 0)::text, (os.annotation_properties::json -> 'defaultBinWidth' ->> 0)::text) as bin_width_override
                  , COALESCE((ap.props::json -> 'forceStringType' ->> 0)::text, (os.annotation_properties::json -> 'forceStringType' ->> 0)::text) as force_string_type
                  , COALESCE((ap.props::json -> 'scale' ->> 0)::text, (os.annotation_properties::json -> 'scale' ->> 0)::text) as scale
                  , COALESCE((ap.props::json -> 'variableSpecToImputeZeroesFor' ->> 0)::text, (os.annotation_properties::json -> 'variableSpecToImputeZeroesFor' ->> 0)::text) as variable_spec_to_impute_zeroes_for
                  , COALESCE((ap.props::json -> 'weightingVariableSpec' ->> 0)::text, (os.annotation_properties::json -> 'weightingVariableSpec' ->> 0)::text) as weighting_variable_spec
                  -- boolean things from json_value
                  , case when lower(COALESCE((ap.props::json -> 'hasStudyDependentVocabulary' ->> 0)::text, (os.annotation_properties::json -> 'hasStudyDependentVocabulary' ->> 0)::text)) = 'yes' then 1 else 0 end as has_study_dependent_vocabulary
                  , case when lower(COALESCE((ap.props::json -> 'is_temporal' ->> 0)::text, (os.annotation_properties::json -> 'is_temporal' ->> 0)::text))  = 'yes' then 1 else 0 end as is_temporal
                  , case when lower(COALESCE((ap.props::json -> 'is_featured' ->> 0)::text, (os.annotation_properties::json -> 'is_featured' ->> 0)::text))  = 'yes' then 1 else 0 end as is_featured
                  , case when lower(COALESCE((ap.props::json -> 'repeated' ->> 0)::text, (os.annotation_properties::json -> 'repeated' ->> 0)::text))  = 'yes' then 1 else 0 end as is_repeated
                  , case when lower(COALESCE((ap.props::json -> 'mergeKey' ->> 0)::text, (os.annotation_properties::json -> 'mergeKey' ->> 0)::text))  = 'yes' then 1 else 0 end as is_merge_key
                  , case when lower(COALESCE((ap.props::json -> 'impute_zero' ->> 0)::text, (os.annotation_properties::json -> 'impute_zero' ->> 0)::text))  = 'yes' then 1 else 0 end as impute_zero
                  -- json array
                  , COALESCE((ap.props::json -> 'hidden')::text, (os.annotation_properties::json -> 'hidden')::text) as hidden
                  , COALESCE((ap.props::json -> 'variable')::text, (os.annotation_properties::json -> 'variable')::text) as provider_label
                  , COALESCE((ap.props::json -> 'ordinal_values')::text, (os.annotation_properties::json -> 'ordinal_values')::text) as ordinal_values
from ${termSchema}.ontologyrelationship r
 INNER JOIN ${termSchema}.ontologyterm s ON r.subject_term_id = s.ontology_term_id
 INNER JOIN ${termSchema}.ontologyterm o ON r.object_term_id = o.ontology_term_id
 INNER JOIN ${termSchema}.ontologyterm p ON r.predicate_term_id = p.ontology_term_id
 LEFT JOIN ${termSchema}.ontologysynonym os ON r.EXTERNAL_DATABASE_RELEASE_ID = os.EXTERNAL_DATABASE_RELEASE_ID AND r.subject_term_id = os.ontology_term_id
 LEFT JOIN (select * from ${schema}.annotationproperties where external_database_release_id = ?) ap ON r.subject_term_id = ap.ontology_term_id
WHERE
 p.SOURCE_ID = 'subClassOf'
 and r.external_database_release_id = ?";

  my $sh = $dbh->prepare($sql);
  $sh->execute($extDbRlsId, $ontologyExtDbRlsId);

  my %ontologyTerms;

  while(my $hash = $sh->fetchrow_hashref()) {
    my $sourceId = $hash->{SOURCE_ID};

    $ontologyTerms{$sourceId} = $hash;
  }
  $sh->finish();

  return \%ontologyTerms;

}




sub getSchemaFromRowAlgInvocationId {
  my($dbh, $rowAlgInvocationId) = @_;
  my $sql  = "select p.string_value as SCHEMA
from core.algorithmparam p, core.algorithmparamkey k
where p.row_alg_invocation_id = ? 
and p.ALGORITHM_PARAM_KEY_ID = k.ALGORITHM_PARAM_KEY_ID
and k.ALGORITHM_PARAM_KEY = 'schema'";
  my $sh = $dbh->prepare($sql);
printf STDERR ("Executing query with id=$rowAlgInvocationId:$sql\n");
  $sh->execute($rowAlgInvocationId);
  my $hash = $sh->fetchrow_hashref();
  my $schema = $hash->{SCHEMA};
printf STDERR ("SCHEMA = $schema\n");
  $sh->finish();
  return $schema;
}

sub getTermsAnnotationProperties {
  my ($dbh, $extDbRlsId, $termSchema) = @_;

  my $sql = "SELECT o2.source_id,o.ANNOTATION_PROPERTIES
FROM ${termSchema}.ONTOLOGYSYNONYM o
LEFT JOIN ${termSchema}.ONTOLOGYTERM o2 ON o.ONTOLOGY_TERM_ID =o2.ONTOLOGY_TERM_ID
WHERE o.EXTERNAL_DATABASE_RELEASE_ID = ? 
and o.ANNOTATION_PROPERTIES IS NOT NULL";

  my $sh = $dbh->prepare($sql);
  $sh->execute($extDbRlsId);
  my %attsHash;
  while(my $hash = $sh->fetchrow_hashref()) {
    $attsHash{$hash->{SOURCE_ID}} = from_json($hash->{ANNOTATION_PROPERTIES});
  }
  return \%attsHash;
}

# sub getTermsWithDataShapeOrdinal {
#   my($dbh, $extDbRlsId, $property, $match, $termSchema) = @_;
#   my $sql = "SELECT o2.source_id,'1'
# FROM ${termSchema}.ONTOLOGYSYNONYM o
# LEFT JOIN ${termSchema}.ONTOLOGYTERM o2 ON o.ONTOLOGY_TERM_ID =o2.ONTOLOGY_TERM_ID
# WHERE o.EXTERNAL_DATABASE_RELEASE_ID = ?
# and ((o.ANNOTATION_PROPERTIES::json -> 'forceStringType' ->> 0)::text = 'yes'
# OR (o.ORDINAL_VALUES IS NOT NULL
# AND json_value(o.ORDINAL_VALUES, '\$.size()') > 1))
# ";
#   my $sh = $dbh->prepare($sql);
#   $sh->execute($extDbRlsId);
#   my %attsHash;
#   while(my $row = $sh->fetchrow_arrayref()) {
#     $attsHash{$row->[0]} = 1;
#   }
#   return \%attsHash;
# }
sub getTermsByAnnotationPropertyValue {
  my($dbh, $extDbRlsId, $property, $match) = @_;
  my $attsHash = getTermsAnnotationProperties($dbh,$extDbRlsId);
  my %terms;
  while( my ($sourceId, $atts) = each %$attsHash){
    next unless $atts->{$property};
    foreach my $value (@{$atts->{$property}}){
      if($value eq $match){
        $terms{$sourceId} = 1;
      }
    }
  }
  return \%terms;
}


sub dropTablesLike {
  my ($schema, $pattern, $dbh) = @_;

  #my $sql = sprintf("SELECT table_name FROM all_tables WHERE upper(OWNER)=upper('${schema}') AND REGEXP_LIKE(upper(table_name), upper('%s'))", $pattern);
  my $sql = "SELECT table_name FROM information_schema.tables WHERE upper(table_schema) = upper('${schema}') AND upper(table_name) like  upper('${pattern}%') and table_type != 'VIEW'";

  print STDERR "Finding tables to drop with SQL: $sql \n";
  my $sth = $dbh->prepare($sql);
  $sth->execute();
  while(my ($table_name) = $sth->fetchrow_array()){
    print STDERR "dropping table ${schema}.${table_name}\n";
    $dbh->do("drop table ${schema}.${table_name} CASCADE") or die $dbh->errstr;
  }
  $sth->finish();
}

sub dropViewsLike {
  my ($schema, $pattern, $dbh) = @_;

  #my $sql = sprintf("SELECT table_name FROM all_tables WHERE upper(OWNER)=upper('${schema}') AND REGEXP_LIKE(upper(table_name), upper('%s'))", $pattern);
  my $sql = "SELECT table_name FROM information_schema.tables WHERE upper(table_schema) = upper('${schema}') AND upper(table_name) like  upper('${pattern}%') and table_type = 'VIEW'";

  print STDERR "Finding views to drop with SQL: $sql \n";
  my $sth = $dbh->prepare($sql);
  $sth->execute();
  while(my ($view_name) = $sth->fetchrow_array()){
    print STDERR "dropping view ${schema}.${view_name}\n";
    $dbh->do("drop view ${schema}.${view_name}") or die $dbh->errstr;
  }
  $sth->finish();
}



sub parseMegaStudyConfig {
  my ($megaStudyYaml, $megaStudyStableId) = @_;

  my $yaml = YAML::Tiny->read($megaStudyYaml);
  unless($yaml) {
    die "Error parsing yaml file for mega study:  $megaStudyYaml";
  }

  foreach my $doc (@$yaml) {
    if($doc->{stable_id} eq $megaStudyStableId) {
      return $doc;
    }
  }

  die "no configuration for $megaStudyStableId found in yaml file:  $megaStudyYaml";
}


sub parseCollectionsConfig {
  my ($collectionsYaml) = @_;

  my %rv;

  my $yaml = YAML::Tiny->read($collectionsYaml);
  unless($yaml) {
    die "Error parsing yaml file for collections:  $collectionsYaml";
  }

  foreach my $doc (@$yaml) {
    my $stableId = $doc->{stable_id};
    $rv{$stableId} = $doc;
  }

  return \%rv;
}



1;
