-- run after bulk insert so that indices will be used in execution plan
analyze table PlasmoDB.Profile compute statistics;
analyze table PlasmoDB.ProfileElementName compute statistics;
