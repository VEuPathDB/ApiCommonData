-- Create schema announce.

DROP TABLE announce.messages; 
DROP TABLE announce.projects;
DROP TABLE announce.category;
DROP TABLE announce.message_projects;


CREATE TABLE announce.messages
(
  message_id NUMBER(10) NOT NULL,
  message_text VARCHAR2(4000) NOT NULL,
  message_category VARCHAR2(150) NOT NULL,
  start_date DATE NOT NULL,
  stop_date  DATE NOT NULL,
  admin_comments VARCHAR2(4000),
  time_submitted TIMESTAMP NOT NULL,
  CONSTRAINT messages_pkey PRIMARY KEY (message_id)  
);

CREATE TABLE announce.projects
(
  project_id NUMBER(3) NOT NULL,
  project_name VARCHAR2(150) NOT NULL,
  CONSTRAINT projects_pkey PRIMARY KEY (project_id)
);

CREATE TABLE announce.category
(
  category_id NUMBER(3) NOT NULL, 
  category_name VARCHAR2(150) NOT NULL,
  CONSTRAINT category_pkey PRIMARY KEY (category_id)
);

CREATE TABLE announce.message_projects
(
  message_id NUMBER(10) NOT NULL,
  project_id NUMBER(3) NOT NULL,
  CONSTRAINT message_id_fkey FOREIGN KEY (message_id) REFERENCES announce.messages(message_id),
  CONSTRAINT project_id_fkey FOREIGN KEY (project_id) REFERENCES announce.projects(project_id)
);

DROP SEQUENCE announce.messages_id_pkseq;
DROP SEQUENCE announce.projects_id_pkseq;
DROP SEQUENCE announce.category_id_pkseq;

-- Will announce need to be replicated?

CREATE SEQUENCE announce.messages_id_pkseq START WITH 10 INCREMENT BY 10 NOMAXVALUE;
CREATE SEQUENCE announce.projects_id_pkseq START WITH 10 INCREMENT BY 10 NOMAXVALUE;
CREATE SEQUENCE announce.category_id_pkseq START WITH 10 INCREMENT BY 10 NOMAXVALUE;

INSERT INTO projects (project_id, project_name) VALUES (projects_id_pkseq.nextval, 'CryptoDB');
INSERT INTO projects (project_Id, project_name) VALUES (projects_id_pkseq.nextval, 'GiardiaDB');
INSERT INTO projects (project_Id, project_name) VALUES (projects_id_pkseq.nextval, 'PlasmoDB');
INSERT INTO projects (project_Id, project_name) VALUES (projects_id_pkseq.nextval, 'ToxoDB');
INSERT INTO projects (project_Id, project_name) VALUES (projects_id_pkseq.nextval, 'TrichDB');

INSERT INTO category (category_id, category_name) VALUES (category_id_pkseq.nextval, 'Information');
INSERT INTO category (category_id, category_name) VALUES (category_id_pkseq.nextval, 'Degraded');
INSERT INTO category (category_id, category_name) VALUES (category_id_pkseq.nextval, 'Down');

------------------------------

grant delete on announce.messages to uga_fed; 
grant insert on announce.messages to uga_fed;
grant select on announce.messages to uga_fed;
grant update on announce.messages to uga_fed;

grant delete on announce.projects to uga_fed;
grant insert on announce.projects to uga_fed;
grant select on announce.projects to uga_fed;
grant update on announce.projects to uga_fed;

grant delete on announce.category to uga_fed;
grant insert on announce.category to uga_fed;
grant select on announce.category to uga_fed;
grant update on announce.category to uga_fed;

grant delete on announce.message_projects to uga_fed;
grant insert on announce.message_projects to uga_fed;
grant select on announce.message_projects to uga_fed;
grant update on announce.message_projects to uga_fed;

grant select on announce.messages_id_pkseq to uga_fed;
grant select on announce.projects_id_pkseq to uga_fed;
grant select on announce.category_id_pkseq to uga_fed;
