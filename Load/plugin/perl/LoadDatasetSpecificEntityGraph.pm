package ApiCommonData::Load::Plugin::LoadDatasetSpecificEntityGraph;

@ISA = qw(GUS::PluginMgr::Plugin);
use strict;
use GUS::PluginMgr::Plugin;

use Data::Dumper;

my $purposeBrief = 'Read Study tables and insert tall table for attribute values and attribute table';
my $purpose = $purposeBrief;

my $tablesAffected =
    [ ['ApiDB::Attribute', ''],
      ['ApiDB::AttributeValue', '']
    ];

my $tablesDependedOn =
    [['ApiDB::Study',''],
     ['ApiDB::AttributeValue',  ''],
     ['ApiDB::EntityType',  ''],
     ['ApiDB::EntityAttributes',  ''],
     ['ApiDB::ProcessAttributes',  ''],
    ];

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

];


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

  return $self;
}

# ======================================================================

sub run {
  my ($self) = @_;

  my $extDbRlsId = $self->getExtDbRlsId($self->getArg('extDbRlsSpec'));

  my $studies = $self->sqlAsDictionary( Sql  => "select study_id, internal_abbrev from apidb.study where external_database_release_id = $extDbRlsId");

  $self->error("Expected one study row.  Found ". scalar keys %$studies) unless(scalar keys %$studies == 1);

  $self->getDbHandle()->do("alter session set nls_date_format = 'yyyy-mm-dd hh24:mi:ss'") or die $self->getDbHandle()->errstr;

  my ($attributeCount, $attributeValueCount, $entityTypeGraphCount);
  foreach my $studyId (keys %$studies) {
    my $studyAbbrev = $studies->{$studyId};
    $self->log("Loading Study: $studyAbbrev");
    my $entityTypeIds = $self->entityTypeIdsFromStudyId($studyId);

    foreach my $entityTypeId (keys %$entityTypeIds) {
      my $entityTypeAbbrev = $entityTypeIds->{$entityTypeId};

      $self->log("Making Tables for Entity Type: $entityTypeId");

      $self->createTallTable($entityTypeId, $entityTypeAbbrev, $studyAbbrev);
      $self->createAncestorsTable($studyId, $entityTypeId, $entityTypeIds, $studyAbbrev);
      $self->createAttributeGraphTable($entityTypeId, $entityTypeAbbrev, $studyAbbrev);

    }
  }

  return("made some tall tables and some wide tables");
}


sub createAncestorsTable {
  my ($self, $studyId, $entityTypeId, $entityTypeIds, $studyAbbrev) = @_;

  my $entityTypeAbbrev = $entityTypeIds->{$entityTypeId};

  my $tableName = "ApiDB.Ancestors_${studyAbbrev}_${entityTypeAbbrev}";
  my $fieldSuffix = "_stable_id";

  $self->log("Creating TABLE $tableName");

  my $ancestorEntityTypeIds = $self->createEmptyAncestorsTable($tableName, $entityTypeId, $fieldSuffix, $entityTypeIds);
  $self->populateAncestorsTable($tableName, $entityTypeId, $ancestorEntityTypeIds, $studyId, $fieldSuffix, $entityTypeIds);
}

sub populateAncestorsTable {
  my ($self, $tableName, $entityTypeId, $ancestorEntityTypeIds, $studyId, $fieldSuffix, $entityTypeAbbrevs) = @_;

  my $stableIdField = $entityTypeAbbrevs->{$entityTypeId} . $fieldSuffix;

  my $sql = "with f as 
(select p.in_entity_id
      , i.stable_id in_stable_id
      , i.entity_type_id in_type_id
      , p.out_entity_id
      , o.entity_type_id out_type_id
      , o.stable_id out_stable_id
from apidb.processattributes p
   , apidb.entityattributes i
   , apidb.entityattributes o
   , apidb.entitytype et
   , apidb.study s
where p.in_entity_id = i.entity_attributes_id
and p.out_entity_id = o.entity_attributes_id
and i.entity_type_id = et.entity_type_id
and et.study_id = s.study_id
and s.study_id = $studyId
)
select connect_by_root out_stable_id,  in_stable_id, in_type_id
from f
start with f.out_type_id = $entityTypeId
connect by prior in_entity_id = out_entity_id
union
select stable_id, null, null
from apidb.entityattributes where entity_type_id = $entityTypeId";

  my $dbh = $self->getDbHandle();
  my $sh = $dbh->prepare($sql);
  $sh->execute();

  my $hasFields = scalar @$ancestorEntityTypeIds > 0;

  my @fields = map { $entityTypeAbbrevs->{$_} . $fieldSuffix } @$ancestorEntityTypeIds;

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

    $entities{$parentTypeId} = $parentId;    
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

  my $stableIdField = $entityTypeIds->{$entityTypeId} . $fieldSuffix;

  my $sql = "select entity_type_id
from apidb.entitytypegraph
start with entity_type_id = ?
connect by prior parent_id = entity_type_id";

  my $dbh = $self->getDbHandle();
  my $sh = $dbh->prepare($sql);
  $sh->execute($entityTypeId);
  
  my (@fields, @ancestorEntityTypeIds);  
  while(my ($id) = $sh->fetchrow_array()) {
    my $entityTypeAbbrev = $entityTypeIds->{$id};
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

  # TODO:  Add indexes
  $dbh->do($createTableSql) or die $self->getDbHandle()->errstr;

  return \@ancestorEntityTypeIds;
}



sub entityTypeIdsFromStudyId {
  my ($self, $studyId) = @_;

  return $self->sqlAsDictionary( Sql => "select t.entity_type_id, t.internal_abbrev from apidb.entitytype t where t.study_id = $studyId" );
}

sub createAttributeGraphTable {
  my ($self, $entityTypeId, $entityTypeAbbrev, $studyAbbrev) = @_;

  my $tableName = "ApiDB.AttributeGraph_${studyAbbrev}_${entityTypeAbbrev}";

  $self->log("Creating TABLE:  $tableName");

  my $sql = "CREATE TABLE $tableName as 
  WITH att AS
  (SELECT * FROM apidb.attribute WHERE entity_type_id = $entityTypeId)
   , atg AS
  (SELECT atg.*
   FROM apidb.attributegraph atg
   WHERE study_id = 1
    START WITH ontology_term_id IN (SELECT DISTINCT ontology_term_id FROM att)
    CONNECT BY prior parent_ontology_term_id = ontology_term_id AND parent_stable_id != 'Thing'
  )
SELECT atg.ontology_term_id
     , atg.stable_id
     , atg.parent_stable_id
     , atg.provider_label
     , atg.display_name
     , atg.term_type
     , case when att.data_type is null then 0 else 1 end as has_value
     , att.data_type
     , att.value_count_per_entity
     , att.data_shape
     , att.unit
     , att.precision
FROM atg, att
where atg.ontology_term_id = att.ontology_term_id (+)
";

  $self->getDbHandle()->do($sql) or die $self->getDbHandle()->errstr;
}


sub createTallTable {
  my ($self, $entityTypeId, $entityTypeAbbrev, $studyAbbrev) = @_;

  my $tableName = "ApiDB.AttributeValue_${studyAbbrev}_${entityTypeAbbrev}";

  $self->log("Creating TABLE:  $tableName");

  my $sql = "CREATE TABLE $tableName as 
SELECT ea.stable_id as ${entityTypeAbbrev}_stable_id
     , ot.source_id as attribute_stable_id
     , string_value
     , number_value
     , date_value
FROM apidb.attributevalue av, apidb.entityattributes ea, sres.ontologyterm ot
WHERE av.entity_type_id = $entityTypeId
and av.entity_attributes_id = ea.entity_attributes_id
and av.attribute_ontology_term_id = ot.ontology_term_id
";

  $self->getDbHandle()->do($sql) or die $self->getDbHandle()->errstr;
}


sub undoPreprocess {
    my ($self, $dbh, $rowAlgInvocationList) = @_;

    my $rowAlgInvocations = join(',', @{$rowAlgInvocationList});

    my $sh = $dbh->prepare("select p.string_value
from core.algorithmparam p, core.algorithmparamkey k
where p.row_alg_invocation_id in ($rowAlgInvocations)
and p.ALGORITHM_PARAM_KEY_ID = k.ALGORITHM_PARAM_KEY_ID
and k.ALGORITHM_PARAM_KEY = 'extDbRlsSpec'");

    $sh->execute();

    while(my ($extDbRlsSpec) = $sh->fetchrow_array()) {
      my ($dbName, $dbVersion) = $extDbRlsSpec =~ /(.+)\|(.+)/;
      die "Failed to extract dbName and dbVersion from ExtDBRlsSpec found: $extDbRlsSpec"
        unless $dbName && $dbVersion;
      
      my $sh2 = $dbh->prepare("select distinct t.internal_abbrev, s.internal_abbrev from sres.externaldatabase d, sres.externaldatabaserelease r, apidb.study s, apidb.entitytype t where d.external_database_id = r.external_database_id and d.name = '$dbName' and r.version = '$dbVersion' and r.external_database_release_id = s.external_database_release_id and s.study_id = t.study_id");
        
      $sh2->execute();

      while(my ($entityTypeAbbrev, $studyAbbrev) = $sh2->fetchrow_array()) {

        $self->log("dropping tables apidb.attributevalue_${studyAbbrev}_${entityTypeAbbrev}, apidb.attributegraph_${studyAbbrev}_${entityTypeAbbrev} and apidb.ancestors_${studyAbbrev}_${entityTypeAbbrev}");

        $dbh->do("drop table apidb.attributevalue_${studyAbbrev}_${entityTypeAbbrev}") or die $self->getDbHandle()->errstr;
        $dbh->do("drop table apidb.ancestors_${studyAbbrev}_${entityTypeAbbrev}") or die $self->getDbHandle()->errstr;
        $dbh->do("drop table apidb.attributegraph_${studyAbbrev}_${entityTypeAbbrev}") or die $self->getDbHandle()->errstr;
      }
    }
    $sh->finish();
}


sub undoTables {}


1;
