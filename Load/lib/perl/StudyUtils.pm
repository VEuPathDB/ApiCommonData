package ApiCommonData::Load::StudyUtils;

use Exporter;
@ISA = qw(Exporter);
@EXPORT = qw(queryForOntologyTerms);

use strict;
use warnings;

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
union
select s.name
     , s.source_id
     , s.ontology_term_id
     , o.name parent_name
     , o.source_id parent_source_id
     , o.ontology_term_id parent_ontology_term_id
     , s.name as display_name
     , null
     , s.definition
     , 'hidden' as display_type
     , null , null , null, null, null, null, null, null, null, null
from sres.ontologyrelationship r
   , sres.ontologyterm o
   , sres.ontologyterm s
   , sres.ontologyterm p
where o.source_id = 'EUPATH_0043202' -- GEOHASH_CODE
and o.ontology_term_id = r.OBJECT_TERM_ID
and r.subject_term_id = s.ontology_term_id
and r.predicate_term_id = p.ontology_term_id
and p.SOURCE_ID = 'subClassOf'
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


1;
