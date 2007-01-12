CREATE PUBLIC DATABASE LINK plasmodb.cbilprod
CONNECT TO plasmodbwww
IDENTIFIED BY po34weep
USING 'cbilprod.db.cbil.upenn.edu';

CREATE DATABASE LINK plasmodb.login_comment
CONNECT TO plasmodbwww
IDENTIFIED BY po34weep
USING 'apicomm.db.cbil.upenn.edu';

CREATE DATABASE LINK toxodb.login_comment
CONNECT TO toxodbwww
IDENTIFIED BY Rh2t0xic
USING 'apicomm.db.cbil.upenn.edu';

exit;
