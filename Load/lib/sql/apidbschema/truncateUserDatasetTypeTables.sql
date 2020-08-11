truncate table ApiDBUserDatasets.UD_NaFeatureExpression;

delete from ApiDBUserDatasets.UD_ProtocolAppNode;

delete from ApiDBUserDatasets.UD_ProfileSet;

truncate table ApiDBUserDatasets.UD_GeneId;

-- see order in the uninstaller
truncate table ApiDBUserDatasets.ud_AggregatedAbundance;
truncate table ApiDBUserDatasets.ud_Abundance;
truncate table ApiDBUserDatasets.ud_SampleDetail;
delete from  ApiDBUserDatasets.ud_Property;
delete from  ApiDBUserDatasets.ud_Sample;
delete from  ApiDBUserDatasets.ud_Presenter;

exit;
