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

  my @entityTypeIds = $self->entityTypeIdsFromExtDbRlsId($extDbRlsId);

  foreach my $entityTypeId (@entityTypeIds) {
    $self->log("Making Tables for Entity Type: $entityTypeId");

    $self->makeTallTable($entityTypeId);
    $self->makeAncestors($extDbRlsId, $entityTypeId);
  }

  return("made some tall tables and some wide tables");
}


sub makeAncestors {
  my ($self, $extDbRlsId, $entityTypeId) = @_;

  my $tableName = "ApiDB.Ancestors_${entityTypeId}";
  my $fieldPrefix = "entity_type_";

  $self->log("Making $tableName");

  my $fields = $self->createAncestorsTable($tableName, $entityTypeId, $fieldPrefix);
  $self->loadAncestorsTable($tableName, $entityTypeId, $fields, $extDbRlsId, $fieldPrefix);
}

sub loadAncestorsTable {
  my ($self, $tableName, $entityTypeId, $entityIds, $extDbRlsId, $fieldPrefix) = @_;

  my $sql = "with f as 
(select p.in_entity_id, i.entity_type_id in_type_id, p.out_entity_id, o.entity_type_id out_type_id
from apidb.processattributes p
   , apidb.entityattributes i
   , apidb.entityattributes o
   , apidb.entitytype et
   , apidb.study s
where p.in_entity_id = i.entity_attributes_id
and p.out_entity_id = o.entity_attributes_id
and i.entity_type_id = et.entity_type_id
and et.study_id = s.study_id
and s.external_database_release_id = $extDbRlsId
)
select connect_by_root out_entity_id,  in_entity_id, in_type_id
from f
start with f.out_type_id = $entityTypeId
connect by prior in_entity_id = out_entity_id
union
select entity_attributes_id, null, null
from apidb.entityattributes where entity_type_id = $entityTypeId";

  my $dbh = $self->getQueryHandle();
  my $sh = $dbh->prepare($sql);
  $sh->execute();

  my $hasFields = scalar @$entityIds > 0;

  my @fields = map { $fieldPrefix . $_ } @$entityIds;

  my $fieldsString = $hasFields ? "entity_id, " . join(",",  @fields) : "entity_id";

  my $qString = $hasFields ? "?, " . join(",", map { "?" } @$entityIds) : "?";

  my $insertSql = "insert into $tableName (${fieldsString})
values ($qString)
";

  my $insertSh = $dbh->prepare($insertSql);

  my %entities;

  my $prevId;
  while(my ($entityId, $parentId, $parentTypeId) = $sh->fetchrow_array()) {
    print STDERR "$prevId\t$entityId\t$parentId\t$parentTypeId\n";

    if($prevId && $prevId != $entityId) {
print STDERR "INSERTING INTO $tableName\n";
      $self->insertAncestorRow($insertSh, $prevId, \%entities, $entityIds);
      %entities = ();
    }

    $entities{$parentTypeId} = $parentId;    
    $prevId = $entityId;
  }

print STDERR "INSERTING LAST ROW $tableName\n";
  $self->insertAncestorRow($insertSh, $prevId, \%entities, $entityIds) if($prevId);
  $insertSh->finish();
}

sub insertAncestorRow {
  my ($self, $sh, $entityId, $ancestorEntityIds, $ancestorEntityTypeIds) = @_;

  my @values = map { $ancestorEntityIds->{$_} } @$ancestorEntityTypeIds;
  $sh->execute($entityId, @values) or die $self->getQueryHandle()->errstr;
}

sub createAncestorsTable {
  my ($self, $tableName, $entityTypeId, $fieldPrefix) = @_;

  my $sql = "select entity_type_id
from apidb.entitytypegraph
start with entity_type_id = ?
connect by prior parent_entity_type_id = entity_type_id";

  my $dbh = $self->getQueryHandle();
  my $sh = $dbh->prepare($sql);
  $sh->execute($entityTypeId);
  
  my @fields;  
  while(my ($id) = $sh->fetchrow_array()) {
    push @fields, $id unless($id == $entityTypeId);
  }

  my $fieldsDef = join("\n", map { $fieldPrefix . $_ . " NUMBER(12)," } @fields);

  my $createTableSql = "CREATE TABLE $tableName (
entity_id         NUMBER(12) NOT NULL,
$fieldsDef
PRIMARY KEY (entity_id)
)";


  # TODO:  Add indexes
  $dbh->do($createTableSql) or die $self->getQueryHandle()->errstr;


  return \@fields;
}



sub entityTypeIdsFromExtDbRlsId {
  my ($self, $extDbRlsId) = @_;

  return $self->sqlAsArray( Sql => "select t.entity_type_id from apidb.study s, apidb.entitytype t where s.external_database_release_id = $extDbRlsId and s.study_id = t.study_id" );
}


sub makeTallTable {
  my ($self, $entityTypeId) = @_;

  my $tableName = "ApiDB.AttributeValue_${entityTypeId}";

  $self->log("Making $tableName");


  my $sql = "CREATE TABLE $tableName as 
SELECT entity_attributes_id as entity_id
     , attribute_ontology_term_id
     , string_value
     , number_value
     , date_value
FROM apidb.attributevalue
WHERE entity_type_id = $entityTypeId
";

  $self->getQueryHandle()->do($sql) or die $self->getQueryHandle()->errstr;
}


sub undoPreprocess {
    my ($self, $dbh, $rowAlgInvocationList) = @_;

    my $rowAlgInvocations = join(',', @{$rowAlgInvocationList});

    my $sh = $dbh->prepare("select p.string_value
from core.algorithmparam p, core.algorithmparamkey k
where p.row_alg_invocation_id in (187)
and p.ALGORITHM_PARAM_KEY_ID = k.ALGORITHM_PARAM_KEY_ID
and k.ALGORITHM_PARAM_KEY = 'extDbRlsSpec'");
                           
    $sh->execute();

    while(my ($extDbRlsSpec) = $sh->fetchrow_array()) {
      if ($extDbRlsSpec =~ /(.+)\|(.+)/) {
        my $dbName = $1;
        my $dbVersion = $2;
        
        my $sh2 = $dbh->prepare("select distinct t.entity_type_id from sres.externaldatabase d, sres.externaldatabaserelease r, apidb.study s, apidb.entitytype t where d.external_database_id = r.external_database_id and d.name = '$dbName' and r.version = '$dbVersion' and r.external_database_release_id = s.external_database_release_id and s.study_id = t.study_id");
        
        $sh2->execute();

        while(my ($id) = $sh2->fetchrow_array()) {
          $self->log("dropping tables apidb.attributevalue_${id} and apidb.ancestors_${id}");

          $dbh->do("drop table apidb.attributevalue_${id}") or die $self->getQueryHandle()->errstr;
          $dbh->do("drop table apidb.ancestors_${id}") or die $self->getQueryHandle()->errstr;
        }

      } 
      else {
        die "Expected ExtDBRlsSpec but found $extDbRlsSpec";
      }
    }
    $sh->finish();
}


sub undoTables {}


1;
