package ApiCommonData::Load::Plugin::LoadDatasetSpecificEntityGraph;

@ISA = qw(GUS::PluginMgr::Plugin ApiCommonData::Load::Plugin::ParameterizedSchema);
use strict;
use warnings;
use GUS::PluginMgr::Plugin;
use ApiCommonData::Load::Plugin::ParameterizedSchema;



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

];

my $SCHEMA = '__SCHEMA__'; # must be replaced with real schema name
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
  my $extDbRlsSpec = $self->getArg('extDbRlsSpec');
  my $extDbRlsId = $self->getExtDbRlsId($extDbRlsSpec);

  $SCHEMA = $self->getArg('schema');

  my $studies = $self->sqlAsDictionary( Sql  => "select study_id, internal_abbrev from ${SCHEMA}.study where external_database_release_id = $extDbRlsId");

  $self->error("Expected one study row.  Found ". scalar keys %$studies) unless(scalar keys %$studies == 1);


  $self->dropTables($extDbRlsSpec);

  my $dbh = $self->getDbHandle();
  $dbh->do("alter session set nls_date_format = 'yyyy-mm-dd hh24:mi:ss'") or die $self->getDbHandle()->errstr;
  $dbh->do("alter session disable parallel query") or die $self->getDbHandle()->errstr;
  $dbh->do("alter session disable parallel dml") or die $self->getDbHandle()->errstr;
  $dbh->do("alter session disable parallel ddl") or die $self->getDbHandle()->errstr;

  my @tables;

  my ($attributeCount, $attributeValueCount, $entityTypeGraphCount);
  foreach my $studyId (keys %$studies) {
    my $studyAbbrev = $studies->{$studyId};
    $self->log("Loading Study: $studyAbbrev");
    my $entityTypeIds = $self->entityTypeIdsFromStudyId($studyId);

    foreach my $entityTypeId (keys %$entityTypeIds) {
      my $entityTypeAbbrev = $entityTypeIds->{$entityTypeId}->{internal_abbrev};
      my $entityTypeOntologyTermId = $entityTypeIds->{$entityTypeId}->{type_id};
      my $internalEntityTypeOntologyTermIds = $entityTypeIds->{$entityTypeId}->{internal_entity_type_ids};

      $self->log("Making Tables for Entity Type $entityTypeAbbrev (ID $entityTypeId)");

      my $tallTableName = $self->createTallTable($entityTypeId, $entityTypeAbbrev, $studyAbbrev);
      my $ancestorsTableName = $self->createAncestorsTable($studyId, $entityTypeId, $entityTypeIds, $studyAbbrev);
      my $attributeGraphTableName = $self->createAttributeGraphTable($entityTypeId, $entityTypeAbbrev, $studyAbbrev, $studyId);
      my $wideTableName;

      $self->createTallTable($entityTypeId, $entityTypeAbbrev, $entityTypeOntologyTermId, $internalEntityTypeOntologyTermIds, $studyAbbrev);
      $self->createAncestorsTable($studyId, $entityTypeId, $entityTypeIds, $studyAbbrev);
      $self->createAttributeGraphTable($entityTypeId, $entityTypeAbbrev, $studyAbbrev, $studyId);

      if ($self->countWideTableColumns($entityTypeId) <= 1000){
        $wideTableName = $self->createWideTable($entityTypeId, $entityTypeAbbrev, $studyAbbrev);
      }
      my ($collectionTableName, $collectionAttributesTableName) = $self->maybeCreateCollectionsForMBioNodes($attributeGraphTableName);
      push @tables, $tallTableName, $ancestorsTableName, $wideTableName, $collectionTableName, $collectionAttributesTableName; 
    }
  }
  my $numTablesMade = grep {$_} @tables;
  return("Created $numTablesMade tables");
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
    $dataType = lc($dataType) eq 'string' ? "VARCHAR2" : uc($dataType);
# TODO Is this the right way to handle longitude?
    $dataType = lc($dataType) eq 'longitude' ? "NUMBER" : uc($dataType);

    # multiValued data always return JSON array
    if($isMultiValued) {
      $dataType = "FORMAT JSON";
      $path = "\$.${stableId}";
    }

    my $string = "${stableId} $dataType PATH '${path}'";
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
sub countWideTableColumns {
  my ($self, $entityTypeId) = @_;
  my ($entityColumnStrings, $processColumnStrings) = $self->makeWideTableColumnString($entityTypeId);
  return 0 + @{$entityColumnStrings} +  @{$processColumnStrings};
}

sub createWideTable {
  my ($self, $entityTypeId, $entityTypeAbbrev, $studyAbbrev) = @_;

  my $tableName = "ATTRIBUTES_${studyAbbrev}_${entityTypeAbbrev}";
  $self->log("Creating TABLE:  $tableName");

  my ($entityColumnStrings, $processColumnStrings) = $self->makeWideTableColumnString($entityTypeId);

  my $entityColumns = join("\n,", map { sprintf(qq/"%s"/, $_) } @$entityColumnStrings);
  my $processColumns = join("\n,", @$processColumnStrings);


  # TODO: use internal entity type _ids here
  my $entitySql = "select ea.stable_id, eaa.*
                   from $SCHEMA.entityattributes ea,
                        json_table(atts, '\$'
                         columns ( $entityColumns )) eaa
                   where ea.entity_type_id = $entityTypeId";

  # TODO: use internal entity type _ids here
  my $processSql = "with process_attributes as (select ea.stable_id, nv.(pa.atts, '{}') as atts
                                                from ${SCHEMA}.processattributes pa,
                                                     (select entity_attributes_id
                                                           , stable_id 
                                                      from ${SCHEMA}.entityattributes 
                                                      where entity_type_id = $entityTypeId) ea
                                                where ea.entity_attributes_id = pa.out_entity_id (+)
                                               )
                    select pa.stable_id, paa.*
                    from process_attributes pa,
                         json_table(atts, '\$'
                          columns ( $processColumns)) paa";

  my @drops;

  my $sql;
  if(scalar @$entityColumnStrings > 0 && scalar @$processColumnStrings > 0) {
    $processSql =~ s{select pa.stable_id}{select pa.stable_id as stable_id_pa};
    $sql = "select e.*, p.* from ($entitySql) e, ($processSql) p where e.stable_id = p.stable_id_pa";
    push @drops, "drop column stable_id_pa";
  }
  elsif(scalar @$entityColumnStrings > 0) {
    $sql = $entitySql;
  }
  elsif(scalar @$processColumnStrings > 0) {
    $sql = $processSql;
  }
  else {
    $sql = "select stable_id from ${SCHEMA}.entityattributes where entity_type_id = $entityTypeId";
  }

  my $dbh = $self->getDbHandle();
  $dbh->do("CREATE TABLE $SCHEMA.$tableName as $sql") or die $self->getDbHandle()->errstr;
  $dbh->do("ALTER TABLE $SCHEMA.$tableName $_") for @drops;
  $dbh->do("GRANT SELECT ON $SCHEMA.$tableName TO gus_r") or die $self->getDbHandle()->errstr;

  # Check for stable_id (entities with no attributes will have none)
  my $fields =  $self->sqlAsDictionary( Sql => "SELECT column_name, DATA_LENGTH FROM all_tab_columns WHERE owner='$SCHEMA'
AND table_name='$tableName'");
  if($fields->{STABLE_ID}){
    $self->log("Creating index on $SCHEMA.$tableName STABLE_ID");
    $dbh->do("CREATE INDEX ATTRIBUTES_${entityTypeId}_IX ON $SCHEMA.$tableName (STABLE_ID) TABLESPACE INDX") or die $dbh->errstr;
  }
  return $tableName;
}


sub createAncestorsTable {
  my ($self, $studyId, $entityTypeId, $entityTypeIds, $studyAbbrev) = @_;

  my $entityTypeAbbrev = $entityTypeIds->{$entityTypeId}->{internal_abbrev};;

  my $tableName = "${SCHEMA}.Ancestors_${studyAbbrev}_${entityTypeAbbrev}";
  my $fieldSuffix = "_stable_id";

  $self->log("Creating TABLE: $tableName");

  my $ancestorEntityTypeIds = $self->createEmptyAncestorsTable($tableName, $entityTypeId, $fieldSuffix, $entityTypeIds);
  $self->populateAncestorsTable($tableName, $entityTypeId, $ancestorEntityTypeIds, $studyId, $fieldSuffix, $entityTypeIds);
  return $tableName;
}

sub populateAncestorsTable {
  my ($self, $tableName, $entityTypeId, $ancestorEntityTypeIds, $studyId, $fieldSuffix, $entityTypeAbbrevs) = @_;

  my $stableIdField = $entityTypeAbbrevs->{$entityTypeId}->{internal_abbrev} . $fieldSuffix;

  my $sql = "select * from (
  with f as 
  (select p.in_entity_id
        , i.stable_id in_stable_id
        , i.entity_type_id in_type_id
        , p.out_entity_id
        , o.entity_type_id out_type_id
        , o.stable_id out_stable_id
  from ${SCHEMA}.processattributes p
     , ${SCHEMA}.entityattributes i
     , ${SCHEMA}.entityattributes o
     , ${SCHEMA}.entitytype et
     , ${SCHEMA}.study s
  where p.in_entity_id = i.entity_attributes_id
  and p.out_entity_id = o.entity_attributes_id
  and i.entity_type_id = et.entity_type_id
  and et.study_id = s.study_id
  and s.study_id = $studyId
  )
  select connect_by_root out_stable_id stable_id,  in_stable_id, in_type_id
  from f
  start with f.out_type_id = $entityTypeId
  connect by prior in_entity_id = out_entity_id
  union
  select stable_id, null, null
  from ${SCHEMA}.entityattributes where entity_type_id = $entityTypeId
) order by stable_id";

  my $dbh = $self->getDbHandle();
  my $sh = $dbh->prepare($sql);
  $sh->execute();

  my $hasFields = scalar @$ancestorEntityTypeIds > 0;

  my @fields = map { $entityTypeAbbrevs->{$_}->{internal_abbrev} . $fieldSuffix } @$ancestorEntityTypeIds;

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

    $entities{$parentTypeId} = $parentId if ($parentId);    
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
  my ($self, $tableName, $entityTypeId, $fieldSuffix, $entityTypeIds) = @_;

  my $stableIdField = $entityTypeIds->{$entityTypeId}->{internal_abbrev} . $fieldSuffix;

  my $sql = "select entity_type_id
from ${SCHEMA}.entitytypegraph
start with entity_type_id = ?
connect by prior parent_id = entity_type_id";

  my $dbh = $self->getDbHandle();
  my $sh = $dbh->prepare($sql);
  $sh->execute($entityTypeId);
  
  my (@fields, @ancestorEntityTypeIds);  
  while(my ($id) = $sh->fetchrow_array()) {
    my $entityTypeAbbrev = $entityTypeIds->{$id}->{internal_abbrev};
    $self->error("Could not determine entityType abbrev for entit_Type_id=$id") unless($id);
    push @fields, $entityTypeAbbrev unless($id == $entityTypeId);
    push @ancestorEntityTypeIds, $id unless($id == $entityTypeId);
  }

  my $fieldsDef = join("\n", map { $_ . $fieldSuffix . " varchar2(200)," } @fields);

  my $createTableSql = "CREATE TABLE $tableName (
$stableIdField         varchar2(200) NOT NULL,
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



sub entityTypeIdsFromStudyId {
  my ($self, $studyId) = @_;

  my $sql = "select t.entity_type_id, t.internal_abbrev, t.type_id, t.entity_type_id from ${SCHEMA}.entitytype t where t.study_id = $studyId";

  my $dbh = $self->getQueryHandle();
  my $sh = $dbh->prepare($sql);
  $sh->execute();

  my $rv = {};
  while(my ($entityTypeId, $internalAbbrev, $typeId, $internalEntityTypeIds) = $sh->fetchrow_array()) {
    $rv->{$entityTypeId}->{internal_abbrev} = $internalAbbrev;
    $rv->{$entityTypeId}->{type_id} = $typeId;
    $rv->{$entityTypeId}->{internal_entity_type_ids} = $entityTypeId;
  }
  $sh->finish();

  return $rv;
}

sub createAttributeGraphTable {
  my ($self, $entityTypeId, $entityTypeAbbrev, $studyAbbrev, $studyId) = @_;

  my $tableName = "${SCHEMA}.AttributeGraph_${studyAbbrev}_${entityTypeAbbrev}";

  $self->log("Creating TABLE:  $tableName");


  # ${SCHEMA}.attribute stable_id could be from sres.ontologyterm, or not
  # if yes, it could also be another term's parent
  # (but not a multifilter - term_type for attributes that have values is default) -- TODO term_type and is_hidden are DEPRECATED, rewrite this comment
  # hence this is only using atg for the parent-child relationship
  # and only adding atg entries which aren't already in
  # careful: att.ontology_term_id doesn't have to exist

  my $sql = "CREATE TABLE $tableName as
  WITH att AS
  (SELECT a.*, t.source_id as unit_stable_id FROM ${SCHEMA}.attribute a, sres.ontologyterm t WHERE a.unit_ontology_term_id = t.ONTOLOGY_TERM_ID (+) and entity_type_id = $entityTypeId)
   , atg AS
  (SELECT atg.*
   FROM ${SCHEMA}.attributegraph atg
   WHERE study_id = $studyId
    START WITH stable_id IN (SELECT DISTINCT stable_id FROM att)
    CONNECT BY prior parent_ontology_term_id = ontology_term_id AND parent_stable_id != 'Thing'
  )
-- this bit gets the internal nodes
SELECT --  distinct
       atg.stable_id
     , atg.parent_stable_id
     , atg.provider_label
     , atg.display_name
     , atg.definition
     , atg.ordinal_values as vocabulary
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
     , 0 as has_values
     , null as data_type
     , null as distinct_values_count
     , null as is_multi_valued
     , null as data_shape
     , null as unit
     , null as precision
FROM atg, att
where atg.stable_id = att.stable_id (+) and att.stable_id is null
UNION ALL
-- this bit gets the Leaf nodes which have ontologyterm id
SELECT -- distinct
       att.stable_id as stable_id
     , atg.parent_stable_id
     , atg.provider_label
     , atg.display_name
     , atg.definition
     , CASE
         WHEN atg.ordinal_values IS NULL
           THEN att.ordered_values
         ELSE atg.ordinal_values
       END as vocabulary
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
     , 1 as has_values
     , att.data_type
     , att.distinct_values_count
     , att.is_multi_valued
     , att.data_shape
     , att.unit
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

  while (my ($stableId) = $dupq->fetchrow_array()) {
    $dbh->do(<<SQL) or die $dbh->errstr;
        delete from $tableName
        where stable_id = '$stableId'
          and rownum < (select count(*)
                        from $tableName
                        where stable_id = '$stableId')
SQL
  }

  $dbh->do("ALTER TABLE $tableName add primary key (stable_id)") or die $dbh->errstr;

  $dbh->do("GRANT SELECT ON $tableName TO gus_r");
  return $tableName;
}


sub createTallTable {
  my ($self, $entityTypeId, $entityTypeAbbrev, $entityTypeOntologyTermId, $internalEntityTypeIds, $studyAbbrev) = @_;

  my $tableName = "${SCHEMA}.AttributeValue_${studyAbbrev}_${entityTypeAbbrev}";

  $self->log("Creating TABLE: $tableName");

  my $sql = <<CREATETABLE;
CREATE TABLE $tableName 
nologging as
SELECT ea.stable_id as ${entityTypeAbbrev}_stable_id
     , av.attribute_stable_id
     , string_value
     , number_value
     , date_value
FROM ${SCHEMA}.attributevalue av
   , ${SCHEMA}.entityattributes ea
   , (SELECT att.stable_id, et.type_id et_type_id, att.unit_ontology_term_id unit_id
      FROM ${SCHEMA}.attribute att, ${SCHEMA}.entitytype et
      WHERE att.entity_type_id = et.entity_type_id 
      AND att.entity_type_id = $entityTypeId) atts
WHERE ea.entity_type_id in ($internalEntityTypeIds)
and av.entity_attributes_id = ea.entity_attributes_id
and av.attribute_stable_id = atts.stable_id
and av.entity_type_ontology_term_id = atts.et_type_id
and nvl(av.unit_ontology_term_id, -1) = nvl(atts.unit_id, -1)
CREATETABLE

  my $dbh = $self->getDbHandle();

  $dbh->do($sql) or die $dbh->errstr;


  $dbh->do("CREATE INDEX attrval_${entityTypeId}_1_ix ON $tableName (attribute_stable_id, ${entityTypeAbbrev}_stable_id) TABLESPACE indx") or die $dbh->errstr;

  $dbh->do("CREATE INDEX attrval_${entityTypeId}_2_ix ON $tableName (attribute_stable_id, string_value, ${entityTypeAbbrev}_stable_id) TABLESPACE indx") or die $dbh->errstr;
  $dbh->do("CREATE INDEX attrval_${entityTypeId}_3_ix ON $tableName (attribute_stable_id, date_value, ${entityTypeAbbrev}_stable_id) TABLESPACE indx") or die $dbh->errstr;
  $dbh->do("CREATE INDEX attrval_${entityTypeId}_4_ix ON $tableName (attribute_stable_id, number_value, ${entityTypeAbbrev}_stable_id) TABLESPACE indx") or die $dbh->errstr;

  $dbh->do("GRANT SELECT ON $tableName TO gus_r");
  return $tableName;
}

sub dropTablesLike {
  my ($self, $pattern) = @_;
  my $dbh = $self->getDbHandle();
  my $sql = sprintf("SELECT table_name FROM all_tables WHERE OWNER='$SCHEMA' AND REGEXP_LIKE(table_name, '%s')", $pattern);
  $self->log("Finding tables to drop with SQL: $sql");
  my $sth = $dbh->prepare($sql);
  $sth->execute();
  while(my ($table_name) = $sth->fetchrow_array()){
    $self->log("dropping table ${SCHEMA}.${table_name}");
    $dbh->do("drop table ${SCHEMA}.${table_name}") or die $dbh->errstr;
  }
  $sth->finish();
}

sub dropTables {
  my ($self, $extDbRlsSpec) = @_;
  my $dbh = $self->getDbHandle();
  my ($dbName, $dbVersion) = $extDbRlsSpec =~ /(.+)\|(.+)/;
  
  my $sql1 = "select distinct s.internal_abbrev from sres.externaldatabase d, sres.externaldatabaserelease r, ${SCHEMA}.study s
 where d.external_database_id = r.external_database_id
and d.name = '$dbName' and r.version = '$dbVersion' 
and r.external_database_release_id = s.external_database_release_id";
  $self->log("Looking for tables belonging to $extDbRlsSpec :\n$sql1");
  my $sh = $dbh->prepare($sql1);
  $sh->execute();

  while(my ($studyAbbrev) = $sh->fetchrow_array()) {

    my $s = uc $studyAbbrev;
    # collection tables have foreign keys - drop them first
    $self->dropTablesLike("COLLECTIONATTRIBUTE_${s}");
    $self->dropTablesLike("COLLECTION_${s}");
    $self->dropTablesLike("(ATTRIBUTES|ATTRIBUTEVALUE|ANCESTORS|ATTRIBUTEGRAPH)_${s}");

    # Some tables do not exist, get a list and drop them
    my $sql = sprintf("SELECT table_name FROM all_tables WHERE OWNER=upper('$SCHEMA') AND REGEXP_LIKE(table_name, '(ATTRIBUTES|ATTRIBUTEVALUE|ANCESTORS|ATTRIBUTEGRAPH)_%s')",uc(${studyAbbrev}));
    $self->log("Finding tables to drop with SQL: $sql");
    my $sh2 = $dbh->prepare($sql);
    $sh2->execute();
    while(my ($table_name) = $sh2->fetchrow_array()){
      $self->log("dropping table ${SCHEMA}.${table_name}");
      $dbh->do("drop table ${SCHEMA}.${table_name}") or die $dbh->errstr;
    }
    $sh2->finish();

  }
  $sh->finish();
}

sub maybeCreateCollectionsForMBioNodes {

  my ($self, $attributeGraphTableName) = @_;
  my $dbh = $self->getDbHandle();


  my ($collectionTableName, $collectionAttributesTableName) = collectionTableNames($attributeGraphTableName);

  my $sth;

  my $fromWhereSql = <<"EOF";
FROM   $attributeGraphTableName child, $attributeGraphTableName parent
WHERE  child.parent_stable_id IN ( 'EUPATH_0009247', 'EUPATH_0009248',
                             'EUPATH_0009249',
                             'EUPATH_0009252', 'EUPATH_0009253',
                             'EUPATH_0009254', 'EUPATH_0009255',
                             'EUPATH_0009256', 'EUPATH_0009257',
                             'EUPATH_0009269')
and child.parent_stable_id = parent.stable_id
EOF

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
       child.data_type,
       child.data_shape,
       child.unit,
       child.precision
$fromWhereSql
GROUP BY  parent.stable_id,
          parent.display_name,
          child.impute_zero,
          child.data_type,
          child.data_shape,
          child.unit,
          child.precision
EOF

  $dbh->do("CREATE TABLE $collectionTableName as ($getCollectionsSql)") or die $dbh->errstr;
  $dbh->do("CREATE UNIQUE INDEX ${collectionTableName}_uix on $collectionTableName (stable_id)")
    or die "unit, data_type, etc. should be consistent across children - ". $dbh->errstr;
  
  (my $collectionPkName = $collectionTableName) =~ s{${SCHEMA}\.(.*)}{$1_pk};
  $dbh->do("ALTER TABLE $collectionTableName add constraint $collectionPkName primary key (stable_id)") or die $dbh->errstr;

  $dbh->do("GRANT SELECT ON $collectionTableName TO gus_r");

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
