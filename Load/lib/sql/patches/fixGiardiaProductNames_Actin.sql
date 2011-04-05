/* patch to fix mis-annotated giardia actins */

update dots.genefeature
set product = 'actin-related protein'
where source_id = 'GL50803_15113';

update dots.genefeature
set product = 'actin-related protein'
where source_id = 'GL50581_3625';

update dots.genefeature
set product = 'ACTIN'
where source_id = 'GL50803_40817';

update dots.genefeature
set product = 'ACTIN'
where source_id = 'GL50581_16';

commit;

quit;
