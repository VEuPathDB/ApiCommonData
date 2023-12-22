package ApiCommonData::Load::Plugin::LoadDatasetSpecificEntityGraph;

@ISA = qw(GUS::PluginMgr::Plugin ApiCommonData::Load::Plugin::ParameterizedSchema);
use strict;
use warnings;
use GUS::PluginMgr::Plugin;
use ApiCommonData::Load::Plugin::ParameterizedSchema;

use ApiCommonData::Load::StudyUtils qw/dropTablesLike/;

use Data::Dumper;

my $purposeBrief = 'Read Study tables and insert tall table for attribute values and attribute table';
my $purpose = $purposeBrief;

my $tablesAffected = [];

my $tablesDependedOn = [];

my $howToRestart = ""; 
my $failureCases = "";
my $notes = "";

my $documentation = { purpose => $purpose,
                      purposeBrief => $purposeBrief,
                      tablesAffected => $tablesAffected,
                      tablesDependedOn => $tablesDependedOn,
                      howToRestart => $howToRestart,
                      failureCases => $failureCases,
                      notes => $notes
};

my $argsDeclaration =
[

 stringArg({ name            => 'extDbRlsSpec',
	     descr           => 'ExternalDatabaseSpec for the Entity Graph',
	     reqd            => 1,
	     constraintFunc  => undef,
	     isList          => 0 }),
   stringArg({name           => 'schema',
            descr          => 'GUS::Model schema for entity tables',
            reqd           => 1,
            constraintFunc => undef,
              isList         => 0, }),
    fileArg({name           => 'collectionsYaml',
            descr          => 'optional yaml file which defines collection ontology terms (and optionally children + ranges)',
            reqd           => 0,
        mustExist      => 1,
        format         => '',
            constraintFunc => undef,
            isList         => 0, }),


];

my $SCHEMA = '__SCHEMA__'; # must be replaced with real schema name
my $TERM_SCHEMA = "SRES";

my @UNDO_TABLES;
my @REQUIRE_TABLES;

# ----------------------------------------------------------------------

sub new {
  my ($class) = @_;
  my $self = {};
  bless($self,$class);

  $self->initialize({ requiredDbVersion => 4.0,
                      cvsRevision       => '$Revision$',
                      name              => ref($self),
                      argsDeclaration   => $argsDeclaration,
                      documentation     => $documentation});
  $self->{_require_tables} = \@REQUIRE_TABLES;
  $self->{_undo_tables} = \@UNDO_TABLES;
  return $self;
}

# ======================================================================

sub run {
  my ($self) = @_;

  $SCHEMA = $self->getArg('schema');
  if(uc($SCHEMA) eq 'APIDBUSERDATASETS') {
    $TERM_SCHEMA = 'APIDBUSERDATASETS';
  }

  my $extDbRlsSpec = $self->getArg('extDbRlsSpec');
  my $extDbRlsId = $self->getExtDbRlsId($extDbRlsSpec, undef, $TERM_SCHEMA);


  my $studies = $self->sqlAsDictionary( Sql  => "select study_id, internal_abbrev from ${SCHEMA}.study where external_database_release_id = $extDbRlsId");

  $self->error("Expected one study row.  Found ". scalar keys %$studies) unless(scalar keys %$studies == 1);


  $self->dropTables($extDbRlsSpec);

  my $collectionsYamlFile = $self->getArg('collectionsYaml');


  my $collections = {};
  if($collectionsYamlFile) {
    $collections = ApiCommonData::Load::StudyUtils::parseCollectionsConfig($collectionsYamlFile);
  }

  my $dbh = $self->getDbHandle();
  $dbh->{RaiseError} = 1;

  $dbh->do("SET DateStyle = 'ISO, YMD'") or die $self->getDbHandle()->errstr;
#  $dbh->do("alter session disable parallel query") or die $self->getDbHandle()->errstr;
#  $dbh->do("alter session disable parallel dml") or die $self->getDbHandle()->errstr;
#  $dbh->do("alter session disable parallel ddl") or die $self->getDbHandle()->errstr;

    foreach my $studyId (keys %$studies) {
    my $studyAbbrev = $studies->{$studyId};
    $self->log("Loading Study: $studyAbbrev");
    my $entityTypeInfo = $self->setEntityTypeInfoFromStudyId($studyId);

    foreach my $entityTypeId (keys %$entityTypeInfo) {
      my $entityTypeAbbrev = $self->getEntityTypeInfo($entityTypeId, "internal_abbrev");

      $self->log("Making Tables for Entity Type $entityTypeAbbrev (ID $entityTypeId)");

      $self->createAncestorsTable($studyId, $entityTypeId, $studyAbbrev);
      my $attributeGraphTableName = $self->createAttributeGraphTable($entityTypeId, $studyAbbrev, $studyId, $extDbRlsId);


      $self->createWideTable($entityTypeId, $entityTypeAbbrev, $studyAbbrev);

      if(scalar(keys(%$collections)) > 0) {
        if($self->maybeCreateCollections($attributeGraphTableName, $collections)) {
          $dbh->do("update ${SCHEMA}.EntityTypeGraph set has_attribute_collections = 1 where entity_type_id = $entityTypeId");
        }
      }
    }
  }

    return("Created Dataset specific tables");
}


sub makeWideTableColumnString {
  my ($self, $entityTypeId) = @_;

  my $specSql = "select stable_id
     , data_type
     , is_multi_valued
     , case when process_type_id is null 
            then 'e' 
            else 'p' 
       end as table_type
from ${SCHEMA}.ATTRIBUTE
where entity_type_id = $entityTypeId";
  my $dbh = $self->getDbHandle();
  my $sh = $dbh->prepare($specSql);
  $sh->execute();


  my (@entityColumnStrings, @processColumnStrings);
  while(my ($stableId, $dataType, $isMultiValued, $tableType) = $sh->fetchrow_array()) {
    my $path = "\$.${stableId}[0]";


    $dataType = lc($dataType) eq 'string' ? "VARCHAR" : uc($dataType);
    # REVIEW Is this the right way to handle longitude?
    $dataType = lc($dataType) eq 'longitude' ? "NUMERIC" : uc($dataType);
    $dataType = lc($dataType) eq 'number' ? "NUMERIC" : uc($dataType);
    $dataType = lc($dataType) eq 'date' ? "text" : uc($dataType);
    # multiValued data always return JSON array
    if($isMultiValued) {
      $dataType = "text";
      $path = "TODO";
    }

    my $entityOrProcess = $tableType eq 'p' ? 'process_atts' : 'entity_atts';

    my $string = "(${entityOrProcess}::json -> '$stableId' ->> 0)::${dataType} as $stableId";

    if($tableType eq 'p') {
      push @processColumnStrings, $string;
    }

    elsif($tableType eq 'e') {
      push @entityColumnStrings, $string;
    }
    else {
      $self->error("Unexpected table_type $tableType");
    }
  }

  return \@entityColumnStrings, \@processColumnStrings;
}

sub createWideTable {
  my ($self, $entityTypeId, $entityTypeAbbrev, $studyAbbrev) = @_;

  my $tableName = "ATTRIBUTES_${studyAbbrev}_${entityTypeAbbrev}";

  my ($entityColumnStrings, $processColumnStrings) = $self->makeWideTableColumnString($entityTypeId);
  my $totalColumnCount = 0 + @{$entityColumnStrings} +  @{$processColumnStrings};

  # no wide tables if we have more than 1000 columns
  return if($totalColumnCount > 1000);

  $self->log("Creating TABLE:  $tableName");
  my $entityColumns = join("\n,", @$entityColumnStrings);
  my $processColumns = join("\n,", @$processColumnStrings);


  my $withAllAttsSql = "
with all_atts as (
select ea.stable_id
     , COALESCE(pa.atts, '{}') as process_atts
     , COALESCE(ea.atts, '{}') as entity_atts
from ${SCHEMA}.processattributes pa
RIGHT JOIN ${SCHEMA}.EntityAttributes_bfv ea
ON pa.out_entity_id = ea.entity_attributes_id
where ea.entity_type_id = $entityTypeId
)
  ";

  my $sql;
  if(scalar @$entityColumnStrings > 0 && scalar @$processColumnStrings > 0) {
    $sql = "$withAllAttsSql
            select  all_atts.stable_id,
                  , $entityColumns
                  , $processColumns
            from all_atts
            ";

  }
  elsif(scalar @$entityColumnStrings > 0) {
    $sql = "$withAllAttsSql
            select  all_atts.stable_id
                  , $entityColumns
            from all_atts
            ";
  }
  elsif(scalar @$processColumnStrings > 0) {
    $sql = "$withAllAttsSql
            select  all_atts.stable_id
                  , $processColumns
            from all_atts
            ";
  }
  else {
    $sql = "select ea.stable_id
            from ${SCHEMA}.entityattributes_bfv ea
            where ea.entity_type_id = $entityTypeId
             ";
  }

  my $dbh = $self->getDbHandle();

  $self->log("CREATE TABLE $SCHEMA.$tableName as $sql");
  $dbh->do("CREATE TABLE $SCHEMA.$tableName as $sql") or die $self->getDbHandle()->errstr;

  $dbh->do("GRANT SELECT ON $SCHEMA.$tableName TO gus_r") or die $self->getDbHandle()->errstr;

  # Check for stable_id (entities with no attributes will have none)
  my $sh = $dbh->prepare("select count(*) from $SCHEMA.$tableName");
  $sh->execute();
  my ($rowCount) = $sh->fetchrow_array();
  $sh->finish();

  if($rowCount){
    $self->log("Creating index on $SCHEMA.$tableName STABLE_ID");
    $dbh->do("CREATE INDEX ATTRIBUTES_${entityTypeId}_IX ON $SCHEMA.$tableName (STABLE_ID) TABLESPACE INDX") or die $dbh->errstr;
  }
  return $tableName;
}


sub createAncestorsTable {
  my ($self, $studyId, $entityTypeId, $studyAbbrev) = @_;

  my $entityTypeAbbrev = $self->getEntityTypeInfo($entityTypeId, "internal_abbrev");

  my $tableName = "${SCHEMA}.Ancestors_${studyAbbrev}_${entityTypeAbbrev}";
  my $fieldSuffix = "_stable_id";

  $self->log("Creating TABLE: $tableName");


  # my $ancestorEntityTypeIds = $self->createEmptyAncestorsTable($tableName, $entityTypeId, $fieldSuffix, $entityTypeIds);
  # $self->populateAncestorsTable($tableName, $entityTypeId, $ancestorEntityTypeIds, $studyId, $fieldSuffix, $entityTypeIds);
  # return $tableName;

  my $ancestorEntityTypeIds = $self->createEmptyAncestorsTable($tableName, $entityTypeId, $fieldSuffix);

  $self->populateAncestorsTable($tableName, $entityTypeId, $fieldSuffix, $ancestorEntityTypeIds, $studyId);


}

sub populateAncestorsTable {
  my ($self, $tableName, $entityTypeId, $fieldSuffix, $ancestorEntityTypeIds, $studyId) = @_;

  my $stableIdField = $self->getEntityTypeInfo($entityTypeId, "internal_abbrev") . $fieldSuffix;

  my $sql = "select * from (
  with f as 
  (select p.in_entity_id
        , i.stable_id in_stable_id
        , i.entity_type_id in_type_id
        , p.out_entity_id
        , o.entity_type_id out_type_id
        , o.stable_id out_stable_id
  from ${SCHEMA}.processattributes p
     , ${SCHEMA}.entityattributes_bfv i
     , ${SCHEMA}.entityattributes_bfv o
  where p.in_entity_id = i.entity_attributes_id
  and p.out_entity_id = o.entity_attributes_id
  and o.study_id = $studyId
  and i.study_id = $studyId
  ),
	  ancestors as (
	      WITH RECURSIVE recursive_ancestors AS (
	        SELECT
	            f.out_stable_id AS stable_id,
	            f.out_stable_id AS root_stable_id,
                f.in_entity_id,
                f.in_stable_id,
	            f.in_type_id,
                f.out_entity_id
	        FROM f
          WHERE f.out_type_id = $entityTypeId
	        UNION ALL
	        SELECT
	            ra.stable_id,
	            ra.root_stable_id,
                f.in_entity_id,
                f.in_stable_id,
	            f.in_type_id,
                f.out_entity_id
            FROM f
	        JOIN recursive_ancestors ra ON f.out_entity_id = ra.in_entity_id
	      )
	      select * from recursive_ancestors
	  )
SELECT DISTINCT root_stable_id AS stable_id, in_stable_id, in_type_id
 FROM ancestors
  union
  select ea.stable_id, null, null
  from ${SCHEMA}.entityattributes_bfv ea
  where ea.entity_type_id = $entityTypeId
) all_ancestors order by stable_id";

  my $dbh = $self->getDbHandle();
  my $sh = $dbh->prepare($sql);
  $sh->execute();

  my $hasFields = scalar @$ancestorEntityTypeIds > 0;

  my @fields = map { $self->getEntityTypeInfo($_, "internal_abbrev") . $fieldSuffix } @$ancestorEntityTypeIds;

  my $fieldsString = $hasFields ? "$stableIdField, " . join(",",  @fields) : $stableIdField;

  my $qString = $hasFields ? "?, " . join(",", map { "?" } @$ancestorEntityTypeIds) : "?";

  my $insertSql = "insert into $tableName (${fieldsString}) values ($qString)";

  my $insertSh = $dbh->prepare($insertSql);

  my %entities;

  my $prevId;
  my $count; 

  while(my ($entityId, $parentId, $parentTypeId) = $sh->fetchrow_array()) {
    $self->error("Data fetching terminated early by error: $DBI::errstr") if $DBI::err;

    if($prevId && $prevId ne $entityId) {
      $self->insertAncestorRow($insertSh, $prevId, \%entities, $ancestorEntityTypeIds);
      %entities = ();
    }

    if ($parentId) {
      # for mega study, the query above will return the internal entity type which needs to be mapped
      # for the standard study, use the identity mapping
      #my $mappedParentTypeId = $self->mapEntityTypeId($parentTypeId);
      #$entities{$mappedParentTypeId} = $parentId;
      $entities{$parentTypeId} = $parentId;
    }
    $prevId = $entityId;

    if(++$count % 1000 == 0) {
      $dbh->commit();
     }
  }

  $self->insertAncestorRow($insertSh, $prevId, \%entities, $ancestorEntityTypeIds) if($prevId);
  $insertSh->finish();
  $dbh->commit();
}

sub insertAncestorRow {
  my ($self, $sh, $entityId, $ancestorEntityIds, $allAncestorEntityTypeIds) = @_;

  my @values = map { $ancestorEntityIds->{$_} } @$allAncestorEntityTypeIds;
  $sh->execute($entityId, @values) or $self->error($self->getDbHandle()->errstr);
}

sub createEmptyAncestorsTable {
  my ($self, $tableName, $entityTypeId, $fieldSuffix) = @_;


  my $stableIdField = $self->getEntityTypeInfo($entityTypeId, "internal_abbrev") . $fieldSuffix;

  my $sql = "WITH RECURSIVE ancestors (entity_type_id)
             AS
             (
             SELECT entity_type_id, parent_id
             FROM ${SCHEMA}.entitytypegraph
             WHERE entity_type_id = ?
             UNION ALL
             SELECT et.entity_type_id, et.parent_id
             FROM ${SCHEMA}.entitytypegraph et
             INNER JOIN ancestors anc ON anc.parent_id = et.entity_type_id
             )
             SELECT entity_type_id FROM ancestors";

  my $dbh = $self->getDbHandle();
  my $sh = $dbh->prepare($sql);
  $sh->execute($entityTypeId);
  
  my (@fields, @ancestorEntityTypeIds);  
  while(my ($id) = $sh->fetchrow_array()) {
    my $entityTypeAbbrev = $self->getEntityTypeInfo($id, "internal_abbrev");
    push @fields, $entityTypeAbbrev unless($id == $entityTypeId);
    push @ancestorEntityTypeIds, $id unless($id == $entityTypeId);
  }

  my $fieldsDef = join("\n", map { $_ . $fieldSuffix . " varchar(200)," } @fields);

  my $createTableSql = "CREATE TABLE $tableName (
$stableIdField         varchar(200) NOT NULL,
$fieldsDef
PRIMARY KEY ($stableIdField)
)";


  $dbh->do($createTableSql) or die $dbh->errstr;

  # create a pair of indexes for each field
  foreach my $field (@fields) {
    $dbh->do("CREATE INDEX ancestors_${entityTypeId}_${field}_1_ix ON $tableName ($stableIdField, ${field}${fieldSuffix}) TABLESPACE indx") or die $dbh->errstr;
    $dbh->do("CREATE INDEX ancestors_${entityTypeId}_${field}_2_ix ON $tableName (${field}${fieldSuffix}, $stableIdField) TABLESPACE indx") or die $dbh->errstr;
  }

  $dbh->do("GRANT SELECT ON $tableName TO gus_r");

  return \@ancestorEntityTypeIds;
}



sub setEntityTypeInfoFromStudyId {
  my ($self, $studyId) = @_;

  my $sql = "select t.entity_type_id, t.internal_abbrev, t.type_id, t.entity_type_id from ${SCHEMA}.entitytype t where t.study_id = $studyId";

  my $dbh = $self->getQueryHandle();
  my $sh = $dbh->prepare($sql);
  $sh->execute();

  my $entityTypeInfo = {};

  while(my ($entityTypeId, $internalAbbrev, $typeId, $internalEntityTypeIds) = $sh->fetchrow_array()) {
    $entityTypeInfo->{$entityTypeId}->{internal_abbrev} = $internalAbbrev;
    $entityTypeInfo->{$entityTypeId}->{type_id} = $typeId;
  }
  $sh->finish();

  $self->{_entity_type_info} = $entityTypeInfo;

  return $entityTypeInfo;
}

# sub mapEntityTypeId {
#   my ($self, $entityTypeId) = @_;

#   my $mappedId = $self->{_entity_type_id_map}->{$entityTypeId};

#   unless($mappedId) {
#     $self->error("Could not map entityTypeId: $entityTypeId");
#   }

#   return $mappedId
# }

sub getEntityTypeInfo {
  my ($self, $entityTypeId, $key) = @_;

  my @allowedKeys = ("internal_abbrev", "type_id");

  unless(grep(/$key/, @allowedKeys)) {
    $self->error("Invalid hash key:  $key");
  }

  my $et = $self->{_entity_type_info}->{$entityTypeId};

  unless($et) {
    $self->error("no entity type info for entity type id:  $entityTypeId");
  }

  my $value = $et->{$key};

  unless(defined $value) {
    $self->error("no value for entity type id [$entityTypeId] and key [$key]");
  }

  return $value;
}



sub createAttributeGraphTable {
  my ($self, $entityTypeId, $studyAbbrev, $studyId, $extDbRlsId) = @_;

  my $entityTypeAbbrev = $self->getEntityTypeInfo($entityTypeId, "internal_abbrev");

  my $tableName = "${SCHEMA}.AttributeGraph_${studyAbbrev}_${entityTypeAbbrev}";

  $self->log("Creating TABLE:  $tableName");

  # ${SCHEMA}.attribute stable_id could be from sres.ontologyterm, or not
  # if yes, it could also be another term's parent
  # (but not a multifilter - term_type for attributes that have values is default) -- TODO term_type and is_hidden are DEPRECATED, rewrite this comment
  # hence this is only using atg for the parent-child relationship
  # and only adding atg entries which aren't already in
  # careful: att.ontology_term_id doesn't have to exist

  my $sql = "CREATE TABLE $tableName as
  WITH attAnnProps AS
  (select ontology_term_id, (props::json -> 'unitLabel' ->> 0)::text as unit_override from ${SCHEMA}.annotationproperties where external_database_release_id = $extDbRlsId)
   , att AS
  (SELECT a.*, t.unit_override
   FROM attAnnProps t
   RIGHT JOIN ${SCHEMA}.attribute a
   ON a.ontology_term_id = t.ONTOLOGY_TERM_ID
   WHERE entity_type_id = $entityTypeId
   ), satg AS
  (SELECT atg.*
   FROM ${SCHEMA}.attributegraph atg
   WHERE study_id = $studyId
  ), atg as
  (WITH RECURSIVE recursive_satg as (
      SELECT s.*
      FROM satg s
      INNER JOIN (
          SELECT DISTINCT stable_id
          FROM att
          ) AS subq
      ON s.stable_id = subq.stable_id
      WHERE s.study_id = $studyId
      UNION ALL
      SELECT s.*
      FROM satg s
      INNER JOIN recursive_satg rs
      ON s.ontology_term_id = rs.parent_ontology_term_id
       AND s.parent_stable_id != 'Thing'
       AND s.study_id = rs.study_id
     )
   select * from recursive_satg
  )
-- this bit gets the internal nodes
SELECT --  distinct
       atg.stable_id
     , atg.parent_stable_id
     , atg.provider_label
     , atg.display_name
     , atg.definition
     , null as vocabulary
     , atg.display_type
     , atg.hidden
     , atg.display_order
     , atg.display_range_min
     , atg.display_range_max
     , null as range_min
     , null as range_max
     , null as bin_width_override
     , null as bin_width_computed
     , null as mean 
     , null as median
     , null as lower_quartile 
     , null as upper_quartile 
     , atg.is_temporal
     , atg.is_featured
     , atg.is_merge_key
     , atg.impute_zero
     , atg.is_repeated
     , atg.variable_spec_to_impute_zeroes_for
     , atg.has_study_dependent_vocabulary
     , weighting_variable_spec
     , 0 as has_values
     , null as data_type
     , null as distinct_values_count
     , null as is_multi_valued
     , null as data_shape
     , null as unit
     , null as scale
     , null as precision
FROM att
RIGHT JOIN atg
ON atg.stable_id = att.stable_id
where att.stable_id is null
UNION ALL
-- this bit gets the Leaf nodes which have ontologyterm id
SELECT -- distinct
       att.stable_id as stable_id
     , atg.parent_stable_id
     , atg.provider_label
     , atg.display_name
     , atg.definition
     , COALESCE(atg.ordinal_values, att.ordered_values) as vocabulary
     , atg.display_type display_type
     , atg.hidden
     , atg.display_order
     , atg.display_range_min
     , atg.display_range_max
     , att.range_min
     , att.range_max
     , atg.bin_width_override
     , att.bin_width as bin_width_computed
     , att.mean 
     , att.median
     , att.lower_quartile 
     , att.upper_quartile 
     , atg.is_temporal
     , atg.is_featured
     , atg.is_merge_key
     , atg.impute_zero
     , atg.is_repeated
     , atg.variable_spec_to_impute_zeroes_for
     , atg.has_study_dependent_vocabulary
     , weighting_variable_spec
     , 1 as has_values
     , att.data_type
     , att.distinct_values_count
     , att.is_multi_valued
     , case when (atg.ordinal_values is not null OR lower(atg.force_string_type) = 'yes')
            then 'ordinal'
            else att.data_shape
       end as data_shape
     , COALESCE(att.unit_override, att.unit) as unit
     , atg.scale
     , att.precision
FROM atg, att
where atg.stable_id = att.stable_id
";


  my $dbh = $self->getDbHandle();
  $dbh->do($sql) or die $dbh->errstr;

  # remove duplicate rows
  my $dupq = $dbh->prepare(<<SQL) or die $dbh->errstr;
       select stable_id
       from $tableName
       group by stable_id
       having count(*) > 1
       order by stable_id
SQL

  $dupq->execute();

  # add temporary unique id to this table
  # this will enable us to drop redundant rows
  $dbh->do("ALTER TABLE $tableName ADD COLUMN temp_id SERIAL PRIMARY KEY") or die $dbh->errstr;

  while (my ($stableId) = $dupq->fetchrow_array()) {
    $dbh->do(<<SQL) or die $dbh->errstr;
    WITH cte AS (
        SELECT temp_id,
               stable_id,
               row_number() OVER (PARTITION BY stable_id ORDER BY temp_id) AS rn
        FROM $tableName
        WHERE stable_id = '$stableId'
    )
    DELETE FROM $tableName
    WHERE temp_id IN (SELECT temp_id FROM cte WHERE rn > 1)
SQL
  }

  $dbh->do("ALTER TABLE $tableName DROP COLUMN temp_id") or die $dbh->errstr;
  $dbh->do("ALTER TABLE $tableName add primary key (stable_id)") or die $dbh->errstr;
  $dbh->do("GRANT SELECT ON $tableName TO gus_r");
  return $tableName;
}


sub dropTables {
  my ($self, $extDbRlsSpec) = @_;
  my $dbh = $self->getDbHandle();
  my ($dbName, $dbVersion) = $extDbRlsSpec =~ /(.+)\|(.+)/;

  my $sql1 = "select distinct s.internal_abbrev from ${TERM_SCHEMA}.externaldatabase d, ${TERM_SCHEMA}.externaldatabaserelease r, ${SCHEMA}.study s
 where d.external_database_id = r.external_database_id
and d.name = '$dbName' and r.version = '$dbVersion'
and r.external_database_release_id = s.external_database_release_id";
  $self->log("Looking for tables belonging to $extDbRlsSpec :\n$sql1");
  my $sh = $dbh->prepare($sql1);
  $sh->execute();

  while(my ($s) = $sh->fetchrow_array()) {
    # collection tables have foreign keys - drop them first
    &dropTablesLike($SCHEMA, "COLLECTIONATTRIBUTE_${s}", $dbh);
    &dropTablesLike($SCHEMA, "COLLECTION_${s}", $dbh);
#    &dropTablesLike($SCHEMA, "(ATTRIBUTES|ANCESTORS|ATTRIBUTEGRAPH)_${s}", $dbh);


    &dropTablesLike($SCHEMA, "ATTRIBUTES_${s}", $dbh);
    &dropTablesLike($SCHEMA, "ANCESTORS_${s}", $dbh);
    &dropTablesLike($SCHEMA, "ATTRIBUTEGRAPH_${s}", $dbh);
  }
  $sh->finish();
}


sub makeCollectionsFromWhereSql {
  my ($self, $attributeGraphTableName, $collections) = @_;

  my @collectionsWithTBDVariables;

  my $collectionsWithVariablesString;

  foreach my $stableId (keys %$collections) {
    if($collections->{variables}) {
      foreach my $variable (@{$collections->{variables}}) {
        $collectionsWithVariablesString .= " OR (child.parent_stable_id = '$stableId' and child.stable_id = '$variable')";
      }
    }
    else {
      push @collectionsWithTBDVariables, $stableId;
    }
  }

  my $collectionsWithTBDVariablesString = join(',', map { "'" . $_ . "'" } @collectionsWithTBDVariables);

  my $fromWhereSql = <<"EOF";
FROM   $attributeGraphTableName child, $attributeGraphTableName parent
WHERE child.parent_stable_id = parent.stable_id
and (child.parent_stable_id IN ( '_DUMMY_', $collectionsWithTBDVariablesString)
     $collectionsWithVariablesString
    )
EOF

  return $fromWhereSql;
}

sub maybeCreateCollections {
  my ($self, $attributeGraphTableName, $collections) = @_;

  my $dbh = $self->getDbHandle();

  my ($collectionTableName, $collectionAttributesTableName) = collectionTableNames($attributeGraphTableName);

  my $sth;

  my $fromWhereSql = $self->makeCollectionsFromWhereSql($attributeGraphTableName, $collections);

  $sth = $dbh->prepare("select 1 $fromWhereSql fetch next 1 row only");
  $sth->execute();
  return unless $sth->fetchrow_arrayref();

  $self->log("Creating TABLE: $collectionTableName");
  my $getCollectionsSql = <<"EOF";
SELECT parent.stable_id       as stable_id,
       parent.display_name    as display_name,
       Count(*)               AS num_members,
       Min(child.display_range_min) AS display_range_min,
       Max(child.display_range_max) AS display_range_max,
       Min(child.range_min)         AS range_min,
       Max(child.range_max)         AS range_max,
       child.impute_zero,
       decode(child.data_type, 'integer', 'number', child.data_type) as data_type,
       decode(child.data_shape, 'binary', 'categorical', child.data_shape) AS data_shape,
       child.unit,
       Min(child.PRECISION) AS precision
$fromWhereSql
GROUP BY  parent.stable_id,
          parent.display_name,
          child.impute_zero,
          decode(child.data_type, 'integer', 'number', child.data_type),
          decode(child.data_shape, 'binary', 'categorical', child.data_shape),
          child.unit
EOF

  $dbh->do("CREATE TABLE $collectionTableName as ($getCollectionsSql)") or die $dbh->errstr;
  $dbh->do("CREATE UNIQUE INDEX ${collectionTableName}_uix on $collectionTableName (stable_id)")
    or die "unit, data_type, etc. should be consistent across children - ". $dbh->errstr;
  
  (my $collectionPkName = $collectionTableName) =~ s{${SCHEMA}\.(.*)}{$1_pk};
  $dbh->do("ALTER TABLE $collectionTableName add constraint $collectionPkName primary key (stable_id)") or die $dbh->errstr;

  $dbh->do("GRANT SELECT ON $collectionTableName TO gus_r");
  $dbh->do("ALTER TABLE $collectionTableName add (is_proportion number(1), is_compositional number(1), normalization_method varchar(25), member varchar(25), member_plural varchar(25))") or die $dbh->errstr;

  # update some things from the yaml.
  foreach my $stableId (keys %$collections) {
    if(my $rangeMin = $collections->{$stableId}->{range_min}) {
      $dbh->do("update $collectionTableName set display_range_min = $rangeMin where stable_id = '$stableId'");
    }
    if(my $rangeMax = $collections->{$stableId}->{range_max}) {
      $dbh->do("update $collectionTableName set display_range_max = $rangeMax where stable_id = '$stableId'");
    }

    if(my $isProportion = $collections->{$stableId}->{isProportion}) {
      if(lc($isProportion) eq 'true') {
        $dbh->do("update $collectionTableName set is_proportion = 1 where stable_id = '$stableId'");
      }
      if(lc($isProportion) eq 'false') {
        $dbh->do("update $collectionTableName set is_proportion = 0 where stable_id = '$stableId'");
      }
    }

    if(my $isCompositional = $collections->{$stableId}->{isCompositional}) {
      if(lc($isCompositional) eq 'true') {
        $dbh->do("update $collectionTableName set is_compositional = 1 where stable_id = '$stableId'");
      }
      if(lc($isCompositional) eq 'false') {
        $dbh->do("update $collectionTableName set is_compositional = 0 where stable_id = '$stableId'");
      }
    }

    if(my $normalizationMethod = $collections->{$stableId}->{normalizationMethod}) {
      if($normalizationMethod && lc($normalizationMethod ne 'null')) {
        $dbh->do("update $collectionTableName set normalization_method = '$normalizationMethod' where stable_id = '$stableId'");
      }
    }

    if(my $member = $collections->{$stableId}->{member}) {
      $dbh->do("update $collectionTableName set member = '$member' where stable_id = '$stableId'");

      if(my $memberPlural = $collections->{$stableId}->{memberPlural}) {
        $dbh->do("update $collectionTableName set member_plural = '$memberPlural' where stable_id = '$stableId'");
      }
    }
  }

  $self->log("Creating TABLE: $collectionAttributesTableName");

  my $getCollectionMembersSql = "SELECT child.stable_id as attribute_stable_id, parent.stable_id as collection_stable_id $fromWhereSql ";
  $dbh->do("CREATE TABLE $collectionAttributesTableName as ($getCollectionMembersSql)")  or die $dbh->errstr;
  $dbh->do("CREATE UNIQUE INDEX ${collectionAttributesTableName}_uix on $collectionAttributesTableName (attribute_stable_id)")  or die $dbh->errstr;

  (my $collectionAttributesAfkName = $collectionAttributesTableName) =~ s{${SCHEMA}\.(.*)}{$1_afk};
  $dbh->do("ALTER TABLE $collectionAttributesTableName add constraint $collectionAttributesAfkName foreign key (attribute_stable_id) references $attributeGraphTableName (stable_id)") or die $dbh->errstr;

  (my $collectionAttributesCfkName = $collectionAttributesTableName) =~ s{${SCHEMA}\.(.*)}{$1_cfk};
  $dbh->do("ALTER TABLE $collectionAttributesTableName add constraint $collectionAttributesCfkName foreign key (collection_stable_id) references $collectionTableName (stable_id)") or die $dbh->errstr;
  $dbh->do("GRANT SELECT ON $collectionAttributesTableName TO gus_r");
  return $collectionTableName, $collectionAttributesTableName;
}

sub collectionTableNames {
  my ($attributeGraphTableName) = @_;
  die $attributeGraphTableName unless $attributeGraphTableName =~ m{ATTRIBUTEGRAPH}i;
  (my $collectionTableName = $attributeGraphTableName) =~ s{ATTRIBUTEGRAPH}{COLLECTION}i;
  (my $collectionAttributesTableName = $attributeGraphTableName) =~ s{ATTRIBUTEGRAPH}{COLLECTIONATTRIBUTE}i;
  return $collectionTableName, $collectionAttributesTableName;
}

sub undoTables {}


1;
