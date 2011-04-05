CREATE PUBLIC DATABASE LINK apidb.cbilprod
CONNECT TO plasmodbwww
IDENTIFIED BY po34weep
USING 'apicomm';

CREATE PUBLIC DATABASE LINK apidb.login_comment
CONNECT TO plasmodbwww
IDENTIFIED BY po34weep
USING 'apicomm';

exit
