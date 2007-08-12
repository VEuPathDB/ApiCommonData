set time on timing on

-- ~99K names have been loaded into dots.NaGene.  Of these, ~59K are of the 
-- form "<name>, <name>".  This script will split these into two records, each 
-- with a dots.NaFeatureNaGene to link it to the original NaFeature
/*

-- first, make a list of the duplicated names
create table apidb.DoubleNameAliases as
select gene, alias
from apidb.GeneAlias
where alias like '%,%';

-- then, insert new nfng
insert into dots.NaFeatureNaGene
            (na_feature_na_gene_id, na_gene_id, na_feature_id,
             modification_date, user_read, user_write, group_read,
             group_write, other_read, other_write, row_user_id, 
             row_group_id, row_project_id, row_alg_invocation_id)
select dots.NaFeatureNaGene_sq.nextval, new.na_gene_id, nfng.na_feature_id,
       sysdate, nfng.user_read, nfng.user_write, nfng.group_read,
       nfng.group_write, nfng.other_read, nfng.other_write, nfng.row_user_id,
       nfng.row_group_id, nfng.row_project_id, nfng.row_alg_invocation_id
from dots.NaFeatureNaGene nfng, dots.NaGene old, dots.NaGene new, apidb.DoubleNameAliases dna
where nfng.na_gene_id = old.na_gene_id
  and old.name = substr(dna.alias, 1, instr(dna.alias, ',')-1)
  and new.name = substr(dna.alias, instr(dna.alias, ', ') + 2);

-- older version
create table apidb.ExtraNaGeneName as
select na_gene_id as old_na_gene_id, dots.NaGene_sq.nextval as new_na_gene_id
from dots.NaGene
where name like '%,%';

-- then, create the new NaGene record
insert into dots.NaGene
            (na_gene_id,  name,  is_verified,  modification_date,  user_read,
             user_write,  group_read,  group_write,  other_read,  other_write,
             row_user_id,  row_group_id,  row_project_id,
             row_alg_invocation_id)
select engn.new_na_gene_id, substr(ng.name, instr(ng.name, ', ') + 2),
       ng.is_verified, sysdate, ng.user_read,
       user_write, ng.group_read, ng.group_write, ng.other_read, ng.other_write,
       row_user_id, ng.row_group_id, ng.row_project_id,
       ng.row_alg_invocation_id
from dots.NaGene ng, apidb.ExtraNaGeneName engn
where engn.old_na_gene_id = ng.na_gene_id;

-- next, create a new NaFeatureNaGene record for each of the newly-created
-- records
insert into dots.NaFeatureNaGene
            (na_feature_na_gene_id, na_gene_id, na_feature_id,
             modification_date, user_read, user_write, group_read,
             group_write, other_read, other_write, row_user_id, 
             row_group_id, row_project_id, row_alg_invocation_id)
select dots.NaFeatureNaGene_sq.nextval, engn.new_na_gene_id, nfng.na_feature_id,
       sysdate, nfng.user_read, nfng.user_write, nfng.group_read,
       nfng.group_write, nfng.other_read, nfng.other_write, nfng.row_user_id,
       nfng.row_group_id, nfng.row_project_id, nfng.row_alg_invocation_id
from dots.NaFeatureNaGene nfng, apidb.ExtraNaGeneName engn
where nfng.na_gene_id = engn.new_na_gene_id;

-- finally, remove the second name from NaGene records with two
update dots.NaGene
set name = substr(name, 1, instr(name, ',')-1)
where name like '%,%';
*/
