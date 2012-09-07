SELECT DISTINCT project_id, source_id FROM apidbtuning.geneAttributes where project_id = '$PROJECT$' and organism ='$ORGANISM$' and nvl(is_deprecated, 0) = $OTHER$
