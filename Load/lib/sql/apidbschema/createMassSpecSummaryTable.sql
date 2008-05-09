create table DoTS.MassSpecSummary(
    mass_spec_summary_id  number(12) not null,
    aa_sequence_id number(12) not null,
    prediction_algorithm_id number(12) not null,
    external_database_release_id number(12) null,
    developmental_stage varchar2(20) not null,
    is_expressed number(1) not null,
    number_of_spans number(12) not null,
    sequence_count number(12) not null,
    spectrum_count number(12) not null,
    aa_seq_percent_covered float(22) not null,
    aa_seq_length number(12) not null,
    aa_seq_molecular_weight number(12) not null,
    aa_seq_pi float(22) not null,
    modification_date date not null,
    user_read number(1) not null,
    user_write number(1) not null,
    group_read number(1) not null,
    group_write number(1) not null,
    other_read number(1) not null,
    other_write number(1) not null,
    row_user_id number(12) not null,
    row_group_id number(3) not null,
    row_project_id number(4) not null,
    row_alg_invocation_id number(12) not null,
    FOREIGN KEY (external_database_release_id) REFERENCES SRes.ExternalDatabaseRelease,
    PRIMARY KEY (mass_spec_summary_id));


create sequence DoTS.MassSpecSummary_sq;
GRANT insert, select, update, delete ON  DoTS.MassSpecSummary TO gusrw;
GRANT select ON   DoTS.MassSpecSummary TO gusdevreadonly;
GRANT select ON DoTS.MassSpecSummary_sq TO gusrw;

INSERT INTO core.tableinfo (
  table_id,
  name,
  table_type,
  primary_key_column,
  database_id,
  is_versioned,
  is_view,
  view_on_table_id,
  superclass_table_id,
  is_updatable,
  modification_date,
  user_read,
  user_write,
  group_read,
  group_write,
  other_read,
  other_write,
  row_user_id,
  row_group_id,
  row_project_id,
  row_alg_invocation_id
)
SELECT
   core.tableinfo_sq.nextval,
  'MassSpecSummary',
  'Standard',
  'mass_spec_summary_id', --primary_key_column
  d.database_id, --database_id
  0,
  0,
  null, --view_on_table_id
  null, --superclass_table_id
  1,
  SYSDATE,
  1,
  1,
  1,
  1,
  1,
  1,
  1,
  1,
  1,
  1
FROM 
  dual,
  (SELECT database_id from core.databaseinfo where name = 'DoTS') d;

exit
