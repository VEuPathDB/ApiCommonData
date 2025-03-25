truncate table ApiDBUserDatasets.UD_NaFeatureExpression;

truncate table ApiDBUserDatasets.UD_ProtocolAppNode;

truncate table ApiDBUserDatasets.UD_ProfileSet;

truncate table ApiDBUserDatasets.UD_GeneId;

-- see order in the uninstaller
truncate table ApiDBUserDatasets.ud_AggregatedAbundance;
truncate table ApiDBUserDatasets.ud_Abundance;
truncate table ApiDBUserDatasets.ud_SampleDetail;
truncate table  ApiDBUserDatasets.ud_Property;
truncate table  ApiDBUserDatasets.ud_Sample;
truncate table  ApiDBUserDatasets.ud_Presenter;


-- drop dataset specific eda tables
SET SERVEROUTPUT ON;
BEGIN
  FOR rec IN
    (
      SELECT
        table_name
      FROM
        all_tables
      WHERE
        owner = 'APIDBUSERDATASETS'
        and (table_name like 'ATTRIBUTEVALUE_%'
             or table_name like 'ANCESTORS_%'
             or table_name like 'ATTRIBUTES_%'
             or table_name like 'COLLECTION_%'
             or table_name like 'COLLECTIONATTRIBUTE_%'
             or table_name like 'ATTRIBUTEGRAPH_%')
    )
  LOOP
   DBMS_OUTPUT.put_line (' dropping table:  ApiDBUserDatasets' || '.'||rec.table_name);
   EXECUTE immediate 'DROP TABLE  ApiDBUserDatasets' || '.'||rec.table_name || ' CASCADE CONSTRAINTS';
  END LOOP;
END;
/

-- truncate other eda tables
truncate table ApidbUserDatasets.DatasetAttributes;
truncate table ApiDBUserDatasets.StudyCharacteristic;
truncate table ApiDBUserDatasets.AttributeGraph;
truncate table ApiDBUserDatasets.Attribute;
truncate table ApiDBUserDatasets.AttributeValue;
truncate table ApiDBUserDatasets.ProcessAttributes;
truncate table ApiDBUserDatasets.EntityAttributes;
truncate table ApiDBUserDatasets.ProcessTypeComponent;
truncate table ApiDBUserDatasets.AttributeUnit;
truncate table ApiDBUserDatasets.ProcessType;
truncate table ApiDBUserDatasets.EntityTypeGraph;
truncate table ApiDBUserDatasets.EntityType;
truncate table ApiDBUserDatasets.Study;


exit;
