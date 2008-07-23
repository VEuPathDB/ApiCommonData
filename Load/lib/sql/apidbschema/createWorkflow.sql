create table apidb.Workflow (
  workflow_id   number(10), 
  name          varchar(30),  -- name and version are an alternate key
  version       varchar(30),
  state         varchar(30),
  process_id    number(10),
  metaconfig    clob,
  start_time    date,
  end_time      date
);

ALTER TABLE apidb.Workflow
ADD CONSTRAINT workflow_pk PRIMARY KEY (workflow_id);

ALTER TABLE apidb.Workflow
ADD CONSTRAINT workflow_uniq
UNIQUE (name, version)

GRANT INSERT, SELECT, UPDATE, DELETE ON apidb.Workflow TO gus_w;
GRANT SELECT ON apidb.Workflow TO gus_r;

CREATE SEQUENCE apidb.Workflow_sq;

GRANT SELECT ON apidb.Workflow_sq TO gus_r;
GRANT SELECT ON apidb.Workflow_sq TO gus_w;


-----------------------------------------------------------

create table WorkflowStep (
  workflow_step_id    number(10),
  workflow_id         number(10),
  name                varchar(50),
  host_machine        varchar(30),
  wrapper_process_id  number(10),
  state               varchar(30),
  state_handled       number(1),
  start_time          date,
  end_time            date
);

ALTER TABLE apidb.WorkflowStep
ADD CONSTRAINT workflow_step_pk PRIMARY KEY (workflow_step_id);

ALTER TABLE apidb.WorkflowStep
ADD CONSTRAINT workflow_step_fk1 FOREIGN KEY (workflow_id)
REFERENCES apidb.Workflow (workflow_id);

ALTER TABLE apidb.WorkflowStep
ADD CONSTRAINT workflow_step_uniq
UNIQUE (name, workflow_id)

GRANT INSERT, SELECT, UPDATE, DELETE ON apidb.WorkflowStep TO gus_w;
GRANT SELECT ON apidb.WorkflowStep TO gus_r;

CREATE SEQUENCE apidb.WorkflowStep_sq;

GRANT SELECT ON apidb.WorkflowStep_sq TO gus_r;
GRANT SELECT ON apidb.WorkflowStep_sq TO gus_w;

-----------------------------------------------------------

create table WorkflowStepDependency (
  workflow_step_dependency_id number(10),
  parent number(10),
  child number(10)
)

ALTER TABLE apidb.WorkflowStepDependency
ADD CONSTRAINT workflow_step_d_pk PRIMARY KEY (workflow_step_dependency_id);

ALTER TABLE apidb.WorkflowStepDependency
ADD CONSTRAINT workflow_step_fk1 FOREIGN KEY (parent_id)
REFERENCES apidb.Workflow (workflow_step_id);

ALTER TABLE apidb.WorkflowStepDependency
ADD CONSTRAINT workflow_step_fk2 FOREIGN KEY (child_id)
REFERENCES apidb.Workflow (workflow_step_id);

ALTER TABLE apidb.WorkflowStepDependency
ADD CONSTRAINT workflow_step_d_uniq
UNIQUE (parent_id, child_id)

GRANT INSERT, SELECT, UPDATE, DELETE ON apidb.WorkflowStepDependency TO gus_w;
GRANT SELECT ON apidb.WorkflowStepDependency TO gus_r;

CREATE SEQUENCE apidb.WorkflowStepDependency_sq;

GRANT SELECT ON apidb.WorkflowStepDependency_sq TO gus_r;
GRANT SELECT ON apidb.WorkflowStepDependency_sq TO gus_w;

