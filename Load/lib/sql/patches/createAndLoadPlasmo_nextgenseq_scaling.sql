drop table apidb.nextgenseq_scaling;

create table apidb.nextgenseq_scaling (
  exp_name varchar2(200),
  sample_name varchar2(40),
  rna_total number,
  nuclei number,
  scaling number
  );

grant select on apidb.nextgenseq_scaling to GUS_W;
grant select on apidb.nextgenseq_scaling to GUS_R;

insert into apidb.nextgenseq_scaling (exp_name,sample_name,rna_total,nuclei,scaling) VALUES ('Stunnenberg_iRBC','5h',9,1.83,0.06329908);
insert into apidb.nextgenseq_scaling (exp_name,sample_name,rna_total,nuclei,scaling) VALUES ('Stunnenberg_iRBC','10h',4,1,0.051483252);
insert into apidb.nextgenseq_scaling (exp_name,sample_name,rna_total,nuclei,scaling) VALUES ('Stunnenberg_iRBC','15h',5,1,0.064354065);
insert into apidb.nextgenseq_scaling (exp_name,sample_name,rna_total,nuclei,scaling) VALUES ('Stunnenberg_iRBC','20h',14,1,0.180191381);
insert into apidb.nextgenseq_scaling (exp_name,sample_name,rna_total,nuclei,scaling) VALUES ('Stunnenberg_iRBC','25h',50,1,0.643540647);
insert into apidb.nextgenseq_scaling (exp_name,sample_name,rna_total,nuclei,scaling) VALUES ('Stunnenberg_iRBC','30h',96,1.39,0.892128551);
insert into apidb.nextgenseq_scaling (exp_name,sample_name,rna_total,nuclei,scaling) VALUES ('Stunnenberg_iRBC','35h',209,2.69,0.999999965);
insert into apidb.nextgenseq_scaling (exp_name,sample_name,rna_total,nuclei,scaling) VALUES ('Stunnenberg_iRBC','40h',195,5.42,0.463491879);

commit;

quit;
