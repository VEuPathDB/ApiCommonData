CREATE PUBLIC DATABASE LINK apidb.login_comment
CONNECT TO plasmodbwww
IDENTIFIED BY po34weep
USING 'apicommS';

CREATE PUBLIC DATABASE LINK alt.login_comment
CONNECT TO plasmodbwww
IDENTIFIED BY po34weep
USING 'apicommN';

CREATE PUBLIC DATABASE LINK devS.login_comment
CONNECT TO plasmodbwww
IDENTIFIED BY po34weep
USING 'apicommDevS';

CREATE PUBLIC DATABASE LINK devN.login_comment
CONNECT TO plasmodbwww
IDENTIFIED BY po34weep
USING 'apicommDevN';


exit
