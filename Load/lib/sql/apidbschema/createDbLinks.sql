CREATE PUBLIC DATABASE LINK prodS.login_comment
CONNECT TO plasmodbwww
IDENTIFIED BY vcltum33r
USING 'apicommS';

CREATE PUBLIC DATABASE LINK prodN.login_comment
CONNECT TO plasmodbwww
IDENTIFIED BY vcltum33r
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
