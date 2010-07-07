CREATE TABLE apidb.OrganismProject (
 organism_project_id          NUMBER(12) NOT NULL,
 organism                     VARCHAR2(100) NOT NULL,
 project                      VARCHAR2(20) NOT NULL,
 modification_date            DATE NOT NULL,
 user_read                    NUMBER(1) NOT NULL,
 user_write                   NUMBER(1) NOT NULL,
 group_read                   NUMBER(1) NOT NULL,
 group_write                  NUMBER(1) NOT NULL,
 other_read                   NUMBER(1) NOT NULL,
 other_write                  NUMBER(1) NOT NULL,
 row_user_id                  NUMBER(12) NOT NULL,
 row_group_id                 NUMBER(3) NOT NULL,
 row_project_id               NUMBER(4) NOT NULL,
 row_alg_invocation_id        NUMBER(12) NOT NULL
);

ALTER TABLE apidb.OrganismProject
ADD CONSTRAINT og_pk PRIMARY KEY (organism_project_id);

ALTER TABLE apidb.OrganismProject
ADD CONSTRAINT workflow_uniq
UNIQUE (organism, project);

GRANT INSERT, SELECT, UPDATE, DELETE ON apidb.OrganismProject TO gus_w;
GRANT SELECT ON apidb.OrganismProject TO gus_r;

CREATE SEQUENCE apidb.OrganismProject_sq;

exit;
