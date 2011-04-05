
CREATE USER amitodbwww
IDENTIFIED BY temppass
QUOTA UNLIMITED ON users 
QUOTA UNLIMITED ON gus
DEFAULT TABLESPACE gus
TEMPORARY TABLESPACE temp;

ALTER USER amitodbwww PASSWORD EXPIRE;

GRANT CREATE TABLE to amitodbwww;
GRANT CREATE SEQUENCE to amitodbwww;
GRANT CREATE SESSION to amitodbwww;

GRANT gus_w TO amitodbwww;
GRANT gus_r TO amitodbwww;

--------------------------------------------------------------------------------
CREATE USER amitodbwwwdev
IDENTIFIED BY temppass
QUOTA UNLIMITED ON users 
QUOTA UNLIMITED ON gus
DEFAULT TABLESPACE gus
TEMPORARY TABLESPACE temp;

ALTER USER amitodbwwwdev PASSWORD EXPIRE;

GRANT CREATE TABLE to amitodbwwwdev;
GRANT CREATE SEQUENCE to amitodbwwwdev;
GRANT CREATE SESSION to amitodbwwwdev;

GRANT gus_w TO amitodbwwwdev;
GRANT gus_r TO amitodbwwwdev;

--------------------------------------------------------------------------------
CREATE USER giardiadbwww
IDENTIFIED BY temppass
QUOTA UNLIMITED ON users 
QUOTA UNLIMITED ON gus
DEFAULT TABLESPACE gus
TEMPORARY TABLESPACE temp;

ALTER USER giardiadbwww PASSWORD EXPIRE;

GRANT CREATE TABLE to giardiadbwww;
GRANT CREATE SEQUENCE to giardiadbwww;
GRANT CREATE SESSION to giardiadbwww;

GRANT gus_w TO giardiadbwww;
GRANT gus_r TO giardiadbwww;

--------------------------------------------------------------------------------
CREATE USER giardiadbwwwdev
IDENTIFIED BY temppass
QUOTA UNLIMITED ON users 
QUOTA UNLIMITED ON gus
DEFAULT TABLESPACE gus
TEMPORARY TABLESPACE temp;

ALTER USER giardiadbwwwdev PASSWORD EXPIRE;

GRANT CREATE TABLE to giardiadbwwwdev;
GRANT CREATE SEQUENCE to giardiadbwwwdev;
GRANT CREATE SESSION to giardiadbwwwdev;

GRANT gus_w TO giardiadbwwwdev;
GRANT gus_r TO giardiadbwwwdev;

--------------------------------------------------------------------------------
CREATE USER plasmodbwww
IDENTIFIED BY temppass
QUOTA UNLIMITED ON users 
QUOTA UNLIMITED ON gus
DEFAULT TABLESPACE gus
TEMPORARY TABLESPACE temp;

ALTER USER plasmodbwww PASSWORD EXPIRE;

GRANT CREATE TABLE to plasmodbwww;
GRANT CREATE SEQUENCE to plasmodbwww;
GRANT CREATE SESSION to plasmodbwww;

GRANT gus_w TO plasmodbwww;
GRANT gus_r TO plasmodbwww;

--------------------------------------------------------------------------------
CREATE USER plasmodbwwwdev
IDENTIFIED BY temppass
QUOTA UNLIMITED ON users 
QUOTA UNLIMITED ON gus
DEFAULT TABLESPACE gus
TEMPORARY TABLESPACE temp;

ALTER USER plasmodbwwwdev PASSWORD EXPIRE;

GRANT CREATE TABLE to plasmodbwwwdev;
GRANT CREATE SEQUENCE to plasmodbwwwdev;
GRANT CREATE SESSION to plasmodbwwwdev;

GRANT gus_w TO plasmodbwwwdev;
GRANT gus_r TO plasmodbwwwdev;

--------------------------------------------------------------------------------
CREATE USER toxodbwww
IDENTIFIED BY temppass
QUOTA UNLIMITED ON users 
QUOTA UNLIMITED ON gus
DEFAULT TABLESPACE gus
TEMPORARY TABLESPACE temp;

ALTER USER toxodbwww PASSWORD EXPIRE;

GRANT CREATE TABLE to toxodbwww;
GRANT CREATE SEQUENCE to toxodbwww;
GRANT CREATE SESSION to toxodbwww;

GRANT gus_w TO toxodbwww;
GRANT gus_r TO toxodbwww;

--------------------------------------------------------------------------------
CREATE USER toxodbwwwdev
IDENTIFIED BY temppass
QUOTA UNLIMITED ON users 
QUOTA UNLIMITED ON gus
DEFAULT TABLESPACE gus
TEMPORARY TABLESPACE temp;

ALTER USER toxodbwwwdev PASSWORD EXPIRE;

GRANT CREATE TABLE to toxodbwwwdev;
GRANT CREATE SEQUENCE to toxodbwwwdev;
GRANT CREATE SESSION to toxodbwwwdev;

GRANT gus_w TO toxodbwwwdev;
GRANT gus_r TO toxodbwwwdev;

exit
