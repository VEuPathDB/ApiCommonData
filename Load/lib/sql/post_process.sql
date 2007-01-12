-- run after bulk insert so that indices will be used in execution plan
analyze table apidb.Profile compute statistics;
analyze table apidb.ProfileElementName compute statistics;

exit
