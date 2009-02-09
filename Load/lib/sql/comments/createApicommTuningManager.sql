create table apidb.TuningFamily (
        family_name    VARCHAR2(32),
        subversion_url VARCHAR2(200) NOT NULL,
        notify_emails  VARCHAR2(200) NOT NULL,
        PRIMARY KEY (family_name)
);

create table apidb.TuningInstance (
        family_name       VARCHAR2(32) NOT NULL,
        last_update       DATE,
        last_updater      VARCHAR2(50),
        last_check        DATE,
        last_checker      VARCHAR2(50),
        instance_nickname VARCHAR2(50),
        PRIMARY KEY (instance_nickname)
);

exit
