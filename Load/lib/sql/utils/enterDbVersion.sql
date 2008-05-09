
------------------------------------------------------------------------------

INSERT INTO Core.DatabaseVersion
   (DATABASE_VERSION_ID, VERSION, MODIFICATION_DATE, USER_READ, USER_WRITE, GROUP_READ, GROUP_WRITE, OTHER_READ, OTHER_WRITE, ROW_USER_ID, ROW_GROUP_ID, ROW_PROJECT_ID, ROW_ALG_INVOCATION_ID) VALUES (1, 3.5, sysdate,1,1,1,1,1,0,1,1,1,1);

------------------------------------------------------------------------

exit;
