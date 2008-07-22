create table Workflow (
  workflow_id   number(10), 
  name          varchar(30),  -- name and version are an alternate key
  version       varchar(30),
  state         varchar(30),
  metaconfig    clob,
);

create table WorkflowStep (
  workflow_step_id    number(10),
  workflow_id         number(10),
  host_machine        varchar(30),
  wrapper_process_id  number(10),
  state               varchar(30),
  state_handled       number(1),
);

create table WorkflowStepDependency (
  parent number(10),
  child number(10)
)

