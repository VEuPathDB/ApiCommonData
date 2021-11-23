set CONCAT OFF;

DROP TABLE &1.StudyCharacteristic;
DROP SEQUENCE &1.StudyCharacteristic_sq;
DELETE FROM core.TableInfo
WHERE lower(name) =  'studycharacteristic'
  AND database_id IN (SELECT database_id
                      FROM core.DatabaseInfo
                      WHERE lower(name) = '&1');

DROP TABLE &1.AttributeGraph;
DROP SEQUENCE &1.AttributeGraph_sq;
DELETE FROM core.TableInfo
WHERE lower(name) =  'attributegraph'
  AND database_id IN (SELECT database_id
                      FROM core.DatabaseInfo
                      WHERE lower(name) = '&1');


DROP TABLE &1.Attribute;
DROP SEQUENCE &1.Attribute_sq;
DELETE FROM core.TableInfo
WHERE lower(name) =  'attribute'
  AND database_id IN (SELECT database_id
                      FROM core.DatabaseInfo
                      WHERE lower(name) = '&1');

DROP TABLE &1.AttributeValue;
DROP SEQUENCE &1.AttributeValue_sq;
DELETE FROM core.TableInfo
WHERE lower(name) =  'attributevalue'
  AND database_id IN (SELECT database_id
                      FROM core.DatabaseInfo
                      WHERE lower(name) = '&1');

DROP TABLE &1.ProcessAttributes;
DROP SEQUENCE &1.ProcessAttributes_sq;
DELETE FROM core.TableInfo
WHERE lower(name) =  'processattributes'
  AND database_id IN (SELECT database_id
                      FROM core.DatabaseInfo
                      WHERE lower(name) = '&1');


DROP TABLE &1.EntityAttributes;
DROP SEQUENCE &1.EntityAttributes_sq;
DELETE FROM core.TableInfo
WHERE lower(name) =  'entityattributes'
  AND database_id IN (SELECT database_id
                      FROM core.DatabaseInfo
                      WHERE lower(name) = '&1');


DROP TABLE &1.ProcessTypeComponent;
DROP SEQUENCE &1.ProcessTypeComponent_sq;
DELETE FROM core.TableInfo
WHERE lower(name) =  'processtypecomponent'
  AND database_id IN (SELECT database_id
                      FROM core.DatabaseInfo
                      WHERE lower(name) = '&1');



DROP TABLE &1.AttributeUnit;
DROP SEQUENCE &1.AttributeUnit_sq;
DELETE FROM core.TableInfo
WHERE lower(name) =  'attributeunit'
  AND database_id IN (SELECT database_id
                      FROM core.DatabaseInfo
                      WHERE lower(name) = '&1');



DROP TABLE &1.ProcessType;
DROP SEQUENCE &1.ProcessType_sq;
DELETE FROM core.TableInfo
WHERE lower(name) =  'processtype'
  AND database_id IN (SELECT database_id
                      FROM core.DatabaseInfo
                      WHERE lower(name) = '&1');




DROP TABLE &1.EntityTypeGraph;
DROP SEQUENCE &1.EntityTypeGraph_sq;
DELETE FROM core.TableInfo
WHERE lower(name) =  'entitytypegraph'
  AND database_id IN (SELECT database_id
                      FROM core.DatabaseInfo
                      WHERE lower(name) = '&1');




DROP TABLE &1.EntityType;
DROP SEQUENCE &1.EntityType_sq;
DELETE FROM core.TableInfo
WHERE lower(name) =  'entitytype'
  AND database_id IN (SELECT database_id
                      FROM core.DatabaseInfo
                      WHERE lower(name) = '&1');


DROP TABLE &1.Study;
DROP SEQUENCE &1.Study_sq;
DELETE FROM core.TableInfo
WHERE lower(name) =  'study'
  AND database_id IN (SELECT database_id
                      FROM core.DatabaseInfo
                      WHERE lower(name) = '&1');


SET SERVEROUTPUT ON;
BEGIN
  FOR rec IN
    (
      SELECT
        table_name
      FROM
        all_tables
      WHERE
        owner = '&1' and table_name like 'ATTRIBUTEVALUE_%' or table_name like 'ANCESTORS_%' or table_name like 'ATTRIBUTEGRAPH_%'
    )
  LOOP
   DBMS_OUTPUT.put_line (' dropping table:  &1.'||rec.table_name);
   EXECUTE immediate 'DROP TABLE  &1.'||rec.table_name || ' CASCADE CONSTRAINTS';
  END LOOP;
END;
/


exit;
