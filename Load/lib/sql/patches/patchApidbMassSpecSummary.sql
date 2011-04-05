/* need to update the number_of-spans so can do better query */


update apidb.MASSSPECSUMMARY mss
set mss.number_of_spans = (select count(distinct aal.start_min || aal.end_max)
from dots.aalocation aal,dots.massspecfeature f,sres.externaldatabase d, sres.externaldatabaserelease rel
where f.aa_sequence_id = mss.aa_sequence_id
and f.aa_feature_id = aal.aa_feature_id
and f.external_database_release_id = rel.external_database_release_id
and rel.external_database_id = d.external_database_id
and d.name = 'Lasonder Mosquito salivary gland sporozoite peptides'
)
where mss.external_database_release_id in (
select edr.external_database_release_id 
from sres.externaldatabase ed, sres.externaldatabaserelease edr
where ed.name = 'Lasonder Mosquito salivary gland sporozoite peptides'
and ed.external_database_id = edr.external_database_id);


update apidb.MASSSPECSUMMARY mss
set mss.number_of_spans = (select count(distinct aal.start_min || aal.end_max)
from dots.aalocation aal,dots.massspecfeature f,sres.externaldatabase d, sres.externaldatabaserelease rel
where f.aa_sequence_id = mss.aa_sequence_id
and f.aa_feature_id = aal.aa_feature_id
and f.external_database_release_id = rel.external_database_release_id
and rel.external_database_id = d.external_database_id
and d.name = 'Lasonder Mosquito oocyst peptides' 
)
where mss.external_database_release_id in (
select edr.external_database_release_id 
from sres.externaldatabase ed, sres.externaldatabaserelease edr
where ed.name = 'Lasonder Mosquito oocyst peptides' 
and ed.external_database_id = edr.external_database_id);



update apidb.MASSSPECSUMMARY mss
set mss.number_of_spans = (select count(distinct aal.start_min || aal.end_max)
from dots.aalocation aal,dots.massspecfeature f,sres.externaldatabase d, sres.externaldatabaserelease rel
where f.aa_sequence_id = mss.aa_sequence_id
and f.aa_feature_id = aal.aa_feature_id
and f.external_database_release_id = rel.external_database_release_id
and rel.external_database_id = d.external_database_id
and d.name = 'Kahn Pfalciparum merozoite peptides' 
)
where mss.external_database_release_id in (
select edr.external_database_release_id 
from sres.externaldatabase ed, sres.externaldatabaserelease edr
where ed.name = 'Kahn Pfalciparum merozoite peptides' 
and ed.external_database_id = edr.external_database_id);



update apidb.MASSSPECSUMMARY mss
set mss.number_of_spans = (select count(distinct aal.start_min || aal.end_max)
from dots.aalocation aal,dots.massspecfeature f,sres.externaldatabase d, sres.externaldatabaserelease rel
where f.aa_sequence_id = mss.aa_sequence_id
and f.aa_feature_id = aal.aa_feature_id
and f.external_database_release_id = rel.external_database_release_id
and rel.external_database_id = d.external_database_id
and d.name = 'Lasonder Mosquito oocyst-derived sporozoite peptides' 
)
where mss.external_database_release_id in (
select edr.external_database_release_id 
from sres.externaldatabase ed, sres.externaldatabaserelease edr
where ed.name = 'Lasonder Mosquito oocyst-derived sporozoite peptides' 
and ed.external_database_id = edr.external_database_id);

commit;

quit;
