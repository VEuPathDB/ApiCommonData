package ApiCommonData::Load::StudyUtils;

use Exporter;
@ISA = qw(Exporter);
@EXPORT = qw(
queryForOntologyTerms
getSchemaFromRowAlgInvocationId
getTermsByAnnotationPropertyValue
);

use strict;
use warnings;

use JSON;
use Data::Dumper;

sub queryForOntologyTerms {
  my ($dbh, $extDbRlsId) = @_;


  # TODO: update the source_id for geohash terms
  my $sql = "select s.name
                  , s.source_id
                  , s.ontology_term_id
                  , o.name parent_name
                  , o.source_id parent_source_id
                  , o.ontology_term_id parent_ontology_term_id
                  , nvl(os.ontology_synonym, s.name) as display_name
                  , os.is_preferred
                  , os.definition                    --this is also in the annotation_properties json
                  , json_value(os.annotation_properties, '\$.displayType[0]') as display_type
                  , json_query(os.annotation_properties, '\$.hidden') as hidden -- gives json array
                  , json_value(os.annotation_properties, '\$.displayOrder[0]') as display_order
                  , json_value(annotation_properties, '\$.defaultDisplayRangeMin[0]') as display_range_min
                  , json_value(annotation_properties, '\$.defaultDisplayRangeMax[0]') as display_range_max
                  , json_value(annotation_properties, '\$.defaultBinWidth[0]') as bin_width_override
                  , case when lower(json_value(annotation_properties, '\$.is_temporal[0]')) = 'yes' then 1 else 0 end as is_temporal
                  , case when lower(json_value(annotation_properties, '\$.is_featured[0]')) = 'yes' then 1 else 0 end as is_featured
                  , case when lower(json_value(annotation_properties, '\$.repeated[0]')) = 'yes' then 1 else 0 end as is_repeated
                  , case when lower(json_value(annotation_properties, '\$.mergeKey[0]')) = 'yes' then 1 else 0 end as is_merge_key
                  , json_query(os.annotation_properties, '\$.variable') as provider_label -- gives json array
                  , os.ordinal_values as ordinal_values --gives json array
from sres.ontologyrelationship r
   , sres.ontologyterm s
   , sres.ontologyterm o
   , sres.ontologyterm p
   , sres.ontologysynonym os
where r.subject_term_id = s.ontology_term_id
and r.predicate_term_id = p.ontology_term_id
and r.object_term_id = o.ontology_term_id
and p.SOURCE_ID = 'subClassOf'
and s.ontology_term_id = os.ontology_term_id (+)
and r.EXTERNAL_DATABASE_RELEASE_ID = os.EXTERNAL_DATABASE_RELEASE_ID (+)    
and r.external_database_release_id = ?
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
  my ($dbh, $extDbRlsId) = @_;

  my $sql = "SELECT o2.source_id,o.ANNOTATION_PROPERTIES
FROM sres.ONTOLOGYSYNONYM o
LEFT JOIN sres.ONTOLOGYTERM o2 ON o.ONTOLOGY_TERM_ID =o2.ONTOLOGY_TERM_ID 
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

sub getTermsByAnnotationPropertyValue {
  my($dbh, $rowAlgInvocationId, $property, $match) = @_;
  my $attsHash = getTermsAnnotationProperties($dbh,$rowAlgInvocationId);
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

1;
