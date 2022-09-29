 CREATE TABLE apidb.OrthologGroup (
 ortholog_group_id            NUMERIC(12) NOT NULL,
 subclass_view                VARCHAR(30) NOT NULL,
 name                         VARCHAR(500),
 core_peripheral_residual     VARCHAR(1) NOT NULL,
 description                  VARCHAR(2000),
 number_of_members            NUMERIC(12) NOT NULL,
 avg_percent_identity         FLOAT,
 avg_percent_match            FLOAT,
 avg_evalue_mant              FLOAT,
 avg_evalue_exp               NUMERIC,
 avg_connectivity             FLOAT8,
 number_of_match_pairs        NUMERIC,
 percent_match_pairs          NUMERIC,
 aa_seq_group_experiment_id   NUMERIC(12),
 external_database_release_id NUMERIC(10) NOT NULL,
 multiple_sequence_alignment  TEXT,
 biolayout_image              BYTEA,
 svg_content                  TEXT,
 modification_date            DATE NOT NULL,
 user_read                    NUMERIC(1) NOT NULL,
 user_write                   NUMERIC(1) NOT NULL,
 group_read                   NUMERIC(1) NOT NULL,
 group_write                  NUMERIC(1) NOT NULL,
 other_read                   NUMERIC(1) NOT NULL,
 other_write                  NUMERIC(1) NOT NULL,
 row_user_id                  NUMERIC(12) NOT NULL,
 row_group_id                 NUMERIC(3) NOT NULL,
 row_project_id               NUMERIC(4) NOT NULL,
 row_alg_invocation_id        NUMERIC(12) NOT NULL
);

ALTER TABLE apidb.OrthologGroup
ADD CONSTRAINT og_pk PRIMARY KEY (ortholog_group_id);

ALTER TABLE apidb.OrthologGroup
ADD CONSTRAINT og_fk1 FOREIGN KEY (external_database_release_id)
REFERENCES sres.ExternalDatabaseRelease;

ALTER TABLE apidb.OrthologGroup
ADD CONSTRAINT og_fk2 FOREIGN KEY (aa_seq_group_experiment_id)
REFERENCES dots.AaSeqGroupExperimentImp (aa_seq_group_experiment_id);

CREATE INDEX OrthologGroup_revix
ON apidb.OrthologGroup (external_database_release_id, ortholog_group_id) tablespace indx;

GRANT INSERT, SELECT, UPDATE, DELETE ON apidb.OrthologGroup TO gus_w;
GRANT SELECT ON apidb.OrthologGroup TO gus_r;

CREATE INDEX og_name_ix ON apidb.OrthologGroup (name, ortholog_group_id) tablespace indx;
CREATE INDEX og_mem_ix ON apidb.OrthologGroup (number_of_members, ortholog_group_id, name) tablespace indx;
CREATE INDEX og_core_ix ON apidb.OrthologGroup (core_peripheral_residual, ortholog_group_id, name) tablespace indx;

CREATE INDEX og_match_ix ON apidb.OrthologGroup (avg_percent_match, ortholog_group_id, name) tablespace indx;
CREATE INDEX og_pct_ix ON apidb.OrthologGroup (percent_match_pairs, ortholog_group_id, name) tablespace indx;
CREATE INDEX og_id_ix ON apidb.OrthologGroup (avg_percent_identity, ortholog_group_id, name) tablespace indx;

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
SELECT NEXTVAL('core.tableinfo_sq'), 'OrthologGroup',
       'Standard', 'ORTHOLOG_GROUP_ID',
       d.database_id, 0, 0, NULL, NULL, 1, localtimestamp, 1, 1, 1, 1, 1, 1, 1, 1,
       p.project_id, 0
FROM 
     (SELECT MAX(project_id) AS project_id FROM core.ProjectInfo) p,
     (SELECT database_id FROM core.DatabaseInfo WHERE lower(name) = 'apidb') d
WHERE 'orthologgroup' NOT IN (SELECT lower(name) FROM core.TableInfo
                                    where database_id = d.database_id);

------------------------------------------------------------------------------
------------------------------------------------------------------------------
CREATE TABLE apidb.OrthomclTaxon (
 orthomcl_taxon_id             NUMERIC(12) NOT NULL,
 parent_id                     NUMERIC(12),
 taxon_id                      NUMERIC(12),
 name                          VARCHAR(255),
 three_letter_abbrev           VARCHAR(8) NOT NULL,
 core_peripheral	           VARCHAR(1) NOT NULL,
 is_species                    NUMERIC(1) NOT NULL,
 species_order                 NUMERIC(4),
 depth_first_index             NUMERIC(10) NOT NULL,
 sibling_depth_first_index     NUMERIC(10),
 common_name                   VARCHAR(255),
 modification_date             DATE NOT NULL,
 user_read                     NUMERIC(1) NOT NULL,
 user_write                    NUMERIC(1) NOT NULL,
 group_read                    NUMERIC(1) NOT NULL,
 group_write                   NUMERIC(1) NOT NULL,
 other_read                    NUMERIC(1) NOT NULL,
 other_write                   NUMERIC(1) NOT NULL,
 row_user_id                   NUMERIC(12) NOT NULL,
 row_group_id                  NUMERIC(3) NOT NULL,
 row_project_id                NUMERIC(4) NOT NULL,
 row_alg_invocation_id         NUMERIC(12) NOT NULL
);

ALTER TABLE apidb.OrthomclTaxon
ADD CONSTRAINT ot_pk PRIMARY KEY (orthomcl_taxon_id);

ALTER TABLE apidb.OrthomclTaxon
ADD CONSTRAINT ot_fk1 FOREIGN KEY (parent_id)
REFERENCES apidb.OrthomclTaxon (orthomcl_taxon_id);

CREATE INDEX OrthomclTaxon_revix
ON apidb.OrthomclTaxon (parent_id, orthomcl_taxon_id) tablespace indx;

ALTER TABLE apidb.OrthomclTaxon
ADD CONSTRAINT ot_fk2 FOREIGN KEY (taxon_id)
REFERENCES sres.Taxon (taxon_id);

CREATE INDEX OrthomclTaxon_revix2
ON apidb.OrthomclTaxon (taxon_id, orthomcl_taxon_id) tablespace indx;

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
SELECT NEXTVAL('core.tableinfo_sq'), 'OrthomclTaxon',
       'Standard', 'ORTHOMCL_TAXON_ID',
       d.database_id, 0, 0, NULL, NULL, 1, localtimestamp, 1, 1, 1, 1, 1, 1, 1, 1,
       p.project_id, 0
FROM 
     (SELECT MAX(project_id) AS project_id FROM core.ProjectInfo) p,
     (SELECT database_id FROM core.DatabaseInfo WHERE lower(name) = 'apidb') d
WHERE 'orthomcltaxon' NOT IN (SELECT lower(name) FROM core.TableInfo
                                    where database_id = d.database_id);

------------------------------------------------------------------------------
------------------------------------------------------------------------------
CREATE TABLE apidb.GroupTaxonMatrix (
 group_taxon_matrix_id       NUMERIC(12) NOT NULL,
 ortholog_group_id       NUMERIC(12) NOT NULL,
 column1                     NUMERIC(8),
 column2                     NUMERIC(8),
 column3                     NUMERIC(8),
 column4                     NUMERIC(8),
 column5                     NUMERIC(8),
 column6                     NUMERIC(8),
 column7                     NUMERIC(8),
 column8                     NUMERIC(8),
 column9                     NUMERIC(8),
 column10                     NUMERIC(8),
 column11                     NUMERIC(8),
 column12                     NUMERIC(8),
 column13                     NUMERIC(8),
 column14                     NUMERIC(8),
 column15                     NUMERIC(8),
 column16                     NUMERIC(8),
 column17                     NUMERIC(8),
 column18                     NUMERIC(8),
 column19                     NUMERIC(8),
 column20                     NUMERIC(8),
 column21                     NUMERIC(8),
 column22                     NUMERIC(8),
 column23                     NUMERIC(8),
 column24                     NUMERIC(8),
 column25                     NUMERIC(8),
 column26                     NUMERIC(8),
 column27                     NUMERIC(8),
 column28                     NUMERIC(8),
 column29                     NUMERIC(8),
 column30                     NUMERIC(8),
 column31                     NUMERIC(8),
 column32                     NUMERIC(8),
 column33                     NUMERIC(8),
 column34                     NUMERIC(8),
 column35                     NUMERIC(8),
 column36                     NUMERIC(8),
 column37                     NUMERIC(8),
 column38                     NUMERIC(8),
 column39                     NUMERIC(8),
 column40                     NUMERIC(8),
 column41                     NUMERIC(8),
 column42                     NUMERIC(8),
 column43                     NUMERIC(8),
 column44                     NUMERIC(8),
 column45                     NUMERIC(8),
 column46                     NUMERIC(8),
 column47                     NUMERIC(8),
 column48                     NUMERIC(8),
 column49                     NUMERIC(8),
 column50                     NUMERIC(8),
 column51                     NUMERIC(8),
 column52                     NUMERIC(8),
 column53                     NUMERIC(8),
 column54                     NUMERIC(8),
 column55                     NUMERIC(8),
 column56                     NUMERIC(8),
 column57                     NUMERIC(8),
 column58                     NUMERIC(8),
 column59                     NUMERIC(8),
 column60                     NUMERIC(8),
 column61                     NUMERIC(8),
 column62                     NUMERIC(8),
 column63                     NUMERIC(8),
 column64                     NUMERIC(8),
 column65                     NUMERIC(8),
 column66                     NUMERIC(8),
 column67                     NUMERIC(8),
 column68                     NUMERIC(8),
 column69                     NUMERIC(8),
 column70                     NUMERIC(8),
 column71                     NUMERIC(8),
 column72                     NUMERIC(8),
 column73                     NUMERIC(8),
 column74                     NUMERIC(8),
 column75                     NUMERIC(8),
 column76                     NUMERIC(8),
 column77                     NUMERIC(8),
 column78                     NUMERIC(8),
 column79                     NUMERIC(8),
 column80                     NUMERIC(8),
 column81                     NUMERIC(8),
 column82                     NUMERIC(8),
 column83                     NUMERIC(8),
 column84                     NUMERIC(8),
 column85                     NUMERIC(8),
 column86                     NUMERIC(8),
 column87                     NUMERIC(8),
 column88                     NUMERIC(8),
 column89                     NUMERIC(8),
 column90                     NUMERIC(8),
 column91                     NUMERIC(8),
 column92                     NUMERIC(8),
 column93                     NUMERIC(8),
 column94                     NUMERIC(8),
 column95                     NUMERIC(8),
 column96                     NUMERIC(8),
 column97                     NUMERIC(8),
 column98                     NUMERIC(8),
 column99                     NUMERIC(8),
 column100                     NUMERIC(8),
 column101                     NUMERIC(8),
 column102                     NUMERIC(8),
 column103                     NUMERIC(8),
 column104                     NUMERIC(8),
 column105                     NUMERIC(8),
 column106                     NUMERIC(8),
 column107                     NUMERIC(8),
 column108                     NUMERIC(8),
 column109                     NUMERIC(8),
 column110                     NUMERIC(8),
 column111                     NUMERIC(8),
 column112                     NUMERIC(8),
 column113                     NUMERIC(8),
 column114                     NUMERIC(8),
 column115                     NUMERIC(8),
 column116                     NUMERIC(8),
 column117                     NUMERIC(8),
 column118                     NUMERIC(8),
 column119                     NUMERIC(8),
 column120                     NUMERIC(8),
 column121                     NUMERIC(8),
 column122                     NUMERIC(8),
 column123                     NUMERIC(8),
 column124                     NUMERIC(8),
 column125                     NUMERIC(8),
 column126                     NUMERIC(8),
 column127                     NUMERIC(8),
 column128                     NUMERIC(8),
 column129                     NUMERIC(8),
 column130                     NUMERIC(8),
 column131                     NUMERIC(8),
 column132                     NUMERIC(8),
 column133                     NUMERIC(8),
 column134                     NUMERIC(8),
 column135                     NUMERIC(8),
 column136                     NUMERIC(8),
 column137                     NUMERIC(8),
 column138                     NUMERIC(8),
 column139                     NUMERIC(8),
 column140                     NUMERIC(8),
 column141                     NUMERIC(8),
 column142                     NUMERIC(8),
 column143                     NUMERIC(8),
 column144                     NUMERIC(8),
 column145                     NUMERIC(8),
 column146                     NUMERIC(8),
 column147                     NUMERIC(8),
 column148                     NUMERIC(8),
 column149                     NUMERIC(8),
 column150                     NUMERIC(8),
 column151                     NUMERIC(8),
 column152                     NUMERIC(8),
 column153                     NUMERIC(8),
 column154                     NUMERIC(8),
 column155                     NUMERIC(8),
 column156                     NUMERIC(8),
 column157                     NUMERIC(8),
 column158                     NUMERIC(8),
 column159                     NUMERIC(8),
 column160                     NUMERIC(8),
 column161                     NUMERIC(8),
 column162                     NUMERIC(8),
 column163                     NUMERIC(8),
 column164                     NUMERIC(8),
 column165                     NUMERIC(8),
 column166                     NUMERIC(8),
 column167                     NUMERIC(8),
 column168                     NUMERIC(8),
 column169                     NUMERIC(8),
 column170                     NUMERIC(8),
 column171                     NUMERIC(8),
 column172                     NUMERIC(8),
 column173                     NUMERIC(8),
 column174                     NUMERIC(8),
 column175                     NUMERIC(8),
 column176                     NUMERIC(8),
 column177                     NUMERIC(8),
 column178                     NUMERIC(8),
 column179                     NUMERIC(8),
 column180                     NUMERIC(8),
 column181                     NUMERIC(8),
 column182                     NUMERIC(8),
 column183                     NUMERIC(8),
 column184                     NUMERIC(8),
 column185                     NUMERIC(8),
 column186                     NUMERIC(8),
 column187                     NUMERIC(8),
 column188                     NUMERIC(8),
 column189                     NUMERIC(8),
 column190                     NUMERIC(8),
 column191                     NUMERIC(8),
 column192                     NUMERIC(8),
 column193                     NUMERIC(8),
 column194                     NUMERIC(8),
 column195                     NUMERIC(8),
 column196                     NUMERIC(8),
 column197                     NUMERIC(8),
 column198                     NUMERIC(8),
 column199                     NUMERIC(8),
 column200                     NUMERIC(8),
 column201                     NUMERIC(8),
 column202                     NUMERIC(8),
 column203                     NUMERIC(8),
 column204                     NUMERIC(8),
 column205                     NUMERIC(8),
 column206                     NUMERIC(8),
 column207                     NUMERIC(8),
 column208                     NUMERIC(8),
 column209                     NUMERIC(8),
 column210                     NUMERIC(8),
 column211                     NUMERIC(8),
 column212                     NUMERIC(8),
 column213                     NUMERIC(8),
 column214                     NUMERIC(8),
 column215                     NUMERIC(8),
 column216                     NUMERIC(8),
 column217                     NUMERIC(8),
 column218                     NUMERIC(8),
 column219                     NUMERIC(8),
 column220                     NUMERIC(8),
 column221                     NUMERIC(8),
 column222                     NUMERIC(8),
 column223                     NUMERIC(8),
 column224                     NUMERIC(8),
 column225                     NUMERIC(8),
 column226                     NUMERIC(8),
 column227                     NUMERIC(8),
 column228                     NUMERIC(8),
 column229                     NUMERIC(8),
 column230                     NUMERIC(8),
 column231                     NUMERIC(8),
 column232                     NUMERIC(8),
 column233                     NUMERIC(8),
 column234                     NUMERIC(8),
 column235                     NUMERIC(8),
 column236                     NUMERIC(8),
 column237                     NUMERIC(8),
 column238                     NUMERIC(8),
 column239                     NUMERIC(8),
 column240                     NUMERIC(8),
 column241                     NUMERIC(8),
 column242                     NUMERIC(8),
 column243                     NUMERIC(8),
 column244                     NUMERIC(8),
 column245                     NUMERIC(8),
 column246                     NUMERIC(8),
 column247                     NUMERIC(8),
 column248                     NUMERIC(8),
 column249                     NUMERIC(8),
 column250                     NUMERIC(8),
 column251                     NUMERIC(8),
 column252                     NUMERIC(8),
 column253                     NUMERIC(8),
 column254                     NUMERIC(8),
 column255                     NUMERIC(8),
 column256                     NUMERIC(8),
 column257                     NUMERIC(8),
 column258                     NUMERIC(8),
 column259                     NUMERIC(8),
 column260                     NUMERIC(8),
 column261                     NUMERIC(8),
 column262                     NUMERIC(8),
 column263                     NUMERIC(8),
 column264                     NUMERIC(8),
 column265                     NUMERIC(8),
 column266                     NUMERIC(8),
 column267                     NUMERIC(8),
 column268                     NUMERIC(8),
 column269                     NUMERIC(8),
 column270                     NUMERIC(8),
 column271                     NUMERIC(8),
 column272                     NUMERIC(8),
 column273                     NUMERIC(8),
 column274                     NUMERIC(8),
 column275                     NUMERIC(8),
 column276                     NUMERIC(8),
 column277                     NUMERIC(8),
 column278                     NUMERIC(8),
 column279                     NUMERIC(8),
 column280                     NUMERIC(8),
 column281                     NUMERIC(8),
 column282                     NUMERIC(8),
 column283                     NUMERIC(8),
 column284                     NUMERIC(8),
 column285                     NUMERIC(8),
 column286                     NUMERIC(8),
 column287                     NUMERIC(8),
 column288                     NUMERIC(8),
 column289                     NUMERIC(8),
 column290                     NUMERIC(8),
 column291                     NUMERIC(8),
 column292                     NUMERIC(8),
 column293                     NUMERIC(8),
 column294                     NUMERIC(8),
 column295                     NUMERIC(8),
 column296                     NUMERIC(8),
 column297                     NUMERIC(8),
 column298                     NUMERIC(8),
 column299                     NUMERIC(8),
 column300                     NUMERIC(8),
 column301                     NUMERIC(8),
 column302                     NUMERIC(8),
 column303                     NUMERIC(8),
 column304                     NUMERIC(8),
 column305                     NUMERIC(8),
 column306                     NUMERIC(8),
 column307                     NUMERIC(8),
 column308                     NUMERIC(8),
 column309                     NUMERIC(8),
 column310                     NUMERIC(8),
 column311                     NUMERIC(8),
 column312                     NUMERIC(8),
 column313                     NUMERIC(8),
 column314                     NUMERIC(8),
 column315                     NUMERIC(8),
 column316                     NUMERIC(8),
 column317                     NUMERIC(8),
 column318                     NUMERIC(8),
 column319                     NUMERIC(8),
 column320                     NUMERIC(8),
 column321                     NUMERIC(8),
 column322                     NUMERIC(8),
 column323                     NUMERIC(8),
 column324                     NUMERIC(8),
 column325                     NUMERIC(8),
 column326                     NUMERIC(8),
 column327                     NUMERIC(8),
 column328                     NUMERIC(8),
 column329                     NUMERIC(8),
 column330                     NUMERIC(8),
 column331                     NUMERIC(8),
 column332                     NUMERIC(8),
 column333                     NUMERIC(8),
 column334                     NUMERIC(8),
 column335                     NUMERIC(8),
 column336                     NUMERIC(8),
 column337                     NUMERIC(8),
 column338                     NUMERIC(8),
 column339                     NUMERIC(8),
 column340                     NUMERIC(8),
 column341                     NUMERIC(8),
 column342                     NUMERIC(8),
 column343                     NUMERIC(8),
 column344                     NUMERIC(8),
 column345                     NUMERIC(8),
 column346                     NUMERIC(8),
 column347                     NUMERIC(8),
 column348                     NUMERIC(8),
 column349                     NUMERIC(8),
 column350                     NUMERIC(8),
 column351                     NUMERIC(8),
 column352                     NUMERIC(8),
 column353                     NUMERIC(8),
 column354                     NUMERIC(8),
 column355                     NUMERIC(8),
 column356                     NUMERIC(8),
 column357                     NUMERIC(8),
 column358                     NUMERIC(8),
 column359                     NUMERIC(8),
 column360                     NUMERIC(8),
 column361                     NUMERIC(8),
 column362                     NUMERIC(8),
 column363                     NUMERIC(8),
 column364                     NUMERIC(8),
 column365                     NUMERIC(8),
 column366                     NUMERIC(8),
 column367                     NUMERIC(8),
 column368                     NUMERIC(8),
 column369                     NUMERIC(8),
 column370                     NUMERIC(8),
 column371                     NUMERIC(8),
 column372                     NUMERIC(8),
 column373                     NUMERIC(8),
 column374                     NUMERIC(8),
 column375                     NUMERIC(8),
 column376                     NUMERIC(8),
 column377                     NUMERIC(8),
 column378                     NUMERIC(8),
 column379                     NUMERIC(8),
 column380                     NUMERIC(8),
 column381                     NUMERIC(8),
 column382                     NUMERIC(8),
 column383                     NUMERIC(8),
 column384                     NUMERIC(8),
 column385                     NUMERIC(8),
 column386                     NUMERIC(8),
 column387                     NUMERIC(8),
 column388                     NUMERIC(8),
 column389                     NUMERIC(8),
 column390                     NUMERIC(8),
 column391                     NUMERIC(8),
 column392                     NUMERIC(8),
 column393                     NUMERIC(8),
 column394                     NUMERIC(8),
 column395                     NUMERIC(8),
 column396                     NUMERIC(8),
 column397                     NUMERIC(8),
 column398                     NUMERIC(8),
 column399                     NUMERIC(8),
 column400                     NUMERIC(8),
 column401                     NUMERIC(8),
 column402                     NUMERIC(8),
 column403                     NUMERIC(8),
 column404                     NUMERIC(8),
 column405                     NUMERIC(8),
 column406                     NUMERIC(8),
 column407                     NUMERIC(8),
 column408                     NUMERIC(8),
 column409                     NUMERIC(8),
 column410                     NUMERIC(8),
 column411                     NUMERIC(8),
 column412                     NUMERIC(8),
 column413                     NUMERIC(8),
 column414                     NUMERIC(8),
 column415                     NUMERIC(8),
 column416                     NUMERIC(8),
 column417                     NUMERIC(8),
 column418                     NUMERIC(8),
 column419                     NUMERIC(8),
 column420                     NUMERIC(8),
 column421                     NUMERIC(8),
 column422                     NUMERIC(8),
 column423                     NUMERIC(8),
 column424                     NUMERIC(8),
 column425                     NUMERIC(8),
 column426                     NUMERIC(8),
 column427                     NUMERIC(8),
 column428                     NUMERIC(8),
 column429                     NUMERIC(8),
 column430                     NUMERIC(8),
 column431                     NUMERIC(8),
 column432                     NUMERIC(8),
 column433                     NUMERIC(8),
 column434                     NUMERIC(8),
 column435                     NUMERIC(8),
 column436                     NUMERIC(8),
 column437                     NUMERIC(8),
 column438                     NUMERIC(8),
 column439                     NUMERIC(8),
 column440                     NUMERIC(8),
 column441                     NUMERIC(8),
 column442                     NUMERIC(8),
 column443                     NUMERIC(8),
 column444                     NUMERIC(8),
 column445                     NUMERIC(8),
 column446                     NUMERIC(8),
 column447                     NUMERIC(8),
 column448                     NUMERIC(8),
 column449                     NUMERIC(8),
 column450                     NUMERIC(8),
 column451                     NUMERIC(8),
 column452                     NUMERIC(8),
 column453                     NUMERIC(8),
 column454                     NUMERIC(8),
 column455                     NUMERIC(8),
 column456                     NUMERIC(8),
 column457                     NUMERIC(8),
 column458                     NUMERIC(8),
 column459                     NUMERIC(8),
 column460                     NUMERIC(8),
 column461                     NUMERIC(8),
 column462                     NUMERIC(8),
 column463                     NUMERIC(8),
 column464                     NUMERIC(8),
 column465                     NUMERIC(8),
 column466                     NUMERIC(8),
 column467                     NUMERIC(8),
 column468                     NUMERIC(8),
 column469                     NUMERIC(8),
 column470                     NUMERIC(8),
 column471                     NUMERIC(8),
 column472                     NUMERIC(8),
 column473                     NUMERIC(8),
 column474                     NUMERIC(8),
 column475                     NUMERIC(8),
 column476                     NUMERIC(8),
 column477                     NUMERIC(8),
 column478                     NUMERIC(8),
 column479                     NUMERIC(8),
 column480                     NUMERIC(8),
 column481                     NUMERIC(8),
 column482                     NUMERIC(8),
 column483                     NUMERIC(8),
 column484                     NUMERIC(8),
 column485                     NUMERIC(8),
 column486                     NUMERIC(8),
 column487                     NUMERIC(8),
 column488                     NUMERIC(8),
 column489                     NUMERIC(8),
 column490                     NUMERIC(8),
 column491                     NUMERIC(8),
 column492                     NUMERIC(8),
 column493                     NUMERIC(8),
 column494                     NUMERIC(8),
 column495                     NUMERIC(8),
 column496                     NUMERIC(8),
 column497                     NUMERIC(8),
 column498                     NUMERIC(8),
 column499                     NUMERIC(8),
 column500                     NUMERIC(8),
 column501                     NUMERIC(8),
 column502                     NUMERIC(8),
 column503                     NUMERIC(8),
 column504                     NUMERIC(8),
 column505                     NUMERIC(8),
 column506                     NUMERIC(8),
 column507                     NUMERIC(8),
 column508                     NUMERIC(8),
 column509                     NUMERIC(8),
 column510                     NUMERIC(8),
 column511                     NUMERIC(8),
 column512                     NUMERIC(8),
 column513                     NUMERIC(8),
 column514                     NUMERIC(8),
 column515                     NUMERIC(8),
 column516                     NUMERIC(8),
 column517                     NUMERIC(8),
 column518                     NUMERIC(8),
 column519                     NUMERIC(8),
 column520                     NUMERIC(8),
 column521                     NUMERIC(8),
 column522                     NUMERIC(8),
 column523                     NUMERIC(8),
 column524                     NUMERIC(8),
 column525                     NUMERIC(8),
 column526                     NUMERIC(8),
 column527                     NUMERIC(8),
 column528                     NUMERIC(8),
 column529                     NUMERIC(8),
 column530                     NUMERIC(8),
 column531                     NUMERIC(8),
 column532                     NUMERIC(8),
 column533                     NUMERIC(8),
 column534                     NUMERIC(8),
 column535                     NUMERIC(8),
 column536                     NUMERIC(8),
 column537                     NUMERIC(8),
 column538                     NUMERIC(8),
 column539                     NUMERIC(8),
 column540                     NUMERIC(8),
 column541                     NUMERIC(8),
 column542                     NUMERIC(8),
 column543                     NUMERIC(8),
 column544                     NUMERIC(8),
 column545                     NUMERIC(8),
 column546                     NUMERIC(8),
 column547                     NUMERIC(8),
 column548                     NUMERIC(8),
 column549                     NUMERIC(8),
 column550                     NUMERIC(8),
 column551                     NUMERIC(8),
 column552                     NUMERIC(8),
 column553                     NUMERIC(8),
 column554                     NUMERIC(8),
 column555                     NUMERIC(8),
 column556                     NUMERIC(8),
 column557                     NUMERIC(8),
 column558                     NUMERIC(8),
 column559                     NUMERIC(8),
 column560                     NUMERIC(8),
 column561                     NUMERIC(8),
 column562                     NUMERIC(8),
 column563                     NUMERIC(8),
 column564                     NUMERIC(8),
 column565                     NUMERIC(8),
 column566                     NUMERIC(8),
 column567                     NUMERIC(8),
 column568                     NUMERIC(8),
 column569                     NUMERIC(8),
 column570                     NUMERIC(8),
 column571                     NUMERIC(8),
 column572                     NUMERIC(8),
 column573                     NUMERIC(8),
 column574                     NUMERIC(8),
 column575                     NUMERIC(8),
 column576                     NUMERIC(8),
 column577                     NUMERIC(8),
 column578                     NUMERIC(8),
 column579                     NUMERIC(8),
 column580                     NUMERIC(8),
 column581                     NUMERIC(8),
 column582                     NUMERIC(8),
 column583                     NUMERIC(8),
 column584                     NUMERIC(8),
 column585                     NUMERIC(8),
 column586                     NUMERIC(8),
 column587                     NUMERIC(8),
 column588                     NUMERIC(8),
 column589                     NUMERIC(8),
 column590                     NUMERIC(8),
 column591                     NUMERIC(8),
 column592                     NUMERIC(8),
 column593                     NUMERIC(8),
 column594                     NUMERIC(8),
 column595                     NUMERIC(8),
 column596                     NUMERIC(8),
 column597                     NUMERIC(8),
 column598                     NUMERIC(8),
 column599                     NUMERIC(8),
 column600                     NUMERIC(8),
 modification_date             DATE NOT NULL,
 user_read                     NUMERIC(1) NOT NULL,
 user_write                    NUMERIC(1) NOT NULL,
 group_read                    NUMERIC(1) NOT NULL,
 group_write                   NUMERIC(1) NOT NULL,
 other_read                    NUMERIC(1) NOT NULL,
 other_write                   NUMERIC(1) NOT NULL,
 row_user_id                   NUMERIC(12) NOT NULL,
 row_group_id                  NUMERIC(3) NOT NULL,
 row_project_id                NUMERIC(4) NOT NULL,
 row_alg_invocation_id         NUMERIC(12) NOT NULL
);

ALTER TABLE apidb.GroupTaxonMatrix
ADD CONSTRAINT gtm_pk PRIMARY KEY (group_taxon_matrix_id);

ALTER TABLE apidb.GroupTaxonMatrix
ADD CONSTRAINT gtm_fk1 FOREIGN KEY (ortholog_group_id)
REFERENCES apidb.OrthologGroup (ortholog_group_id);

CREATE UNIQUE INDEX apidb.gtm_group_id 
    ON apidb.GroupTaxonMatrix (ortholog_group_id) tablespace indx;

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
SELECT NEXTVAL('core.tableinfo_sq'), 'GroupTaxonMatrix',
       'Standard', 'GROUP_TAXON_MATRIX_ID',
       d.database_id, 0, 0, NULL, NULL, 1, localtimestamp, 1, 1, 1, 1, 1, 1, 1, 1,
       p.project_id, 0
FROM 
     (SELECT MAX(project_id) AS project_id FROM core.ProjectInfo) p,
     (SELECT database_id FROM core.DatabaseInfo WHERE lower(name) = 'apidb') d
WHERE 'grouptaxonmatrix' NOT IN (SELECT lower(name) FROM core.TableInfo
                                    where database_id = d.database_id);
                                    
------------------------------------------------------------------------------

CREATE TABLE apidb.OrthologGroupAaSequence (
 ortholog_group_aa_sequence_id NUMERIC(12) NOT NULL,
 ortholog_group_id             NUMERIC(12) NOT NULL,
 aa_sequence_id                NUMERIC(12) NOT NULL,
 connectivity                  FLOAT8,
 modification_date             DATE NOT NULL,
 user_read                     NUMERIC(1) NOT NULL,
 user_write                    NUMERIC(1) NOT NULL,
 group_read                    NUMERIC(1) NOT NULL,
 group_write                   NUMERIC(1) NOT NULL,
 other_read                    NUMERIC(1) NOT NULL,
 other_write                   NUMERIC(1) NOT NULL,
 row_user_id                   NUMERIC(12) NOT NULL,
 row_group_id                  NUMERIC(3) NOT NULL,
 row_project_id                NUMERIC(4) NOT NULL,
 row_alg_invocation_id         NUMERIC(12) NOT NULL
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

CREATE INDEX ogas_ogas_ix
ON apidb.OrthologGroupAaSequence (ortholog_group_id, aa_sequence_id) tablespace indx;

CREATE INDEX ogas_asog_ix
ON apidb.OrthologGroupAaSequence (aa_sequence_id, ortholog_group_id) tablespace indx;
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
SELECT NEXTVAL('core.tableinfo_sq'), 'OrthologGroupAaSequence',
       'Standard', 'ORTHOLOG_GROUP_AA_SEQUENCE_ID',
       d.database_id, 0, 0, NULL, NULL, 1, localtimestamp, 1, 1, 1, 1, 1, 1, 1, 1,
       p.project_id, 0
FROM 
     (SELECT MAX(project_id) AS project_id FROM core.ProjectInfo) p,
     (SELECT database_id FROM core.DatabaseInfo WHERE lower(name) = 'apidb') d
WHERE 'orthologgroupaasequence' NOT IN (SELECT lower(name) FROM core.TableInfo
                                    where database_id = d.database_id);

------------------------------------------------------------------------------

CREATE TABLE ApiDB.OrthomclResource (
 orthomcl_resource_id          NUMERIC(10) NOT NULL,
 orthomcl_taxon_id             NUMERIC(10) NOT NULL,
 resource_name                 VARCHAR(50) NOT NULL,
 resource_url                  VARCHAR(255) NOT NULL,
 resource_version              VARCHAR(100),
 strain                        VARCHAR(100),
 description                   VARCHAR(255),
 linkout_url                   VARCHAR(255),
 modification_date             DATE NOT NULL,
 user_read                     NUMERIC(1) NOT NULL,
 user_write                    NUMERIC(1) NOT NULL,
 group_read                    NUMERIC(1) NOT NULL,
 group_write                   NUMERIC(1) NOT NULL,
 other_read                    NUMERIC(1) NOT NULL,
 other_write                   NUMERIC(1) NOT NULL,
 row_user_id                   NUMERIC(12) NOT NULL,
 row_group_id                  NUMERIC(3) NOT NULL,
 row_project_id                NUMERIC(4) NOT NULL,
 row_alg_invocation_id         NUMERIC(12) NOT NULL,
 FOREIGN KEY (orthomcl_taxon_id) REFERENCES ApiDB.OrthomclTaxon (orthomcl_taxon_id),
 PRIMARY KEY (orthomcl_resource_id)
);

CREATE INDEX OrthomclResource_revix
ON ApiDB.OrthomclResource (orthomcl_taxon_id, orthomcl_resource_id) tablespace indx;

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
SELECT NEXTVAL('core.tableinfo_sq'), 'OrthomclResource',
       'Standard', 'orthomcl_resource_id',
       d.database_id, 0, 0, NULL, NULL, 1, localtimestamp, 1, 1, 1, 1, 1, 1, 1, 1,
       p.project_id, 0
FROM 
     (SELECT MAX(project_id) AS project_id FROM core.ProjectInfo) p,
     (SELECT database_id FROM core.DatabaseInfo WHERE name = 'ApiDB') d
WHERE 'OrthomclResource' NOT IN (SELECT name FROM core.TableInfo
                                 WHERE database_id = d.database_id);

---------------------------------------------------------------------------

CREATE TABLE ApiDB.OrthomclGroupKeyword (
 orthomcl_keyword_id           NUMERIC(10) NOT NULL,
 ortholog_group_id             NUMERIC(10) NOT NULL,
 keyword                       VARCHAR(255) NOT NULL,
 frequency                     VARCHAR(20) NOT NULL,
 modification_date             DATE NOT NULL,
 user_read                     NUMERIC(1) NOT NULL,
 user_write                    NUMERIC(1) NOT NULL,
 group_read                    NUMERIC(1) NOT NULL,
 group_write                   NUMERIC(1) NOT NULL,
 other_read                    NUMERIC(1) NOT NULL,
 other_write                   NUMERIC(1) NOT NULL,
 row_user_id                   NUMERIC(12) NOT NULL,
 row_group_id                  NUMERIC(3) NOT NULL,
 row_project_id                NUMERIC(4) NOT NULL,
 row_alg_invocation_id         NUMERIC(12) NOT NULL,
 FOREIGN KEY (ortholog_group_id) REFERENCES ApiDB.OrthologGroup (ortholog_group_id),
 PRIMARY KEY (orthomcl_keyword_id)
);

GRANT insert, select, update, delete ON ApiDB.OrthomclGroupKeyword TO gus_w;
GRANT select ON ApiDB.OrthomclGroupKeyword TO gus_r;

CREATE INDEX ogk_group_ix ON apidb.OrthomclGroupKeyword(ortholog_group_id, keyword, frequency) tablespace indx;

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
SELECT NEXTVAL('core.tableinfo_sq'), 'OrthomclGroupKeyword',
       'Standard', 'orthomcl_keyword_id',
       d.database_id, 0, 0, NULL, NULL, 1, localtimestamp, 1, 1, 1, 1, 1, 1, 1, 1,
       p.project_id, 0
FROM 
     (SELECT MAX(project_id) AS project_id FROM core.ProjectInfo) p,
     (SELECT database_id FROM core.DatabaseInfo WHERE name = 'ApiDB') d
WHERE 'OrthomclGroupKeyword' NOT IN (SELECT name FROM core.TableInfo
                                 WHERE database_id = d.database_id);

---------------------------------------------------------------------------

CREATE TABLE ApiDB.OrthomclGroupDomain (
 orthomcl_domain_id           NUMERIC(10) NOT NULL,
 ortholog_group_id             NUMERIC(10) NOT NULL,
 description                   VARCHAR(255) NOT NULL,
 frequency                     FLOAT NOT NULL,
 modification_date             DATE NOT NULL,
 user_read                     NUMERIC(1) NOT NULL,
 user_write                    NUMERIC(1) NOT NULL,
 group_read                    NUMERIC(1) NOT NULL,
 group_write                   NUMERIC(1) NOT NULL,
 other_read                    NUMERIC(1) NOT NULL,
 other_write                   NUMERIC(1) NOT NULL,
 row_user_id                   NUMERIC(12) NOT NULL,
 row_group_id                  NUMERIC(3) NOT NULL,
 row_project_id                NUMERIC(4) NOT NULL,
 row_alg_invocation_id         NUMERIC(12) NOT NULL,
 FOREIGN KEY (ortholog_group_id) REFERENCES ApiDB.OrthologGroup (ortholog_group_id),
 PRIMARY KEY (orthomcl_domain_id)
);

GRANT insert, select, update, delete ON ApiDB.OrthomclGroupDomain TO gus_w;
GRANT select ON ApiDB.OrthomclGroupDomain TO gus_r;

CREATE INDEX ogd_group_ix ON apidb.OrthomclGroupDomain(ortholog_group_id, frequency, description) tablespace indx;

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
SELECT NEXTVAL('core.tableinfo_sq'), 'OrthomclGroupDomain',
       'Standard', 'orthomcl_domain_id',
       d.database_id, 0, 0, NULL, NULL, 1, localtimestamp, 1, 1, 1, 1, 1, 1, 1, 1,
       p.project_id, 0
FROM 
     (SELECT MAX(project_id) AS project_id FROM core.ProjectInfo) p,
     (SELECT database_id FROM core.DatabaseInfo WHERE name = 'ApiDB') d
WHERE 'OrthomclGroupDomain' NOT IN (SELECT name FROM core.TableInfo
                                 WHERE database_id = d.database_id);
