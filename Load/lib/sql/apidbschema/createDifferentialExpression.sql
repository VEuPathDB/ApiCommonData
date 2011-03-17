DROP VIEW rad.DifferentialExpression;

CREATE VIEW rad.DifferentialExpression AS
SELECT
   analysis_result_id,
   subclass_view,
   analysis_id,
   table_id,
   row_id,
   float1 as confidence,
   float2 as fold_change,
   float3 as pvalue_mant,
   number1 as pvalue_exp,
   modification_date,
   user_read,
   user_write,
   group_read,
   group_write,
   other_read,
   other_write,
   row_user_id,
   row_group_id,
   row_project_id,
   row_alg_invocation_id
FROM RAD.AnalysisResultImp
WHERE subclass_view = 'DifferentialExpression'
WITH CHECK OPTION;

GRANT SELECT ON rad.DifferentialExpression TO gus_r;
GRANT INSERT, UPDATE, DELETE ON rad.DifferentialExpression TO gus_w;

exit
