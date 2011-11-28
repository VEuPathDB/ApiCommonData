CREATE TABLE apidb.OrthologGroup (
 ortholog_group_id            NUMBER(12) NOT NULL,
 subclass_view                VARCHAR2(30) NOT NULL,
 name                         VARCHAR2(500),
 description                  VARCHAR2(2000),
 number_of_members            NUMBER(12) NOT NULL,
 avg_percent_identity         FLOAT,
 avg_percent_match            FLOAT,
 avg_evalue_mant              FLOAT,
 avg_evalue_exp               NUMBER,
 avg_connectivity             FLOAT(126),
 number_of_match_pairs        NUMBER,
 aa_seq_group_experiment_id   NUMBER(12),
 external_database_release_id NUMBER(10) NOT NULL,
 multiple_sequence_alignment  CLOB,
 biolayout_image              BLOB,
 svg_content                  CLOB,
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

ALTER TABLE apidb.OrthologGroup
ADD CONSTRAINT og_pk PRIMARY KEY (ortholog_group_id);

ALTER TABLE apidb.OrthologGroup
ADD CONSTRAINT og_fk1 FOREIGN KEY (external_database_release_id)
REFERENCES sres.ExternalDatabaseRelease;

CREATE INDEX apidb.OrthologGroup_revix
ON apidb.OrthologGroup (external_database_release_id, ortholog_group_id);

GRANT INSERT, SELECT, UPDATE, DELETE ON apidb.OrthologGroup TO gus_w;
GRANT SELECT ON apidb.OrthologGroup TO gus_r;

CREATE INDEX apidb.og_name_ix ON apidb.OrthologGroup (name, ortholog_group_id);
CREATE INDEX apidb.og_mem_ix ON apidb.OrthologGroup (number_of_members, ortholog_group_id);

------------------------------------------------------------------------------

CREATE SEQUENCE apidb.OrthologGroup_sq;

GRANT SELECT ON apidb.OrthologGroup_sq TO gus_r;
GRANT SELECT ON apidb.OrthologGroup_sq TO gus_w;

------------------------------------------------------------------------------

INSERT INTO core.TableInfo
    (table_id, name, table_type, primary_key_column, database_id, is_versioned,
     is_view, view_on_table_id, superclass_table_id, is_updatable, 
     modification_date, user_read, user_write, group_read, group_write, 
     other_read, other_write, row_user_id, row_group_id, row_project_id, 
     row_alg_invocation_id)
SELECT core.tableinfo_sq.nextval, 'OrthologGroup',
       'Standard', 'ORTHOLOG_GROUP_ID',
       d.database_id, 0, 0, '', '', 1,sysdate, 1, 1, 1, 1, 1, 1, 1, 1,
       p.project_id, 0
FROM dual,
     (SELECT MAX(project_id) AS project_id FROM core.ProjectInfo) p,
     (SELECT database_id FROM core.DatabaseInfo WHERE lower(name) = 'apidb') d
WHERE 'orthologgroup' NOT IN (SELECT lower(name) FROM core.TableInfo
                                    where database_id = d.database_id);

------------------------------------------------------------------------------
------------------------------------------------------------------------------
CREATE TABLE apidb.OrthomclTaxon (
 orthomcl_taxon_id             NUMBER(12) NOT NULL,
 parent_id                     NUMBER(12),
 taxon_id                      NUMBER(12),
 name                          VARCHAR(255),
 three_letter_abbrev           VARCHAR(6) NOT NULL,
 is_species                    NUMBER(1) NOT NULL,
 species_order                 NUMBER(4),
 depth_first_index             NUMBER(10) NOT NULL,
 sibling_depth_first_index     NUMBER(10),
 common_name                   VARCHAR(255),
 modification_date             DATE NOT NULL,
 user_read                     NUMBER(1) NOT NULL,
 user_write                    NUMBER(1) NOT NULL,
 group_read                    NUMBER(1) NOT NULL,
 group_write                   NUMBER(1) NOT NULL,
 other_read                    NUMBER(1) NOT NULL,
 other_write                   NUMBER(1) NOT NULL,
 row_user_id                   NUMBER(12) NOT NULL,
 row_group_id                  NUMBER(3) NOT NULL,
 row_project_id                NUMBER(4) NOT NULL,
 row_alg_invocation_id         NUMBER(12) NOT NULL
);

ALTER TABLE apidb.OrthomclTaxon
ADD CONSTRAINT ot_pk PRIMARY KEY (orthomcl_taxon_id);

ALTER TABLE apidb.OrthomclTaxon
ADD CONSTRAINT ot_fk1 FOREIGN KEY (parent_id)
REFERENCES apidb.OrthomclTaxon (orthomcl_taxon_id);

CREATE INDEX apidb.OrthomclTaxon_revix
ON apidb.OrthomclTaxon (parent_id, orthomcl_taxon_id);

ALTER TABLE apidb.OrthomclTaxon
ADD CONSTRAINT ot_fk2 FOREIGN KEY (taxon_id)
REFERENCES sres.Taxon (taxon_id);

GRANT INSERT, SELECT, UPDATE, DELETE ON apidb.OrthomclTaxon TO gus_w;
GRANT SELECT ON apidb.OrthomclTaxon TO gus_r;

------------------------------------------------------------------------------

CREATE SEQUENCE apidb.OrthomclTaxon_sq;

GRANT SELECT ON apidb.OrthomclTaxon_sq TO gus_r;
GRANT SELECT ON apidb.OrthomclTaxon_sq TO gus_w;

------------------------------------------------------------------------------

INSERT INTO core.TableInfo
    (table_id, name, table_type, primary_key_column, database_id, is_versioned,
     is_view, view_on_table_id, superclass_table_id, is_updatable, 
     modification_date, user_read, user_write, group_read, group_write, 
     other_read, other_write, row_user_id, row_group_id, row_project_id, 
     row_alg_invocation_id)
SELECT core.tableinfo_sq.nextval, 'OrthomclTaxon',
       'Standard', 'ORTHOMCL_TAXON_ID',
       d.database_id, 0, 0, '', '', 1,sysdate, 1, 1, 1, 1, 1, 1, 1, 1,
       p.project_id, 0
FROM dual,
     (SELECT MAX(project_id) AS project_id FROM core.ProjectInfo) p,
     (SELECT database_id FROM core.DatabaseInfo WHERE lower(name) = 'apidb') d
WHERE 'orthomcltaxon' NOT IN (SELECT lower(name) FROM core.TableInfo
                                    where database_id = d.database_id);

------------------------------------------------------------------------------
------------------------------------------------------------------------------
CREATE TABLE apidb.GroupTaxonMatrix (
 group_taxon_matrix_id       NUMBER(12) NOT NULL,
 ortholog_group_id       NUMBER(12) NOT NULL,
 column1                     NUMBER(8),
 column2                     NUMBER(8),
 column3                     NUMBER(8),
 column4                     NUMBER(8),
 column5                     NUMBER(8),
 column6                     NUMBER(8),
 column7                     NUMBER(8),
 column8                     NUMBER(8),
 column9                     NUMBER(8),
 column10                     NUMBER(8),
 column11                     NUMBER(8),
 column12                     NUMBER(8),
 column13                     NUMBER(8),
 column14                     NUMBER(8),
 column15                     NUMBER(8),
 column16                     NUMBER(8),
 column17                     NUMBER(8),
 column18                     NUMBER(8),
 column19                     NUMBER(8),
 column20                     NUMBER(8),
 column21                     NUMBER(8),
 column22                     NUMBER(8),
 column23                     NUMBER(8),
 column24                     NUMBER(8),
 column25                     NUMBER(8),
 column26                     NUMBER(8),
 column27                     NUMBER(8),
 column28                     NUMBER(8),
 column29                     NUMBER(8),
 column30                     NUMBER(8),
 column31                     NUMBER(8),
 column32                     NUMBER(8),
 column33                     NUMBER(8),
 column34                     NUMBER(8),
 column35                     NUMBER(8),
 column36                     NUMBER(8),
 column37                     NUMBER(8),
 column38                     NUMBER(8),
 column39                     NUMBER(8),
 column40                     NUMBER(8),
 column41                     NUMBER(8),
 column42                     NUMBER(8),
 column43                     NUMBER(8),
 column44                     NUMBER(8),
 column45                     NUMBER(8),
 column46                     NUMBER(8),
 column47                     NUMBER(8),
 column48                     NUMBER(8),
 column49                     NUMBER(8),
 column50                     NUMBER(8),
 column51                     NUMBER(8),
 column52                     NUMBER(8),
 column53                     NUMBER(8),
 column54                     NUMBER(8),
 column55                     NUMBER(8),
 column56                     NUMBER(8),
 column57                     NUMBER(8),
 column58                     NUMBER(8),
 column59                     NUMBER(8),
 column60                     NUMBER(8),
 column61                     NUMBER(8),
 column62                     NUMBER(8),
 column63                     NUMBER(8),
 column64                     NUMBER(8),
 column65                     NUMBER(8),
 column66                     NUMBER(8),
 column67                     NUMBER(8),
 column68                     NUMBER(8),
 column69                     NUMBER(8),
 column70                     NUMBER(8),
 column71                     NUMBER(8),
 column72                     NUMBER(8),
 column73                     NUMBER(8),
 column74                     NUMBER(8),
 column75                     NUMBER(8),
 column76                     NUMBER(8),
 column77                     NUMBER(8),
 column78                     NUMBER(8),
 column79                     NUMBER(8),
 column80                     NUMBER(8),
 column81                     NUMBER(8),
 column82                     NUMBER(8),
 column83                     NUMBER(8),
 column84                     NUMBER(8),
 column85                     NUMBER(8),
 column86                     NUMBER(8),
 column87                     NUMBER(8),
 column88                     NUMBER(8),
 column89                     NUMBER(8),
 column90                     NUMBER(8),
 column91                     NUMBER(8),
 column92                     NUMBER(8),
 column93                     NUMBER(8),
 column94                     NUMBER(8),
 column95                     NUMBER(8),
 column96                     NUMBER(8),
 column97                     NUMBER(8),
 column98                     NUMBER(8),
 column99                     NUMBER(8),
 column100                     NUMBER(8),
 column101                     NUMBER(8),
 column102                     NUMBER(8),
 column103                     NUMBER(8),
 column104                     NUMBER(8),
 column105                     NUMBER(8),
 column106                     NUMBER(8),
 column107                     NUMBER(8),
 column108                     NUMBER(8),
 column109                     NUMBER(8),
 column110                     NUMBER(8),
 column111                     NUMBER(8),
 column112                     NUMBER(8),
 column113                     NUMBER(8),
 column114                     NUMBER(8),
 column115                     NUMBER(8),
 column116                     NUMBER(8),
 column117                     NUMBER(8),
 column118                     NUMBER(8),
 column119                     NUMBER(8),
 column120                     NUMBER(8),
 column121                     NUMBER(8),
 column122                     NUMBER(8),
 column123                     NUMBER(8),
 column124                     NUMBER(8),
 column125                     NUMBER(8),
 column126                     NUMBER(8),
 column127                     NUMBER(8),
 column128                     NUMBER(8),
 column129                     NUMBER(8),
 column130                     NUMBER(8),
 column131                     NUMBER(8),
 column132                     NUMBER(8),
 column133                     NUMBER(8),
 column134                     NUMBER(8),
 column135                     NUMBER(8),
 column136                     NUMBER(8),
 column137                     NUMBER(8),
 column138                     NUMBER(8),
 column139                     NUMBER(8),
 column140                     NUMBER(8),
 column141                     NUMBER(8),
 column142                     NUMBER(8),
 column143                     NUMBER(8),
 column144                     NUMBER(8),
 column145                     NUMBER(8),
 column146                     NUMBER(8),
 column147                     NUMBER(8),
 column148                     NUMBER(8),
 column149                     NUMBER(8),
 column150                     NUMBER(8),
 column151                     NUMBER(8),
 column152                     NUMBER(8),
 column153                     NUMBER(8),
 column154                     NUMBER(8),
 column155                     NUMBER(8),
 column156                     NUMBER(8),
 column157                     NUMBER(8),
 column158                     NUMBER(8),
 column159                     NUMBER(8),
 column160                     NUMBER(8),
 column161                     NUMBER(8),
 column162                     NUMBER(8),
 column163                     NUMBER(8),
 column164                     NUMBER(8),
 column165                     NUMBER(8),
 column166                     NUMBER(8),
 column167                     NUMBER(8),
 column168                     NUMBER(8),
 column169                     NUMBER(8),
 column170                     NUMBER(8),
 column171                     NUMBER(8),
 column172                     NUMBER(8),
 column173                     NUMBER(8),
 column174                     NUMBER(8),
 column175                     NUMBER(8),
 column176                     NUMBER(8),
 column177                     NUMBER(8),
 column178                     NUMBER(8),
 column179                     NUMBER(8),
 column180                     NUMBER(8),
 column181                     NUMBER(8),
 column182                     NUMBER(8),
 column183                     NUMBER(8),
 column184                     NUMBER(8),
 column185                     NUMBER(8),
 column186                     NUMBER(8),
 column187                     NUMBER(8),
 column188                     NUMBER(8),
 column189                     NUMBER(8),
 column190                     NUMBER(8),
 column191                     NUMBER(8),
 column192                     NUMBER(8),
 column193                     NUMBER(8),
 column194                     NUMBER(8),
 column195                     NUMBER(8),
 column196                     NUMBER(8),
 column197                     NUMBER(8),
 column198                     NUMBER(8),
 column199                     NUMBER(8),
 column200                     NUMBER(8),
 column201                     NUMBER(8),
 column202                     NUMBER(8),
 column203                     NUMBER(8),
 column204                     NUMBER(8),
 column205                     NUMBER(8),
 column206                     NUMBER(8),
 column207                     NUMBER(8),
 column208                     NUMBER(8),
 column209                     NUMBER(8),
 column210                     NUMBER(8),
 column211                     NUMBER(8),
 column212                     NUMBER(8),
 column213                     NUMBER(8),
 column214                     NUMBER(8),
 column215                     NUMBER(8),
 column216                     NUMBER(8),
 column217                     NUMBER(8),
 column218                     NUMBER(8),
 column219                     NUMBER(8),
 column220                     NUMBER(8),
 column221                     NUMBER(8),
 column222                     NUMBER(8),
 column223                     NUMBER(8),
 column224                     NUMBER(8),
 column225                     NUMBER(8),
 column226                     NUMBER(8),
 column227                     NUMBER(8),
 column228                     NUMBER(8),
 column229                     NUMBER(8),
 column230                     NUMBER(8),
 column231                     NUMBER(8),
 column232                     NUMBER(8),
 column233                     NUMBER(8),
 column234                     NUMBER(8),
 column235                     NUMBER(8),
 column236                     NUMBER(8),
 column237                     NUMBER(8),
 column238                     NUMBER(8),
 column239                     NUMBER(8),
 column240                     NUMBER(8),
 column241                     NUMBER(8),
 column242                     NUMBER(8),
 column243                     NUMBER(8),
 column244                     NUMBER(8),
 column245                     NUMBER(8),
 column246                     NUMBER(8),
 column247                     NUMBER(8),
 column248                     NUMBER(8),
 column249                     NUMBER(8),
 column250                     NUMBER(8),
 column251                     NUMBER(8),
 column252                     NUMBER(8),
 column253                     NUMBER(8),
 column254                     NUMBER(8),
 column255                     NUMBER(8),
 column256                     NUMBER(8),
 column257                     NUMBER(8),
 column258                     NUMBER(8),
 column259                     NUMBER(8),
 column260                     NUMBER(8),
 column261                     NUMBER(8),
 column262                     NUMBER(8),
 column263                     NUMBER(8),
 column264                     NUMBER(8),
 column265                     NUMBER(8),
 column266                     NUMBER(8),
 column267                     NUMBER(8),
 column268                     NUMBER(8),
 column269                     NUMBER(8),
 column270                     NUMBER(8),
 column271                     NUMBER(8),
 column272                     NUMBER(8),
 column273                     NUMBER(8),
 column274                     NUMBER(8),
 column275                     NUMBER(8),
 column276                     NUMBER(8),
 column277                     NUMBER(8),
 column278                     NUMBER(8),
 column279                     NUMBER(8),
 column280                     NUMBER(8),
 column281                     NUMBER(8),
 column282                     NUMBER(8),
 column283                     NUMBER(8),
 column284                     NUMBER(8),
 column285                     NUMBER(8),
 column286                     NUMBER(8),
 column287                     NUMBER(8),
 column288                     NUMBER(8),
 column289                     NUMBER(8),
 column290                     NUMBER(8),
 column291                     NUMBER(8),
 column292                     NUMBER(8),
 column293                     NUMBER(8),
 column294                     NUMBER(8),
 column295                     NUMBER(8),
 column296                     NUMBER(8),
 column297                     NUMBER(8),
 column298                     NUMBER(8),
 column299                     NUMBER(8),
 column300                     NUMBER(8),
 column301                     NUMBER(8),
 column302                     NUMBER(8),
 column303                     NUMBER(8),
 column304                     NUMBER(8),
 column305                     NUMBER(8),
 column306                     NUMBER(8),
 column307                     NUMBER(8),
 column308                     NUMBER(8),
 column309                     NUMBER(8),
 column310                     NUMBER(8),
 column311                     NUMBER(8),
 column312                     NUMBER(8),
 column313                     NUMBER(8),
 column314                     NUMBER(8),
 column315                     NUMBER(8),
 column316                     NUMBER(8),
 column317                     NUMBER(8),
 column318                     NUMBER(8),
 column319                     NUMBER(8),
 column320                     NUMBER(8),
 column321                     NUMBER(8),
 column322                     NUMBER(8),
 column323                     NUMBER(8),
 column324                     NUMBER(8),
 column325                     NUMBER(8),
 column326                     NUMBER(8),
 column327                     NUMBER(8),
 column328                     NUMBER(8),
 column329                     NUMBER(8),
 column330                     NUMBER(8),
 column331                     NUMBER(8),
 column332                     NUMBER(8),
 column333                     NUMBER(8),
 column334                     NUMBER(8),
 column335                     NUMBER(8),
 column336                     NUMBER(8),
 column337                     NUMBER(8),
 column338                     NUMBER(8),
 column339                     NUMBER(8),
 column340                     NUMBER(8),
 column341                     NUMBER(8),
 column342                     NUMBER(8),
 column343                     NUMBER(8),
 column344                     NUMBER(8),
 column345                     NUMBER(8),
 column346                     NUMBER(8),
 column347                     NUMBER(8),
 column348                     NUMBER(8),
 column349                     NUMBER(8),
 column350                     NUMBER(8),
 column351                     NUMBER(8),
 column352                     NUMBER(8),
 column353                     NUMBER(8),
 column354                     NUMBER(8),
 column355                     NUMBER(8),
 column356                     NUMBER(8),
 column357                     NUMBER(8),
 column358                     NUMBER(8),
 column359                     NUMBER(8),
 column360                     NUMBER(8),
 column361                     NUMBER(8),
 column362                     NUMBER(8),
 column363                     NUMBER(8),
 column364                     NUMBER(8),
 column365                     NUMBER(8),
 column366                     NUMBER(8),
 column367                     NUMBER(8),
 column368                     NUMBER(8),
 column369                     NUMBER(8),
 column370                     NUMBER(8),
 column371                     NUMBER(8),
 column372                     NUMBER(8),
 column373                     NUMBER(8),
 column374                     NUMBER(8),
 column375                     NUMBER(8),
 column376                     NUMBER(8),
 column377                     NUMBER(8),
 column378                     NUMBER(8),
 column379                     NUMBER(8),
 column380                     NUMBER(8),
 column381                     NUMBER(8),
 column382                     NUMBER(8),
 column383                     NUMBER(8),
 column384                     NUMBER(8),
 column385                     NUMBER(8),
 column386                     NUMBER(8),
 column387                     NUMBER(8),
 column388                     NUMBER(8),
 column389                     NUMBER(8),
 column390                     NUMBER(8),
 column391                     NUMBER(8),
 column392                     NUMBER(8),
 column393                     NUMBER(8),
 column394                     NUMBER(8),
 column395                     NUMBER(8),
 column396                     NUMBER(8),
 column397                     NUMBER(8),
 column398                     NUMBER(8),
 column399                     NUMBER(8),
 column400                     NUMBER(8),
 column401                     NUMBER(8),
 column402                     NUMBER(8),
 column403                     NUMBER(8),
 column404                     NUMBER(8),
 column405                     NUMBER(8),
 column406                     NUMBER(8),
 column407                     NUMBER(8),
 column408                     NUMBER(8),
 column409                     NUMBER(8),
 column410                     NUMBER(8),
 column411                     NUMBER(8),
 column412                     NUMBER(8),
 column413                     NUMBER(8),
 column414                     NUMBER(8),
 column415                     NUMBER(8),
 column416                     NUMBER(8),
 column417                     NUMBER(8),
 column418                     NUMBER(8),
 column419                     NUMBER(8),
 column420                     NUMBER(8),
 column421                     NUMBER(8),
 column422                     NUMBER(8),
 column423                     NUMBER(8),
 column424                     NUMBER(8),
 column425                     NUMBER(8),
 column426                     NUMBER(8),
 column427                     NUMBER(8),
 column428                     NUMBER(8),
 column429                     NUMBER(8),
 column430                     NUMBER(8),
 column431                     NUMBER(8),
 column432                     NUMBER(8),
 column433                     NUMBER(8),
 column434                     NUMBER(8),
 column435                     NUMBER(8),
 column436                     NUMBER(8),
 column437                     NUMBER(8),
 column438                     NUMBER(8),
 column439                     NUMBER(8),
 column440                     NUMBER(8),
 column441                     NUMBER(8),
 column442                     NUMBER(8),
 column443                     NUMBER(8),
 column444                     NUMBER(8),
 column445                     NUMBER(8),
 column446                     NUMBER(8),
 column447                     NUMBER(8),
 column448                     NUMBER(8),
 column449                     NUMBER(8),
 column450                     NUMBER(8),
 column451                     NUMBER(8),
 column452                     NUMBER(8),
 column453                     NUMBER(8),
 column454                     NUMBER(8),
 column455                     NUMBER(8),
 column456                     NUMBER(8),
 column457                     NUMBER(8),
 column458                     NUMBER(8),
 column459                     NUMBER(8),
 column460                     NUMBER(8),
 column461                     NUMBER(8),
 column462                     NUMBER(8),
 column463                     NUMBER(8),
 column464                     NUMBER(8),
 column465                     NUMBER(8),
 column466                     NUMBER(8),
 column467                     NUMBER(8),
 column468                     NUMBER(8),
 column469                     NUMBER(8),
 column470                     NUMBER(8),
 column471                     NUMBER(8),
 column472                     NUMBER(8),
 column473                     NUMBER(8),
 column474                     NUMBER(8),
 column475                     NUMBER(8),
 column476                     NUMBER(8),
 column477                     NUMBER(8),
 column478                     NUMBER(8),
 column479                     NUMBER(8),
 column480                     NUMBER(8),
 column481                     NUMBER(8),
 column482                     NUMBER(8),
 column483                     NUMBER(8),
 column484                     NUMBER(8),
 column485                     NUMBER(8),
 column486                     NUMBER(8),
 column487                     NUMBER(8),
 column488                     NUMBER(8),
 column489                     NUMBER(8),
 column490                     NUMBER(8),
 column491                     NUMBER(8),
 column492                     NUMBER(8),
 column493                     NUMBER(8),
 column494                     NUMBER(8),
 column495                     NUMBER(8),
 column496                     NUMBER(8),
 column497                     NUMBER(8),
 column498                     NUMBER(8),
 column499                     NUMBER(8),
 column500                     NUMBER(8),
 modification_date             DATE NOT NULL,
 user_read                     NUMBER(1) NOT NULL,
 user_write                    NUMBER(1) NOT NULL,
 group_read                    NUMBER(1) NOT NULL,
 group_write                   NUMBER(1) NOT NULL,
 other_read                    NUMBER(1) NOT NULL,
 other_write                   NUMBER(1) NOT NULL,
 row_user_id                   NUMBER(12) NOT NULL,
 row_group_id                  NUMBER(3) NOT NULL,
 row_project_id                NUMBER(4) NOT NULL,
 row_alg_invocation_id         NUMBER(12) NOT NULL
);

ALTER TABLE apidb.GroupTaxonMatrix
ADD CONSTRAINT gtm_pk PRIMARY KEY (group_taxon_matrix_id);

ALTER TABLE apidb.GroupTaxonMatrix
ADD CONSTRAINT gtm_fk1 FOREIGN KEY (ortholog_group_id)
REFERENCES apidb.OrthologGroup (ortholog_group_id);

CREATE UNIQUE INDEX apidb.gtm_group_id 
    ON apidb.GroupTaxonMatrix (ortholog_group_id);

GRANT INSERT, SELECT, UPDATE, DELETE ON apidb.GroupTaxonMatrix TO gus_w;
GRANT SELECT ON apidb.GroupTaxonMatrix TO gus_r;

------------------------------------------------------------------------------

CREATE SEQUENCE apidb.GroupTaxonMatrix_sq;

GRANT SELECT ON apidb.GroupTaxonMatrix_sq TO gus_r;
GRANT SELECT ON apidb.GroupTaxonMatrix_sq TO gus_w;

------------------------------------------------------------------------------

INSERT INTO core.TableInfo
    (table_id, name, table_type, primary_key_column, database_id, is_versioned,
     is_view, view_on_table_id, superclass_table_id, is_updatable, 
     modification_date, user_read, user_write, group_read, group_write, 
     other_read, other_write, row_user_id, row_group_id, row_project_id, 
     row_alg_invocation_id)
SELECT core.tableinfo_sq.nextval, 'GroupTaxonMatrix',
       'Standard', 'GROUP_TAXON_MATRIX_ID',
       d.database_id, 0, 0, '', '', 1,sysdate, 1, 1, 1, 1, 1, 1, 1, 1,
       p.project_id, 0
FROM dual,
     (SELECT MAX(project_id) AS project_id FROM core.ProjectInfo) p,
     (SELECT database_id FROM core.DatabaseInfo WHERE lower(name) = 'apidb') d
WHERE 'grouptaxonmatrix' NOT IN (SELECT lower(name) FROM core.TableInfo
                                    where database_id = d.database_id);
                                    
------------------------------------------------------------------------------

CREATE TABLE apidb.OrthologGroupAaSequence (
 ortholog_group_aa_sequence_id NUMBER(12) NOT NULL,
 ortholog_group_id             NUMBER(12) NOT NULL,
 aa_sequence_id                NUMBER(12) NOT NULL,
 connectivity                  FLOAT(126),
 modification_date             DATE NOT NULL,
 user_read                     NUMBER(1) NOT NULL,
 user_write                    NUMBER(1) NOT NULL,
 group_read                    NUMBER(1) NOT NULL,
 group_write                   NUMBER(1) NOT NULL,
 other_read                    NUMBER(1) NOT NULL,
 other_write                   NUMBER(1) NOT NULL,
 row_user_id                   NUMBER(12) NOT NULL,
 row_group_id                  NUMBER(3) NOT NULL,
 row_project_id                NUMBER(4) NOT NULL,
 row_alg_invocation_id         NUMBER(12) NOT NULL
);

ALTER TABLE apidb.OrthologGroupAaSequence
ADD CONSTRAINT ogas_pk PRIMARY KEY (ortholog_group_aa_sequence_id);

ALTER TABLE apidb.OrthologGroupAaSequence
ADD CONSTRAINT ogas_fk1 FOREIGN KEY (ortholog_group_id)
REFERENCES apidb.OrthologGroup;

ALTER TABLE apidb.OrthologGroupAaSequence
ADD CONSTRAINT ogas_fk2 FOREIGN KEY (aa_sequence_id)
REFERENCES dots.AaSequenceImp;

GRANT INSERT, SELECT, UPDATE, DELETE ON apidb.OrthologGroupAaSequence TO gus_w;
GRANT SELECT ON apidb.OrthologGroupAaSequence TO gus_r;

CREATE INDEX apidb.ogas_ogas_ix
ON apidb.OrthologGroupAaSequence (ortholog_group_id, aa_sequence_id);

CREATE INDEX apidb.ogas_asog_ix
ON apidb.OrthologGroupAaSequence (aa_sequence_id, ortholog_group_id);
------------------------------------------------------------------------------

CREATE SEQUENCE apidb.OrthologGroupAaSequence_sq;

GRANT SELECT ON apidb.OrthologGroupAaSequence_sq TO gus_r;
GRANT SELECT ON apidb.OrthologGroupAaSequence_sq TO gus_w;

------------------------------------------------------------------------------

INSERT INTO core.TableInfo
    (table_id, name, table_type, primary_key_column, database_id, is_versioned,
     is_view, view_on_table_id, superclass_table_id, is_updatable, 
     modification_date, user_read, user_write, group_read, group_write, 
     other_read, other_write, row_user_id, row_group_id, row_project_id, 
     row_alg_invocation_id)
SELECT core.tableinfo_sq.nextval, 'OrthologGroupAaSequence',
       'Standard', 'ORTHOLOG_GROUP_AA_SEQUENCE_ID',
       d.database_id, 0, 0, '', '', 1,sysdate, 1, 1, 1, 1, 1, 1, 1, 1,
       p.project_id, 0
FROM dual,
     (SELECT MAX(project_id) AS project_id FROM core.ProjectInfo) p,
     (SELECT database_id FROM core.DatabaseInfo WHERE lower(name) = 'apidb') d
WHERE 'orthologgroupaasequence' NOT IN (SELECT lower(name) FROM core.TableInfo
                                    where database_id = d.database_id);

------------------------------------------------------------------------------

CREATE TABLE ApiDB.OrthomclResource (
 orthomcl_resource_id          NUMBER(10) NOT NULL,
 orthomcl_taxon_id             NUMBER(10) NOT NULL,
 resource_name                 VARCHAR(50) NOT NULL,
 resource_url                  VARCHAR(255) NOT NULL,
 resource_version              VARCHAR(100),
 strain                        VARCHAR(100),
 description                   VARCHAR(255),
 linkout_url                   VARCHAR(255),
 modification_date             DATE NOT NULL,
 user_read                     NUMBER(1) NOT NULL,
 user_write                    NUMBER(1) NOT NULL,
 group_read                    NUMBER(1) NOT NULL,
 group_write                   NUMBER(1) NOT NULL,
 other_read                    NUMBER(1) NOT NULL,
 other_write                   NUMBER(1) NOT NULL,
 row_user_id                   NUMBER(12) NOT NULL,
 row_group_id                  NUMBER(3) NOT NULL,
 row_project_id                NUMBER(4) NOT NULL,
 row_alg_invocation_id         NUMBER(12) NOT NULL,
 FOREIGN KEY (orthomcl_taxon_id) REFERENCES ApiDB.OrthomclTaxon (orthomcl_taxon_id),
 PRIMARY KEY (orthomcl_resource_id)
);

CREATE INDEX ApiDB.OrthomclResource_revix
ON ApiDB.OrthomclResource (orthomcl_taxon_id, orthomcl_resource_id);

GRANT insert, select, update, delete ON ApiDB.OrthomclResource TO gus_w;
GRANT select ON ApiDB.OrthomclResource TO gus_r;

------------------------------------------------------------------------------

CREATE SEQUENCE ApiDB.OrthomclResource_sq;

GRANT SELECT ON ApiDB.OrthomclResource_sq TO gus_r;
GRANT SELECT ON ApiDB.OrthomclResource_sq TO gus_w;

------------------------------------------------------------------------------

INSERT INTO core.TableInfo
    (table_id, name, table_type, primary_key_column, database_id, is_versioned,
     is_view, view_on_table_id, superclass_table_id, is_updatable,
     modification_date, user_read, user_write, group_read, group_write,
     other_read, other_write, row_user_id, row_group_id, row_project_id,
     row_alg_invocation_id)
SELECT core.tableinfo_sq.nextval, 'OrthomclResource',
       'Standard', 'orthomcl_resource_id',
       d.database_id, 0, 0, '', '', 1, sysdate, 1, 1, 1, 1, 1, 1, 1, 1,
       p.project_id, 0
FROM dual,
     (SELECT MAX(project_id) AS project_id FROM core.ProjectInfo) p,
     (SELECT database_id FROM core.DatabaseInfo WHERE name = 'ApiDB') d
WHERE 'OrthomclResource' NOT IN (SELECT name FROM core.TableInfo
                                 WHERE database_id = d.database_id);

---------------------------------------------------------------------------

CREATE TABLE ApiDB.OrthomclGroupKeyword (
 orthomcl_keyword_id           NUMBER(10) NOT NULL,
 ortholog_group_id             NUMBER(10) NOT NULL,
 keyword                       VARCHAR(255) NOT NULL,
 frequency                     VARCHAR(255) NOT NULL,
 modification_date             DATE NOT NULL,
 user_read                     NUMBER(1) NOT NULL,
 user_write                    NUMBER(1) NOT NULL,
 group_read                    NUMBER(1) NOT NULL,
 group_write                   NUMBER(1) NOT NULL,
 other_read                    NUMBER(1) NOT NULL,
 other_write                   NUMBER(1) NOT NULL,
 row_user_id                   NUMBER(12) NOT NULL,
 row_group_id                  NUMBER(3) NOT NULL,
 row_project_id                NUMBER(4) NOT NULL,
 row_alg_invocation_id         NUMBER(12) NOT NULL,
 FOREIGN KEY (ortholog_group_id) REFERENCES ApiDB.OrthologGroup (ortholog_group_id),
 PRIMARY KEY (orthomcl_keyword_id)
);

GRANT insert, select, update, delete ON ApiDB.OrthomclGroupKeyword TO gus_w;
GRANT select ON ApiDB.OrthomclGroupKeyword TO gus_r;

CREATE INDEX apidb.ogk_group_ix ON apidb.OrthomclGroupKeyword(ortholog_group_id);

------------------------------------------------------------------------------

CREATE SEQUENCE ApiDB.OrthomclGroupKeyword_sq;

GRANT SELECT ON ApiDB.OrthomclGroupKeyword_sq TO gus_r;
GRANT SELECT ON ApiDB.OrthomclGroupKeyword_sq TO gus_w;

------------------------------------------------------------------------------

INSERT INTO core.TableInfo
    (table_id, name, table_type, primary_key_column, database_id, is_versioned,
     is_view, view_on_table_id, superclass_table_id, is_updatable,
     modification_date, user_read, user_write, group_read, group_write,
     other_read, other_write, row_user_id, row_group_id, row_project_id,
     row_alg_invocation_id)
SELECT core.tableinfo_sq.nextval, 'OrthomclGroupKeyword',
       'Standard', 'orthomcl_keyword_id',
       d.database_id, 0, 0, '', '', 1, sysdate, 1, 1, 1, 1, 1, 1, 1, 1,
       p.project_id, 0
FROM dual,
     (SELECT MAX(project_id) AS project_id FROM core.ProjectInfo) p,
     (SELECT database_id FROM core.DatabaseInfo WHERE name = 'ApiDB') d
WHERE 'OrthomclGroupKeyword' NOT IN (SELECT name FROM core.TableInfo
                                 WHERE database_id = d.database_id);

---------------------------------------------------------------------------

CREATE TABLE ApiDB.OrthomclGroupDomain (
 orthomcl_domain_id           NUMBER(10) NOT NULL,
 ortholog_group_id             NUMBER(10) NOT NULL,
 description                   VARCHAR(255) NOT NULL,
 frequency                     FLOAT NOT NULL,
 modification_date             DATE NOT NULL,
 user_read                     NUMBER(1) NOT NULL,
 user_write                    NUMBER(1) NOT NULL,
 group_read                    NUMBER(1) NOT NULL,
 group_write                   NUMBER(1) NOT NULL,
 other_read                    NUMBER(1) NOT NULL,
 other_write                   NUMBER(1) NOT NULL,
 row_user_id                   NUMBER(12) NOT NULL,
 row_group_id                  NUMBER(3) NOT NULL,
 row_project_id                NUMBER(4) NOT NULL,
 row_alg_invocation_id         NUMBER(12) NOT NULL,
 FOREIGN KEY (ortholog_group_id) REFERENCES ApiDB.OrthologGroup (ortholog_group_id),
 PRIMARY KEY (orthomcl_domain_id)
);

GRANT insert, select, update, delete ON ApiDB.OrthomclGroupDomain TO gus_w;
GRANT select ON ApiDB.OrthomclGroupDomain TO gus_r;

CREATE INDEX apidb.ogd_group_ix ON apidb.OrthomclGroupDomain(ortholog_group_id);

------------------------------------------------------------------------------

CREATE SEQUENCE ApiDB.OrthomclGroupDomain_sq;

GRANT SELECT ON ApiDB.OrthomclGroupDomain_sq TO gus_r;
GRANT SELECT ON ApiDB.OrthomclGroupDomain_sq TO gus_w;

------------------------------------------------------------------------------

INSERT INTO core.TableInfo
    (table_id, name, table_type, primary_key_column, database_id, is_versioned,
     is_view, view_on_table_id, superclass_table_id, is_updatable,
     modification_date, user_read, user_write, group_read, group_write,
     other_read, other_write, row_user_id, row_group_id, row_project_id,
     row_alg_invocation_id)
SELECT core.tableinfo_sq.nextval, 'OrthomclGroupDomain',
       'Standard', 'orthomcl_domain_id',
       d.database_id, 0, 0, '', '', 1, sysdate, 1, 1, 1, 1, 1, 1, 1, 1,
       p.project_id, 0
FROM dual,
     (SELECT MAX(project_id) AS project_id FROM core.ProjectInfo) p,
     (SELECT database_id FROM core.DatabaseInfo WHERE name = 'ApiDB') d
WHERE 'OrthomclGroupDomain' NOT IN (SELECT name FROM core.TableInfo
                                 WHERE database_id = d.database_id);

exit;
