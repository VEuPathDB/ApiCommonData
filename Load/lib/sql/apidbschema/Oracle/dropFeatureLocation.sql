DROP SEQUENCE apidb.FeatureLocation_sq;
DROP TABLE apidb.FeatureLocation;
DELETE FROM core.TableInfo
WHERE name = 'FeatureLocation' AND database_id = (SELECT database_id FROM core.DatabaseInfo WHERE name = 'ApiDB');

DROP SEQUENCE apidb.GeneLocation_sq;
DROP TABLE apidb.GeneLocation;
DELETE FROM core.TableInfo WHERE name = 'GeneLocation' AND database_id = (SELECT database_id FROM core.DatabaseInfo WHERE name = 'ApiDB');

DROP SEQUENCE apidb.TranscriptLocation_sq;
DROP TABLE apidb.TranscriptLocation;
DELETE FROM core.TableInfo WHERE name = 'TranscriptLocation' AND database_id = (SELECT database_id FROM core.DatabaseInfo WHERE name = 'ApiDB');

DROP SEQUENCE apidb.ExonLocation_sq;
DROP TABLE apidb.ExonLocation;
DELETE FROM core.TableInfo WHERE name = 'ExonLocation' AND database_id = (SELECT database_id FROM core.DatabaseInfo WHERE name = 'ApiDB');

DROP SEQUENCE apidb.CdsLocation_sq;
DROP TABLE apidb.CdsLocation;
DELETE FROM core.TableInfo WHERE name = 'CdsLocation' AND database_id = (SELECT database_id FROM core.DatabaseInfo WHERE name = 'ApiDB');

DROP SEQUENCE apidb.UtrLocation_sq;
DROP TABLE apidb.UtrLocation;
DELETE FROM core.TableInfo WHERE name = 'UtrLocation' AND database_id = (SELECT database_id FROM core.DatabaseInfo WHERE name = 'ApiDB');

DROP SEQUENCE apidb.IntronLocation_sq;
DROP TABLE apidb.IntronLocation;
DELETE FROM core.TableInfo WHERE name = 'IntronLocation' AND database_id = (SELECT database_id FROM core.DatabaseInfo WHERE name = 'ApiDB');

exit
