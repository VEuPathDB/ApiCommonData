DROP TABLE comments2.PhenotypeMutantMarker;
DROP TABLE comments2.MutantMarker;
DROP TABLE comments2.Phenotype;

DROP SEQUENCE comments2.phenotype_pkseq; 

CREATE TABLE comments2.Phenotype
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
  CONSTRAINT phenotype_key PRIMARY KEY (phenotype_id),
  CONSTRAINT comment_id_phenotype_fkey FOREIGN KEY (comment_id)
     REFERENCES comments2.comments (comment_id)
);

GRANT insert, update, delete on comments2.Phenotype to GUS_W;
GRANT select on comments2.Phenotype to GUS_R;

CREATE SEQUENCE comments2.phenotype_pkseq START WITH 1 INCREMENT BY 1;

GRANT select on comments2.phenotype_pkseq to GUS_W;
GRANT select on comments2.phenotype_pkseq to GUS_R;

CREATE TABLE comments2.MutantStatus
(
  mutant_status_id NUMBER(2) NOT NULL,
  mutant_status VARCHAR2(50) NOT NULL,
  CONSTRAINT mutant_status_id_key PRIMARY KEY (mutant_status_id)
);

GRANT insert, update, delete on comments2.MutantStatus to GUS_W;
GRANT select on comments2.MutantStatus to GUS_R;

INSERT INTO comments2.MutantStatus VALUES(1, 'Successful/Available');
INSERT INTO comments2.MutantStatus VALUES(2, 'Failed/Unavailable');
INSERT INTO comments2.MutantStatus VALUES(3, 'In Progress');

CREATE TABLE comments2.MutantType
(
  mutant_type_id NUMBER(2) NOT NULL,
  mutant_type VARCHAR2(50) NOT NULL,
  CONSTRAINT mutant_type_id_key PRIMARY KEY (mutant_type_id)
);

GRANT insert, update, delete on comments2.MutantType to GUS_W;
GRANT select on comments2.MutantType to GUS_R;

INSERT INTO comments2.MutantType VALUES(1, 'Gene knock out');
INSERT INTO comments2.MutantType VALUES(2, 'Gene knock in');
INSERT INTO comments2.MutantType VALUES(3, 'Induced mutation');
INSERT INTO comments2.MutantType VALUES(4, 'Inducible/Conditonal mutation');
INSERT INTO comments2.MutantType VALUES(5, 'Random insertion');
INSERT INTO comments2.MutantType VALUES(6, 'Point mutation');
INSERT INTO comments2.MutantType VALUES(7, 'Transient/Knock down');
INSERT INTO comments2.MutantType VALUES(8, 'Dominant negative');
INSERT INTO comments2.MutantType VALUES(9, 'Spontaneous');

CREATE TABLE comments2.MutantMethod
(
  mutant_method_id NUMBER(2) NOT NULL,
  mutant_method VARCHAR2(50) NOT NULL,
  CONSTRAINT mutant_method_id_key PRIMARY KEY (mutant_method_id)
);

GRANT insert, update, delete on comments2.MutantMethod to GUS_W;
GRANT select on comments2.MutantMethod to GUS_R;

INSERT INTO comments2.MutantMethod VALUES(1, 'Transgene (over)expression');
INSERT INTO comments2.MutantMethod VALUES(2, 'Pharmaccological KO');
INSERT INTO comments2.MutantMethod VALUES(3, 'Homologous recombination (DKO)');
INSERT INTO comments2.MutantMethod VALUES(4, 'Spontaneous mutant');
INSERT INTO comments2.MutantMethod VALUES(5, 'ENU mutagenesis');
INSERT INTO comments2.MutantMethod VALUES(6, 'Xray mutagenesis');
INSERT INTO comments2.MutantMethod VALUES(7, 'DKO');
INSERT INTO comments2.MutantMethod VALUES(8, 'Conditional KO');
INSERT INTO comments2.MutantMethod VALUES(9, 'Destabilization');
INSERT INTO comments2.MutantMethod VALUES(10, 'Antisense/siRNA');
INSERT INTO comments2.MutantMethod VALUES(11, 'Other');

CREATE TABLE comments2.MutantCategory
(
  mutant_category_id NUMBER(2) NOT NULL,
  mutant_category VARCHAR2(50) NOT NULL,
  CONSTRAINT mutant_category_id_key PRIMARY KEY (mutant_category_id)
);

GRANT insert, update, delete on comments2.MutantCategory to GUS_W;
GRANT select on comments2.MutantCategory to GUS_R;

INSERT INTO comments2.MutantCategory VALUES(1, 'Growth');
INSERT INTO comments2.MutantCategory VALUES(2, 'Invasion');
INSERT INTO comments2.MutantCategory VALUES(3, 'Motility');
INSERT INTO comments2.MutantCategory VALUES(4, 'Differentiation');
INSERT INTO comments2.MutantCategory VALUES(5, 'Replication');
INSERT INTO comments2.MutantCategory VALUES(6, 'EGRESS');
INSERT INTO comments2.MutantCategory VALUES(7, 'Host Response');
INSERT INTO comments2.MutantCategory VALUES(8, 'Other');

CREATE TABLE comments2.PhenotypeMutantCategory
(
  comment_mutant_category_id NUMBER(10) NOT NULL,
  comment_id NUMBER(10) NOT NULL,
  mutant_category_id NUMBER(10) NOT NULL,
  CONSTRAINT comment_mutant_category_key PRIMARY KEY (comment_mutant_category_id),
  CONSTRAINT pmc_category_fkey FOREIGN KEY (comment_id)
     REFERENCES comments2.comments (comment_id),
  CONSTRAINT comment_mutant_category_fkey FOREIGN KEY (mutant_category_id)
     REFERENCES comments2.MutantCategory (mutant_category_id)
);

GRANT insert, update, delete on comments2.PhenotypeMutantCategory to GUS_W;
GRANT select on comments2.PhenotypeMutantCategory to GUS_R;

CREATE SEQUENCE comments2.phenotypeMutantCategory_pkseq START WITH 1 INCREMENT BY 1;

GRANT select on comments2.phenotypeMutantCategory_pkseq to GUS_W;
GRANT select on comments2.phenotypeMutantCategory_pkseq to GUS_R; 

CREATE TABLE comments2.MutantExpression
(
  mutant_expression_id NUMBER(2) NOT NULL,
  mutant_expression VARCHAR2(50) NOT NULL,
  CONSTRAINT mutant_expression_id_key PRIMARY KEY (mutant_expression_id)
);

GRANT insert, update, delete on comments2.MutantExpression to GUS_W;
GRANT select on comments2.MutantExpression to GUS_R;

INSERT INTO comments2.MutantExpression VALUES(1, 'Stable');
INSERT INTO comments2.MutantExpression VALUES(2, 'Transient');
INSERT INTO comments2.MutantExpression VALUES(3, 'Don''t know');

CREATE TABLE comments2.MutantMarker
(
  mutant_marker_id NUMBER(2) NOT NULL,
  mutant_marker VARCHAR2(50) NOT NULL,
  CONSTRAINT mutant_marker_id_key PRIMARY KEY (mutant_marker_id)
);

GRANT insert, update, delete on comments2.MutantMarker to GUS_W;
GRANT select on comments2.MutantMarker to GUS_R;

INSERT INTO comments2.MutantMarker VALUES(1, 'ble');
INSERT INTO comments2.MutantMarker VALUES(2, 'dhfr');
INSERT INTO comments2.MutantMarker VALUES(3, 'hxgprt');
INSERT INTO comments2.MutantMarker VALUES(4, 'cat');
INSERT INTO comments2.MutantMarker VALUES(5, 'neo');
INSERT INTO comments2.MutantMarker VALUES(6, 'bsd');
INSERT INTO comments2.MutantMarker VALUES(7, 'hph');
INSERT INTO comments2.MutantMarker VALUES(8, 'pac');
INSERT INTO comments2.MutantMarker VALUES(9, 'other');

CREATE TABLE comments2.PhenotypeMutantMarker
(
  comment_mutant_marker_id NUMBER(10) NOT NULL,
  comment_id NUMBER(10) NOT NULL,
  mutant_marker_id NUMBER(10) NOT NULL,
  CONSTRAINT comment_mutant_marker_key PRIMARY KEY (comment_mutant_marker_id),
  CONSTRAINT comment_id_mutant_marker_fkey FOREIGN KEY (comment_id)
     REFERENCES comments2.comments (comment_id),
  CONSTRAINT comment_mutant_marker_fkey FOREIGN KEY (mutant_marker_id)
     REFERENCES comments2.MutantMarker (mutant_marker_id)
);

GRANT insert, update, delete on comments2.PhenotypeMutantMarker to GUS_W;
GRANT select on comments2.PhenotypeMutantMarker to GUS_R;

CREATE SEQUENCE comments2.commentMutantMarker_pkseq START WITH 1 INCREMENT BY 1;

GRANT select on comments2.commentMutantMarker_pkseq to GUS_W;
GRANT select on comments2.commentMutantMarker_pkseq to GUS_R;

CREATE TABLE comments2.MutantReporter
(
  mutant_reporter_id NUMBER(2) NOT NULL,
  mutant_reporter VARCHAR2(50) NOT NULL,
  CONSTRAINT mutant_reporter_id_key PRIMARY KEY (mutant_reporter_id)
);

GRANT insert, update, delete on comments2.MutantReporter to GUS_W;
GRANT select on comments2.MutantReporter to GUS_R;

INSERT INTO comments2.MutantReporter VALUES(1, 'Luciferase');
INSERT INTO comments2.MutantReporter VALUES(2, 'Fluorescent Protein (GFP, RFP, etc)');
INSERT INTO comments2.MutantReporter VALUES(3, 'CAT');
INSERT INTO comments2.MutantReporter VALUES(4, 'beta-galactosidase');
INSERT INTO comments2.MutantReporter VALUES(5, 'Other');

CREATE TABLE comments2.PhenotypeMutantReporter
(
  comment_mutant_reporter_id NUMBER(10) NOT NULL,
  comment_id NUMBER(10) NOT NULL,
  mutant_reporter_id NUMBER(10) NOT NULL,
  CONSTRAINT comment_mutant_reporter_key PRIMARY KEY (comment_mutant_reporter_id),
  CONSTRAINT comment_id_reporter_fkey FOREIGN KEY (comment_id)
     REFERENCES comments2.comments (comment_id),
  CONSTRAINT comment_reporter_fkey FOREIGN KEY (mutant_reporter_id)
     REFERENCES comments2.MutantReporter (mutant_reporter_id)
);

GRANT insert, update, delete on comments2.PhenotypeMutantReporter to GUS_W;
GRANT select on comments2.PhenotypeMutantReporter to GUS_R;

CREATE SEQUENCE comments2.commentMutantReporter_pkseq START WITH 1 INCREMENT BY 1;

GRANT select on comments2.commentMutantReporter_pkseq to GUS_W;
GRANT select on comments2.commentMutantReporter_pkseq to GUS_R;

