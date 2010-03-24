DROP TABLE apidb.WorkflowStepDependency;
DROP SEQUENCE apidb.WorkflowStepDependency_sq;

DROP TABLE apidb.WorkflowStepAlgInvocation;
DROP SEQUENCE apidb.WorkflowStepAlgInvocation_sq;

ALTER TABLE apidb.Workflow DROP CONSTRAINT workflow_fk1;

DROP TABLE apidb.WorkflowStep;
DROP SEQUENCE apidb.WorkflowStep_sq;

DROP TABLE apidb.Workflow;
DROP SEQUENCE apidb.Workflow_sq;
 
exit;
