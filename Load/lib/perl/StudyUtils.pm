package ApiCommonData::Load::StudyUtils;

use Exporter;
@ISA = qw(Exporter);
@EXPORT = qw(
queryForOntologyTerms
queryForOntologyHierarchyAndAnnotationProperties
getSchemaFromRowAlgInvocationId
getTermsByAnnotationPropertyValue
getTermsWithDataShapeOrdinal
parseMegaStudyConfig
dropTablesLike
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

sub queryForOntologyTerms {
  my ($dbh, $extDbRlsId, $termSchema) = @_;


  my $sql = "select s.source_id
                  , s.ontology_term_id
                  , nvl(os.ontology_synonym, s.name) as display_name
from ${termSchema}.ontologyterm s
   , (select ontology_term_id
           , ontology_synonym
      from ${termSchema}.ontologysynonym
      where external_database_release_id = ?) os
where s.ontology_term_id = os.ontology_term_id (+)
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
  my ($dbh, $ontologyExtDbRlsId, $extDbRlsId, $schema, $termSchema) = @_;

  my $sql = "select s.name
                  , s.source_id
                   , s.ontology_term_id
                  , o.name parent_name
                  , o.source_id as parent_stable_id
                  , o.ontology_term_id parent_ontology_term_id
                  , nvl(json_value(ap.props, '\$.displayName[0]'), nvl(os.ontology_synonym, s.name)) as display_name
                  , os.is_preferred
                  , nvl(json_value(ap.props, '\$.definition[0]'), nvl(os.definition, s.definition)) as definition
                  , json_value(ap.props, '\$.displayType[0]') as display_type
                  , json_query(ap.props, '\$.hidden') as hidden -- gives json array
                  , json_value(ap.props, '\$.displayOrder[0]') as display_order
                  , json_value(ap.props, '\$.defaultDisplayRangeMin[0]') as display_range_min
                  , json_value(ap.props, '\$.defaultDisplayRangeMax[0]') as display_range_max
                  , json_value(ap.props, '\$.defaultBinWidth[0]') as bin_width_override
                  , case when lower(json_value(ap.props, '\$.is_temporal[0]')) = 'yes' then 1 else 0 end as is_temporal
                  , case when lower(json_value(ap.props, '\$.is_featured[0]')) = 'yes' then 1 else 0 end as is_featured
                  , case when lower(json_value(ap.props, '\$.repeated[0]')) = 'yes' then 1 else 0 end as is_repeated
                  , case when lower(json_value(ap.props, '\$.mergeKey[0]')) = 'yes' then 1 else 0 end as is_merge_key
                  , case when lower(json_value(ap.props, '\$.impute_zero[0]')) = 'yes' then 1 else 0 end as impute_zero
                  , json_query(ap.props, '\$.variable') as provider_label -- gives json array
                  , json_query(ap.props, '\$.ordinal_values') as ordinal_values -- gives json array
                  , json_value(ap.props, '\$.scale[0]') as scale
from ${termSchema}.ontologyrelationship r
   , ${termSchema}.ontologyterm s
   , ${termSchema}.ontologyterm o
   , ${termSchema}.ontologyterm p
   , ${termSchema}.ontologysynonym os
   , (select * from ${schema}.annotationproperties where external_database_release_id = ?) ap
where r.subject_term_id = s.ontology_term_id
and r.predicate_term_id = p.ontology_term_id
and r.object_term_id = o.ontology_term_id
and p.SOURCE_ID = 'subClassOf'
and s.ontology_term_id = os.ontology_term_id (+)
and s.ontology_term_id = ap.ontology_term_id (+)
and r.EXTERNAL_DATABASE_RELEASE_ID = os.EXTERNAL_DATABASE_RELEASE_ID (+)
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

sub getTermsWithDataShapeOrdinal {
  my($dbh, $extDbRlsId, $property, $match, $termSchema) = @_;
  my $sql = "SELECT o2.source_id,'1'
FROM ${termSchema}.ONTOLOGYSYNONYM o
LEFT JOIN ${termSchema}.ONTOLOGYTERM o2 ON o.ONTOLOGY_TERM_ID =o2.ONTOLOGY_TERM_ID
WHERE o.EXTERNAL_DATABASE_RELEASE_ID = ? 
and (json_value(o.ANNOTATION_PROPERTIES, '\$.forceStringType[0]') = 'yes' 
OR (o.ORDINAL_VALUES IS NOT NULL
AND json_value(o.ORDINAL_VALUES, '\$.size()') > 1))
";
  my $sh = $dbh->prepare($sql);
  $sh->execute($extDbRlsId);
  my %attsHash;
  while(my $row = $sh->fetchrow_arrayref()) {
    $attsHash{$row->[0]} = 1;
  }
  return \%attsHash;
}
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

  my $sql = sprintf("SELECT table_name FROM all_tables WHERE upper(OWNER)=upper('${schema}') AND REGEXP_LIKE(upper(table_name), upper('%s'))", $pattern);
  print STDERR "Finding tables to drop with SQL: $sql";
  my $sth = $dbh->prepare($sql);
  $sth->execute();
  while(my ($table_name) = $sth->fetchrow_array()){
    print STDERR "dropping table ${schema}.${table_name}";
    $dbh->do("drop table ${schema}.${table_name}") or die $dbh->errstr;
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
