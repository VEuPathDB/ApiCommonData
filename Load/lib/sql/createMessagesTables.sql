DROP TABLE ryanthib.messages; 
DROP TABLE ryanthib.projects;
DROP TABLE ryanthib.category;
DROP TABLE ryanthib.message_projects;


CREATE TABLE ryanthib.messages
(
  message_id NUMBER(7) NOT NULL,
  message_text VARCHAR(4000) NOT NULL,
  message_category VARCHAR(150) NOT NULL,
  start_date DATE NOT NULL,
  stop_date  DATE NOT NULL,
  admin_comments VARCHAR(4000),
  time_submitted TIMESTAMP NOT NULL,
  CONSTRAINT messages_pkey PRIMARY KEY (message_id)  
);

CREATE TABLE ryanthib.projects
(
  project_id NUMBER(3) NOT NULL,
  project_name VARCHAR(150) NOT NULL,
  CONSTRAINT projects_pkey PRIMARY KEY (project_id)
);

CREATE TABLE ryanthib.category
(
  category_id NUMBER(3) NOT NULL, 
  category_name VARCHAR(150) NOT NULL,
  CONSTRAINT category_pkey PRIMARY KEY (category_id)
);

CREATE TABLE ryanthib.message_projects
(
  message_id NUMBER(3) NOT NULL,
  project_id NUMBER(3) NOT NULL,
  CONSTRAINT message_id_fkey FOREIGN KEY (message_id) REFERENCES ryanthib.messages(message_id),
  CONSTRAINT project_id_fkey FOREIGN KEY (project_id) REFERENCES ryanthib.projects(project_id)
);

CREATE SEQUENCE ryanthib.messages_id_pkseq START WITH 1 INCREMENT BY 1 NOMAXVALUE;

CREATE SEQUENCE ryanthib.projects_id_pkseq START WITH 1 INCREMENT BY 1 NOMAXVALUE;

CREATE SEQUENCE ryanthib.category_id_pkseq START WITH 1 INCREMENT BY 1 NOMAXVALUE;

exit
