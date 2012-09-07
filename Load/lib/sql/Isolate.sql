select distinct project_id, source_id from apidbtuning.IsolateAttributes where project_id = '$PROJECT$' and  nvl(is_reference, 0) = $OTHER$
