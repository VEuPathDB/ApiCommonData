DROP TABLE userlogins5.PhenotypeMutantCategory;
DROP TABLE userlogins5.MutantCategory;
DROP TABLE userlogins5.PhenotypeMutantReporter;
DROP TABLE userlogins5.MutantReporter;
DROP TABLE userlogins5.PhenotypeMutantMarker;
DROP TABLE userlogins5.MutantMarker;
DROP TABLE userlogins5.MutantStatus;
DROP TABLE userlogins5.MutantType;
DROP TABLE userlogins5.MutantMethod;
DROP TABLE userlogins5.PhenotypeLoc; 
DROP TABLE userlogins5.MutantExpression; 
DROP TABLE userlogins5.Phenotype;

DROP SEQUENCE userlogins5.phenotype_pkseq; 
DROP SEQUENCE userlogins5.phenotypeMutantCategory_pkseq; 
DROP SEQUENCE userlogins5.commentMutantMarker_pkseq; 
DROP SEQUENCE userlogins5.commentMutantReporter_pkseq; 

CREATE TABLE userlogins5.Phenotype
(
  phenotype_id NUMBER(10) NOT NULL,
  comment_id NUMBER(10) NOT NULL,
  background VARCHAR2(200),
  mutant_status_id NUMBER(2),
  mutant_type_id NUMBER(2),
  mutant_method_id NUMBER(2),
  mutant_description VARCHAR2(4000),
  phenotype_description VARCHAR2(4000),
  phenotype_category_id NUMBER(2),
  mutant_expression_id NUMBER(2),
  phenotype_loc_id NUMBER(2),
  CONSTRAINT phenotype_key PRIMARY KEY (phenotype_id),
  CONSTRAINT comment_id_phenotype_fkey FOREIGN KEY (comment_id)
     REFERENCES userlogins5.comments (comment_id)
);

GRANT insert, update, delete on userlogins5.Phenotype to GUS_W;
GRANT select on userlogins5.Phenotype to GUS_R;

CREATE SEQUENCE userlogins5.phenotype_pkseq START WITH 1 INCREMENT BY 1;

GRANT select on userlogins5.phenotype_pkseq to GUS_W;
GRANT select on userlogins5.phenotype_pkseq to GUS_R;

CREATE TABLE userlogins5.MutantStatus
(
  mutant_status_id NUMBER(2) NOT NULL,
  mutant_status VARCHAR2(50) NOT NULL,
  CONSTRAINT mutant_status_id_key PRIMARY KEY (mutant_status_id)
);

GRANT insert, update, delete on userlogins5.MutantStatus to GUS_W;
GRANT select on userlogins5.MutantStatus to GUS_R;

INSERT INTO userlogins5.MutantStatus VALUES(1, 'Successful');
INSERT INTO userlogins5.MutantStatus VALUES(2, 'Failed');
INSERT INTO userlogins5.MutantStatus VALUES(3, 'In Progress');

CREATE TABLE userlogins5.MutantType
(
  mutant_type_id NUMBER(2) NOT NULL,
  mutant_type VARCHAR2(50) NOT NULL,
  CONSTRAINT mutant_type_id_key PRIMARY KEY (mutant_type_id)
);

GRANT insert, update, delete on userlogins5.MutantType to GUS_W;
GRANT select on userlogins5.MutantType to GUS_R;

INSERT INTO userlogins5.MutantType VALUES(1, 'Gene knock out');
INSERT INTO userlogins5.MutantType VALUES(2, 'Gene knock in');
INSERT INTO userlogins5.MutantType VALUES(3, 'Induced mutation');
INSERT INTO userlogins5.MutantType VALUES(4, 'Inducible/Conditonal mutation');
INSERT INTO userlogins5.MutantType VALUES(5, 'Random insertion');
INSERT INTO userlogins5.MutantType VALUES(6, 'Point mutation');
INSERT INTO userlogins5.MutantType VALUES(7, 'Transient/Knock down');
INSERT INTO userlogins5.MutantType VALUES(8, 'Dominant negative');
INSERT INTO userlogins5.MutantType VALUES(9, 'Spontaneous');
INSERT INTO userlogins5.MutantType VALUES(10, 'Other');

CREATE TABLE userlogins5.MutantMethod
(
  mutant_method_id NUMBER(2) NOT NULL,
  mutant_method VARCHAR2(50) NOT NULL,
  CONSTRAINT mutant_method_id_key PRIMARY KEY (mutant_method_id)
);

GRANT insert, update, delete on userlogins5.MutantMethod to GUS_W;
GRANT select on userlogins5.MutantMethod to GUS_R;

INSERT INTO userlogins5.MutantMethod VALUES(1, 'Transgene (over)expression');
INSERT INTO userlogins5.MutantMethod VALUES(2, 'Pharmaccological KO');
INSERT INTO userlogins5.MutantMethod VALUES(3, 'Homologous recombination (DKO)');
INSERT INTO userlogins5.MutantMethod VALUES(4, 'Spontaneous mutant');
INSERT INTO userlogins5.MutantMethod VALUES(5, 'ENU mutagenesis');
INSERT INTO userlogins5.MutantMethod VALUES(6, 'Xray mutagenesis');
INSERT INTO userlogins5.MutantMethod VALUES(7, 'DKO');
INSERT INTO userlogins5.MutantMethod VALUES(8, 'Conditional KO');
INSERT INTO userlogins5.MutantMethod VALUES(9, 'Destabilization');
INSERT INTO userlogins5.MutantMethod VALUES(10, 'Antisense/siRNA');
INSERT INTO userlogins5.MutantMethod VALUES(11, 'Other');

CREATE TABLE userlogins5.PhenotypeLoc
(
  phenotype_loc_id NUMBER(2) NOT NULL,
  phenotype_loc VARCHAR2(50) NOT NULL,
  CONSTRAINT phenotype_loc_id_key PRIMARY KEY (phenotype_loc_id)
);

GRANT insert, update, delete on userlogins5.PhenotypeLoc to GUS_W;
GRANT select on userlogins5.PhenotypeLoc to GUS_R;

INSERT INTO userlogins5.PhenotypeLoc VALUES(1, 'in vitro');
INSERT INTO userlogins5.PhenotypeLoc VALUES(2, 'in vivo');
INSERT INTO userlogins5.PhenotypeLoc VALUES(3, 'Both');

CREATE TABLE userlogins5.MutantCategory
(
  mutant_category_id NUMBER(2) NOT NULL,
  mutant_category VARCHAR2(50) NOT NULL,
  CONSTRAINT mutant_category_id_key PRIMARY KEY (mutant_category_id)
);

GRANT insert, update, delete on userlogins5.MutantCategory to GUS_W;
GRANT select on userlogins5.MutantCategory to GUS_R;

INSERT INTO userlogins5.MutantCategory VALUES(1, 'Growth');
INSERT INTO userlogins5.MutantCategory VALUES(2, 'Invasion');
INSERT INTO userlogins5.MutantCategory VALUES(3, 'Motility');
INSERT INTO userlogins5.MutantCategory VALUES(4, 'Differentiation');
INSERT INTO userlogins5.MutantCategory VALUES(5, 'Replication');
INSERT INTO userlogins5.MutantCategory VALUES(6, 'EGRESS');
INSERT INTO userlogins5.MutantCategory VALUES(7, 'Host Response');
INSERT INTO userlogins5.MutantCategory VALUES(8, 'Other');

CREATE TABLE userlogins5.PhenotypeMutantCategory
(
  comment_mutant_category_id NUMBER(10) NOT NULL,
  comment_id NUMBER(10) NOT NULL,
  mutant_category_id NUMBER(10) NOT NULL,
  CONSTRAINT comment_mutant_category_key PRIMARY KEY (comment_mutant_category_id),
  CONSTRAINT pmc_category_fkey FOREIGN KEY (comment_id)
     REFERENCES userlogins5.comments (comment_id),
  CONSTRAINT comment_mutant_category_fkey FOREIGN KEY (mutant_category_id)
     REFERENCES userlogins5.MutantCategory (mutant_category_id)
);

GRANT insert, update, delete on userlogins5.PhenotypeMutantCategory to GUS_W;
GRANT select on userlogins5.PhenotypeMutantCategory to GUS_R;

CREATE SEQUENCE userlogins5.phenotypeMutantCategory_pkseq START WITH 1 INCREMENT BY 1;

GRANT select on userlogins5.phenotypeMutantCategory_pkseq to GUS_W;
GRANT select on userlogins5.phenotypeMutantCategory_pkseq to GUS_R; 

CREATE TABLE userlogins5.MutantExpression
(
  mutant_expression_id NUMBER(2) NOT NULL,
  mutant_expression VARCHAR2(50) NOT NULL,
  CONSTRAINT mutant_expression_id_key PRIMARY KEY (mutant_expression_id)
);

GRANT insert, update, delete on userlogins5.MutantExpression to GUS_W;
GRANT select on userlogins5.MutantExpression to GUS_R;

INSERT INTO userlogins5.MutantExpression VALUES(1, 'Stable');
INSERT INTO userlogins5.MutantExpression VALUES(2, 'Transient');
INSERT INTO userlogins5.MutantExpression VALUES(3, 'Don''t know');

CREATE TABLE userlogins5.MutantMarker
(
  mutant_marker_id NUMBER(2) NOT NULL,
  mutant_marker VARCHAR2(50) NOT NULL,
  CONSTRAINT mutant_marker_id_key PRIMARY KEY (mutant_marker_id)
);

GRANT insert, update, delete on userlogins5.MutantMarker to GUS_W;
GRANT select on userlogins5.MutantMarker to GUS_R;

INSERT INTO userlogins5.MutantMarker VALUES(1, 'ble');
INSERT INTO userlogins5.MutantMarker VALUES(2, 'dhfr');
INSERT INTO userlogins5.MutantMarker VALUES(3, 'hxgprt');
INSERT INTO userlogins5.MutantMarker VALUES(4, 'cat');
INSERT INTO userlogins5.MutantMarker VALUES(5, 'neo');
INSERT INTO userlogins5.MutantMarker VALUES(6, 'bsd');
INSERT INTO userlogins5.MutantMarker VALUES(7, 'hph');
INSERT INTO userlogins5.MutantMarker VALUES(8, 'pac');
INSERT INTO userlogins5.MutantMarker VALUES(9, 'other');

CREATE TABLE userlogins5.PhenotypeMutantMarker
(
  comment_mutant_marker_id NUMBER(10) NOT NULL,
  comment_id NUMBER(10) NOT NULL,
  mutant_marker_id NUMBER(10) NOT NULL,
  CONSTRAINT comment_mutant_marker_key PRIMARY KEY (comment_mutant_marker_id),
  CONSTRAINT comment_id_mutant_marker_fkey FOREIGN KEY (comment_id)
     REFERENCES userlogins5.comments (comment_id),
  CONSTRAINT comment_mutant_marker_fkey FOREIGN KEY (mutant_marker_id)
     REFERENCES userlogins5.MutantMarker (mutant_marker_id)
);

GRANT insert, update, delete on userlogins5.PhenotypeMutantMarker to GUS_W;
GRANT select on userlogins5.PhenotypeMutantMarker to GUS_R;

CREATE SEQUENCE userlogins5.commentMutantMarker_pkseq START WITH 1 INCREMENT BY 1;

GRANT select on userlogins5.commentMutantMarker_pkseq to GUS_W;
GRANT select on userlogins5.commentMutantMarker_pkseq to GUS_R;

CREATE TABLE userlogins5.MutantReporter
(
  mutant_reporter_id NUMBER(2) NOT NULL,
  mutant_reporter VARCHAR2(50) NOT NULL,
  CONSTRAINT mutant_reporter_id_key PRIMARY KEY (mutant_reporter_id)
);

GRANT insert, update, delete on userlogins5.MutantReporter to GUS_W;
GRANT select on userlogins5.MutantReporter to GUS_R;

INSERT INTO userlogins5.MutantReporter VALUES(1, 'Luciferase');
INSERT INTO userlogins5.MutantReporter VALUES(2, 'Fluorescent Protein (GFP, RFP, etc)');
INSERT INTO userlogins5.MutantReporter VALUES(3, 'CAT');
INSERT INTO userlogins5.MutantReporter VALUES(4, 'beta-galactosidase');
INSERT INTO userlogins5.MutantReporter VALUES(5, 'Other');

CREATE TABLE userlogins5.PhenotypeMutantReporter
(
  comment_mutant_reporter_id NUMBER(10) NOT NULL,
  comment_id NUMBER(10) NOT NULL,
  mutant_reporter_id NUMBER(10) NOT NULL,
  CONSTRAINT comment_mutant_reporter_key PRIMARY KEY (comment_mutant_reporter_id),
  CONSTRAINT comment_id_reporter_fkey FOREIGN KEY (comment_id)
     REFERENCES userlogins5.comments (comment_id),
  CONSTRAINT comment_reporter_fkey FOREIGN KEY (mutant_reporter_id)
     REFERENCES userlogins5.MutantReporter (mutant_reporter_id)
);

GRANT insert, update, delete on userlogins5.PhenotypeMutantReporter to GUS_W;
GRANT select on userlogins5.PhenotypeMutantReporter to GUS_R;

CREATE SEQUENCE userlogins5.commentMutantReporter_pkseq START WITH 1 INCREMENT BY 1;

GRANT select on userlogins5.commentMutantReporter_pkseq to GUS_W;
GRANT select on userlogins5.commentMutantReporter_pkseq to GUS_R;

