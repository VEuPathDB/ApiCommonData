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

exit
