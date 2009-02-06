create table apidb.Workflow (
  workflow_id           number(10), 
  name                  varchar(30),  -- name and version are an alternate key
  version               varchar(30),
  state                 varchar(30),
  process_id            number(10),
  undo_step_id          number(10),
  metaconfig            clob,
  xml_file_digest    	varchar(100)
);

ALTER TABLE apidb.Workflow
ADD CONSTRAINT workflow_pk PRIMARY KEY (workflow_id);

ALTER TABLE apidb.Workflow
ADD CONSTRAINT workflow_uniq
UNIQUE (name, version);

GRANT INSERT, SELECT, UPDATE, DELETE ON apidb.Workflow TO gus_w;
GRANT SELECT ON apidb.Workflow TO gus_r;

CREATE SEQUENCE apidb.Workflow_sq;

GRANT SELECT ON apidb.Workflow_sq TO gus_r;
GRANT SELECT ON apidb.Workflow_sq TO gus_w;


-----------------------------------------------------------

create table WorkflowStep (
  workflow_step_id    number(10),
  workflow_id         number(10),
  name                varchar(200),
  host_machine        varchar(30),
  process_id          number(10),
  state               varchar(30),
  state_handled       number(1),
  undo_state          varchar(30),
  undo_state_handled  number(1),
  off_line            number(1),
  start_time          date,
  end_time            date,
  step_class          varchar(200),
  params_digest       varchar(100),
  depth_first_order   number(5)
);

ALTER TABLE apidb.WorkflowStep
ADD CONSTRAINT workflow_step_pk PRIMARY KEY (workflow_step_id);

ALTER TABLE apidb.WorkflowStep
ADD CONSTRAINT workflow_step_fk1 FOREIGN KEY (workflow_id)
REFERENCES apidb.Workflow (workflow_id);

ALTER TABLE apidb.WorkflowStep
ADD CONSTRAINT workflow_step_uniq
UNIQUE (name, workflow_id);

ALTER TABLE apidb.Workflow
ADD CONSTRAINT workflow_fk1 FOREIGN KEY (undo_step_id)
REFERENCES apidb.WorkflowStep (workflow_step_id);

GRANT INSERT, SELECT, UPDATE, DELETE ON apidb.WorkflowStep TO gus_w;
GRANT SELECT ON apidb.WorkflowStep TO gus_r;

CREATE SEQUENCE apidb.WorkflowStep_sq;

GRANT SELECT ON apidb.WorkflowStep_sq TO gus_r;
GRANT SELECT ON apidb.WorkflowStep_sq TO gus_w;

-----------------------------------------------------------

-- this table is not used yet.  might be needed by pilot GUI

create table apidb.WorkflowStepDependency (
  workflow_step_dependency_id number(10),
  parent_id number(10),
  child_id number(10)
);

ALTER TABLE apidb.WorkflowStepDependency
ADD CONSTRAINT workflow_step_d_pk PRIMARY KEY (workflow_step_dependency_id);

ALTER TABLE apidb.WorkflowStepDependency
ADD CONSTRAINT workflow_step_d_fk1 FOREIGN KEY (parent_id)
REFERENCES apidb.WorkflowStep (workflow_step_id);

ALTER TABLE apidb.WorkflowStepDependency
ADD CONSTRAINT workflow_step_d_fk2 FOREIGN KEY (child_id)
REFERENCES apidb.WorkflowStep (workflow_step_id);

ALTER TABLE apidb.WorkflowStepDependency
ADD CONSTRAINT workflow_step_d_uniq
UNIQUE (parent_id, child_id);

GRANT INSERT, SELECT, UPDATE, DELETE ON apidb.WorkflowStepDependency TO gus_w;
GRANT SELECT ON apidb.WorkflowStepDependency TO gus_r;

CREATE SEQUENCE apidb.WorkflowStepDependency_sq;

GRANT SELECT ON apidb.WorkflowStepDependency_sq TO gus_r;
GRANT SELECT ON apidb.WorkflowStepDependency_sq TO gus_w;
GRANT REFERENCES ON core.AlgorithmInvocation TO ApiDB;

---------------------------------------------------------------------------

create table apidb.WorkflowStepAlgInvocation (
  workflow_step_alg_inv_id number(10),
  workflow_step_id number(10),
  algorithm_invocation_id number(10)
);

ALTER TABLE apidb.WorkflowStepAlgInvocation
ADD CONSTRAINT workflow_step_alg_inv_pk PRIMARY KEY (workflow_step_alg_inv_id);

ALTER TABLE apidb.WorkflowStepAlgInvocation
ADD CONSTRAINT workflow_step_alg_inv_fk1 FOREIGN KEY (workflow_step_id)
REFERENCES apidb.WorkflowStep (workflow_step_id);

ALTER TABLE apidb.WorkflowStepAlgInvocation
ADD CONSTRAINT workflow_step_alg_inv_fk2 FOREIGN KEY (algorithm_invocation_id)
REFERENCES core.AlgorithmInvocation (algorithm_invocation_id);

ALTER TABLE apidb.WorkflowStepAlgInvocation
ADD CONSTRAINT workflow_step_alg_inv_uniq
UNIQUE (workflow_step_id, algorithm_invocation_id);

GRANT INSERT, SELECT, UPDATE, DELETE ON apidb.WorkflowStepAlgInvocation TO gus_w;
GRANT SELECT ON apidb.WorkflowStepAlgInvocation TO gus_r;

CREATE SEQUENCE apidb.WorkflowStepAlgInvocation_sq;

GRANT SELECT ON apidb.WorkflowStepAlgInvocation_sq TO gus_r;
GRANT SELECT ON apidb.WorkflowStepAlgInvocation_sq TO gus_w;


exit;
