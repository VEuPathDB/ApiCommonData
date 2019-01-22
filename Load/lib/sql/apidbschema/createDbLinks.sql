-- CREATE PUBLIC DATABASE LINK prodS.login_comment
-- CONNECT TO APICOMM_DBLINK
-- IDENTIFIED BY "<password>"
-- USING 'apicommS';

-- CREATE PUBLIC DATABASE LINK prodN.login_comment
-- CONNECT TO APICOMM_DBLINK
-- IDENTIFIED BY "<password>"
-- USING 'apicommN';

-- CREATE PUBLIC DATABASE LINK devS.login_comment
-- CONNECT TO APICOMM_DBLINK
-- IDENTIFIED BY "<password>"
-- USING 'apicommDevS';

-- CREATE PUBLIC DATABASE LINK devN.login_comment
-- CONNECT TO APICOMM_DBLINK
-- IDENTIFIED BY "<password>"
-- USING 'apicommDevN';

-- CREATE PUBLIC DATABASE LINK acctdbN.profile
-- CONNECT TO ACCTDB_DBLINK
-- IDENTIFIED BY "<password>"
-- USING 'acctdbN';

-- CREATE PUBLIC DATABASE LINK acctdbS.profile
-- CONNECT TO ACCTDB_DBLINK
-- IDENTIFIED BY "<password>"
-- USING 'acctdbS';

-- rm15873 is for development of apicomm release-maintenance stuff
-- https://redmine.apidb.org/issues/15873
-- CREATE PUBLIC DATABASE LINK rm15873.login_comment
-- CONNECT TO APICOMM_DBLINK
-- IDENTIFIED BY "<password>"
-- USING 'rm15873';


exit
