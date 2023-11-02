
create table ApiDBUserDatasets.InstalledUserDataset (
user_dataset_id NUMERIC(20) not null,
name           varchar(100) not null,
is_invalid     NUMERIC(1),
invalid_reason varchar(1000),
primary key (user_dataset_id)
);
GRANT insert, select, update, delete ON ApiDBUserDatasets.InstalledUserDataset TO gus_w;
GRANT select ON ApiDBUserDatasets.InstalledUserDataset TO gus_r;

--------------------------------------------------------------------------------

create table ApiDBUserDatasets.UserDatasetOwner (
user_id NUMERIC(12) not null,
user_dataset_id NUMERIC(20) not null,
primary key (user_id, user_dataset_id),
FOREIGN KEY (user_dataset_id) REFERENCES ApiDBUserDatasets.InstalledUserDataset
);
GRANT insert, select, update, delete ON ApiDBUserDatasets.UserDatasetOwner TO gus_w;
GRANT select ON ApiDBUserDatasets.UserDatasetOwner TO gus_r;


---------------------------------------------------------------------------------

create table ApiDBUserDatasets.UserDatasetSharedWith (
owner_user_id NUMERIC(12) not null,
recipient_user_id NUMERIC(12) not null,
user_dataset_id NUMERIC(20) not null,
primary key (owner_user_id, recipient_user_id, user_dataset_id),
FOREIGN KEY (user_dataset_id) REFERENCES ApiDBUserDatasets.InstalledUserDataset
);
GRANT insert, select, update, delete ON ApiDBUserDatasets.UserDatasetSharedWith TO gus_w;
GRANT select ON ApiDBUserDatasets.UserDatasetSharedWith TO gus_r;

create index udshareix_01
   on ApiDBUserDatasets.UserDatasetSharedWith (user_dataset_id, owner_user_id, recipient_user_id)
   tablespace indx;


---------------------------------------------------------------------------------


create view ApiDBUserDatasets.UserDatasetAccessControl as
 select USER_ID,USER_DATASET_ID from ApiDBUserDatasets.UserDatasetOwner
union 
  select RECIPIENT_USER_ID AS USER_ID,USER_DATASET_ID from ApiDBUserDatasets.UserDatasetSharedWith;

GRANT select ON ApiDBUserDatasets.UserDatasetAccessControl TO gus_r;

---------------------------------------------------------------------------------

CREATE TABLE ApiDBUserDatasets.UserDatasetEvent
(
  event_id                  NUMERIC(20)    NOT NULL PRIMARY KEY,
  event_type                VARCHAR(16)   NOT NULL,
  status                    VARCHAR(18)  NOT NULL,
  user_dataset_id           NUMERIC(20)    NOT NULL,
  user_dataset_type_name    VARCHAR(256) NOT NULL,
  user_dataset_type_version VARCHAR(256) NOT NULL,
  handled_time              TIMESTAMP WITH TIME ZONE NOT NULL
);
GRANT insert, select, update, delete ON ApiDBUserDatasets.UserDatasetEvent TO gus_w;
GRANT select ON ApiDBUserDatasets.UserDatasetEvent TO gus_r;


