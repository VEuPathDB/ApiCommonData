/* patches the virtual sequence table after loading vivax agp file */
update dots.VIRTUALSEQUENCE set chromosome = replace(source_id,'chromo_',''), modification_date = sysdate;

update dots.VIRTUALSEQUENCE set chromosome = replace(source_id,'chromo_0',''), modification_date = sysdate where chromosome like '0%';

update dots.VIRTUALSEQUENCE set source_id = 'CM000' || to_char(441 + chromosome), modification_date = sysdate;

commit;

quit;
