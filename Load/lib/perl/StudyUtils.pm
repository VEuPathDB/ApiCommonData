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
                  , os.variable as provider_label
                  , os.is_preferred
                  , os.definition
                  , tt.term_type
from sres.ontologyrelationship r
   , sres.ontologyterm s
   , sres.ontologyterm o
   , sres.ontologyterm p
   , sres.ontologysynonym os
   , (select r.external_database_release_id, s.ontology_term_id, o.name as term_type
from sres.ontologyrelationship r
   , sres.ontologyterm s
   , sres.ontologyterm o
   , sres.ontologyterm p
where r.subject_term_id = s.ontology_term_id
and r.predicate_term_id = p.ontology_term_id
and r.object_term_id = o.ontology_term_id
and p.SOURCE_ID = 'EUPATH_0000271' -- termType
) tt
where r.subject_term_id = s.ontology_term_id
and r.predicate_term_id = p.ontology_term_id
and r.object_term_id = o.ontology_term_id
and p.SOURCE_ID = 'subClassOf'
and s.ontology_term_id = os.ontology_term_id (+)
and r.EXTERNAL_DATABASE_RELEASE_ID = os.EXTERNAL_DATABASE_RELEASE_ID (+)    
and s.ontology_term_id = tt.ontology_term_id (+)
and r.EXTERNAL_DATABASE_RELEASE_ID = tt.EXTERNAL_DATABASE_RELEASE_ID (+)    
and r.external_database_release_id = ?
union
select ot.name, ot.source_id, ot.ontology_term_id, pt.name, pt.source_id, pt.ontology_term_id, ot.name, null, null, null, 'hidden'
from sres.ontologyterm ot, sres.ontologyterm pt
where ot.source_id like 'GEOHASH%'
and pt.source_id = 'Thing'
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
