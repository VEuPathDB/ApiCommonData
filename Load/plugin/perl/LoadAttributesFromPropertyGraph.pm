package ApiCommonData::Load::Plugin::LoadAttributesFromPropertyGraph;

@ISA = qw(GUS::PluginMgr::Plugin);
use strict;
use GUS::PluginMgr::Plugin;

#use GUS::Model::ApiDB::Attribute;
#use GUS::Model::ApiDB::AttributeValue;

use ApiCommonData::Load::Fifo;
use ApiCommonData::Load::Sqlldr;

use Scalar::Util qw(looks_like_number);

use Time::HiRes qw(gettimeofday);

use JSON;

use Data::Dumper;



my $END_OF_RECORD_DELIMITER = "#EOR#\n";
my $END_OF_COLUMN_DELIMITER = "#EOC#\t";

my $argsDeclaration =[];
my $purposeBrief = 'Read PropertyGraph tables and insert tall table for attribute values and attribute table';
my $purpose = $purposeBrief;

my $tablesAffected =
    [ ['ApiDB::Attribute', ''],
      ['ApiDB::AttributeValue', '']
    ];

my $tablesDependedOn =
    [['ApiDB::PropetyGraph',''],
     ['ApiDB::VertexAttributes',  ''],
     ['ApiDB::EdgeAttributes',  ''],
     ['ApiDB::EdgeType',  ''],
     ['ApiDB::VertexType',  ''],
     ['ApiDB::VertexAttributeUnit',  ''],
     ['ApiDB::EdgeAttributeUnit',  ''],
     ['SRes::OntologyTerm',  ''],
     ['ApiDB::EdgeType',  ''],
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
   fileArg({name           => 'logDir',
            descr          => 'directory where to log sqlldr output',
            reqd           => 1,
            mustExist      => 1,
            format         => '',
            constraintFunc => undef,
            isList         => 0, }),

 stringArg({ name            => 'extDbRlsSpec',
	     descr           => 'ExternalDatabaseSpec for the Property Graph',
	     reqd            => 1,
	     constraintFunc  => undef,
	     isList          => 0 }),

 stringArg({ name            => 'ontologyExtDbRlsSpec',
	     descr           => 'ExternalDatabaseSpec for the Associated Ontology',
	     reqd            => 1,
	     constraintFunc  => undef,
	     isList          => 0 }),

];

sub getActiveForkedProcesses {
  my ($self) = @_;

  return $self->{_active_forked_processes} || [];
}

sub addActiveForkedProcess {
  my ($self, $pid) = @_;

  push @{$self->{_active_forked_processes}}, $pid;
}

sub resetActiveForkedProcesses {
  my ($self) = @_;

  $self->{_active_forked_processes} = [];
}

sub new {
  my ($class) = @_;
  my $self = {};
  bless($self,$class);

  $self->initialize({requiredDbVersion => 4.0,
		     cvsRevision => '$Revision$', # cvs fills this in!
		     name => ref($self),
		     argsDeclaration   => $argsDeclaration,
		     documentation     => $documentation
		    });
  return $self;
}


$| = 1;

sub run {
  my $self  = shift;

  chdir $self->getArg('logDir');

  my $extDbRlsId = $self->getExtDbRlsId($self->getArg('extDbRlsSpec'));


  
  my $propertyGraphs = $self->sqlAsDictionary( Sql  => "select property_graph_id, max_attr_length from apidb.propertygraph where external_database_release_id = $extDbRlsId");

  print Dumper $propertyGraphs;
  exit;

  $self->error("Expected one propertyGraph row.  Found ". scalar @propertyGraphIds) unless(scalar keys %$propertyGraphIds == 1);

  $self->getQueryHandle()->do("alter session set nls_date_format = 'yyyy-mm-dd hh24:mi:ss'") or die $self->getQueryHandle()->errstr;

  my $ontologyTerms = $self->queryForOntologyTerms();

  my $attributeValueCount;
  while(my ($propertyGraphId, $maxAttrLength) = each (%$propertyGraphs)) {
    my $ct = $self->loadAttributeValues($propertyGraphId, $ontologyTerms, $maxAttrLength);
    $attributeValueCount = $attributeValueCount + $ct;
  }

  # TODO: Load values from $ontologyTerms hash into ApiDB.Attribute table

  return "Loaded $attributeValueCount rows into ApiDB.AttributeValue";
}

sub queryForOntologyTerms {
  my ($self) = @_;

  my $extDbRlsId = $self->getExtDbRlsId($self->getArg('ontologyExtDbRlsSpec'));

  my $dbh = $self->getQueryHandle();

  my $sql = "select s.name
                  , s.source_id
                  , s.ontology_term_id
                  , o.name parent_name
                  , o.source_id parent_source_id
                  , o.ontology_term_id parent_ontology_term_id
                  , os.ontology_synonym
                  , os.is_preferred
                  , os.definition
from sres.ontologyrelationship r
   , sres.ontologyterm s
   , sres.ontologyterm o
   , sres.ontologyterm p
   , sres.ontologysynonym os
where r.subject_term_id = s.ontology_term_id
and r.predicate_term_id = p.ontology_term_id
and r.object_term_id = o.ontology_term_id
and p.SOURCE_ID = 'subClassOf'
and s.ontology_term_id = os.ontology_term_id (+)
and r.EXTERNAL_DATABASE_RELEASE_ID = os.EXTERNAL_DATABASE_RELEASE_ID (+)
and r.EXTERNAL_DATABASE_RELEASE_ID = ?";

  my $sh = $dbh->prepare($sql);
  $sh->execute($extDbRlsId);

  my %ontologyTerms;

  while(my $hash = $sh->fetchrow_hashref()) {
    my $sourceId = $hash->{SOURCE_ID};

    $ontologyTerms{$sourceId} = $hash;
  }
  $sh->finish();

  return \%ontologyTerms;
}

sub loadAttributeValues {
  my ($self, $propertyGraphId, $ontologyTerms, $maxAttrLength) = @_;

  my $timestamp = int (gettimeofday * 1000);
  my $fifoName = "apidb_attributevalue_${timestamp}.dat";

  my $fields = $self->fields();

  my $fifo = $self->makeFifo($fields, $fifoName, $maxAttrLength, $maxAttrLength);
  $self->loadAttributesFromVertex($propertyGraphId, $fifo, $ontologyTerms);
  $self->loadAttributesFromIncomingEdge($propertyGraphId, $fifo, $ontologyTerms);

  $fifo->cleanup();
  unlink $fifoName;
}

sub loadAttributes {
  my ($self, $propertyGraphId, $fifo, $ontologyTerms, $sql) = @_;

  my $dbh = $self->getQueryHandle();

  my $fh = $fifo->getFileHandle();

  my $sh = $dbh->prepare($sql, { ora_auto_lob => 0 } );
  $sh->execute($propertyGraphId);

  while(my ($vaId, $vtId, $etId, $lobLocator) = $sh->fetchrow_array()) {
    my $json = $self->readClob($lobLocator);

    my $attsHash = decode_json($json);

    while(my ($ontologySourceId, $value) = each (%$attsHash)) {

      my $ontologyTerm = $ontologyTerms->{$ontologySourceId};
      my $ontologyTermId = $ontologyTerm->{ONTOLOGY_TERM_ID};

      unless($ontologyTermId) {
        $self->error("No ontology_term_id found for:  $ontologySourceId");
      }

      my ($dateValue, $numberValue) = $self->ontologyTermValues($ontologyTerm, $value);

      my @a = ($vaId,
               $vtId,
               undef,
               $ontologyTermId,
               $value,
               $numberValue,
               $dateValue
          );

      print $fh join($END_OF_COLUMN_DELIMITER, @a) . $END_OF_RECORD_DELIMITER;
    }
  }
}


sub ontologyTermValues {
  my ($self, $ontologyTerm, $value) = @_;

  my ($dateValue, $numberValue);

  $ontologyTerm->{_COUNT}++;

  if(looks_like_number($value)) {
    $numberValue = $value;
    $ontologyTerm->{_IS_NUMBER_COUNT}++;
  }
  elsif($value =~ /^\d\d\d\d-\d\d-\d\d$/) {
    $dateValue = $value;
    $ontologyTerm->{_IS_DATE_COUNT}++;
  }
  else {
    my $lcValue = lc $value;
    if($lcValue eq 'yes' || $lcValue eq 'no' || $lcValue eq 'true' || $lcValue eq 'false') {
      $ontologyTerm->{_IS_BOOLEAN_COUNT}++;
    }
    $ontologyTerm->{_IS_STRING_COUNT}++;
  }


  return $dateValue, $numberValue
}


sub readClob {
  my ($self, $lobLocator) = @_;

  my $dbh = $self->getQueryHandle();

  my $chunkSize = $self->{_lob_locator_size};

  unless($chunkSize) {
    $self->{_lob_locator_size} = $dbh->ora_lob_chunk_size($lobLocator);
    $chunkSize = $self->{_lob_locator_size};
  }

  my $offset = 1;   # Offsets start at 1, not 0

  my $output;

  while(1) {
    my $data = $dbh->ora_lob_read($lobLocator, $offset, $chunkSize );
    last unless length $data;
    $output .= $data;
    $offset += $chunkSize;
  }

  return $output;
}


sub loadAttributesFromVertex {
  my ($self, $propertyGraphId, $fifo, $ontologyTerms) = @_;

  my $sql = "select va.vertex_attributes_id, va.vertex_type_id, null as edge_type_id, va.atts from apidb.vertexattributes va, apidb.vertextype vt where to_char(va.atts) != '{}' and vt.vertex_type_id = va.vertex_type_id and vt.property_graph_id = ?";

  $self->loadAttributes($propertyGraphId, $fifo, $ontologyTerms, $sql);
}


sub loadAttributesFromIncomingEdge {
  my ($self, $propertyGraphId, $fifo, $ontologyTerms) = @_;

  my $sql = "select va.vertex_attributes_id, va.vertex_type_id, ea.edge_type_id, ea.atts
from apidb.edgeattributes ea
   , apidb.vertexattributes va
   , apidb.vertextype vt
where to_char(ea.atts) != '{}'
and vt.vertex_type_id = va.vertex_type_id
and va.vertex_attributes_id = ea.out_vertex_id
and vt.property_graph_id = ?
";

  $self->loadAttributes($propertyGraphId, $fifo, $ontologyTerms, $sql);
}

sub fields {
  my ($self, $maxAttrLength) = @_;
  my $database = $self->getDb();
  my $projectId = $database->getDefaultProjectId();
  my $userId = $database->getDefaultUserId();
  my $groupId = $database->getDefaultGroupId();
  my $algInvocationId = $database->getDefaultAlgoInvoId();
  my $userRead = $database->getDefaultUserRead();
  my $userWrite = $database->getDefaultUserWrite();
  my $groupRead = $database->getDefaultGroupRead();
  my $groupWrite = $database->getDefaultGroupWrite();
  my $otherRead = $database->getDefaultOtherRead();
  my $otherWrite = $database->getDefaultOtherWrite();

  my ($sec,$min,$hour,$mday,$mon,$year) = localtime();
  my @abbr = qw(JAN FEB MAR APR MAY JUN JUL AUG SEP OCT NOV DEC);
  my $modDate = sprintf('%2d-%s-%02d', $mday, $abbr[$mon], ($year+1900) % 100);

  my $datatypeMap = {'user_read' => " constant $userRead", 
                     'user_write' => " constant $userWrite", 
                     'group_read' => " constant $groupRead", 
                     'group_write' => " constant $groupWrite", 
                     'other_read' => " constant $otherRead", 
                     'other_write' => " constant $otherWrite", 
                     'row_user_id' => " constant $userId", 
                     'row_group_id' => " constant $groupId", 
                     'row_alg_invocation_id' => " constant $algInvocationId",
                     'row_project_id' => " constant $projectId",
                     'modification_date' => " constant \"$modDate\"",
  };


  my $attributeList = ["vertex_attributes_id",
                       "vertex_type_id",
                       "incoming_edge_type_id",
                       "attribute_ontology_term_id",
                       "string_value",
                       "number_value",
                       "date_value",
                       "attribute_value_id",
      ];

  push @$attributeList, keys %$datatypeMap;

  $datatypeMap->{'attribute_value_id'} = " SEQUENCE(MAX,1)";
  $datatypeMap->{'vertex_attributes_id'} = " CHAR(12)";
  $datatypeMap->{'vertex_type_id'} = "  CHAR(12)";
  $datatypeMap->{'incoming_edge_type_id'} = "  CHAR(12)";
  $datatypeMap->{'attribute_ontology_term_id'} = "  CHAR(10)";
  $datatypeMap->{'string_value'} = "  CHAR($maxAttrLength)";
  $datatypeMap->{'number_value'} = "  CHAR($maxAttrLength)";
  $datatypeMap->{'date_value'} = " DATE 'yyyy-mm-dd hh24:mi:ss'";
  
  my @fields = map { lc($_) . $datatypeMap->{lc($_)}  } @$attributeList;

  return \@fields;
}


sub makeFifo {
  my ($self, $fields, $fifoName, $maxAttrLength) = @_;

  my $eorLiteral = $END_OF_RECORD_DELIMITER;
  $eorLiteral =~ s/\n/\\n/;

  my $eocLiteral = $END_OF_COLUMN_DELIMITER;
  $eocLiteral =~ s/\t/\\t/;

  my $database = $self->getDb();
  my $login       = $database->getLogin();
  my $password    = $database->getPassword();
  my $dbiDsn      = $database->getDSN();
  my ($dbi, $type, $db) = split(':', $dbiDsn);

  my $sqlldr = ApiCommonData::Load::Sqlldr->new({_login => $login,
                                                 _password => $password,
                                                 _database => $db,
                                                 _direct => 0,
                                                 _controlFilePrefix => 'sqlldr_AttributeValue',
                                                 _quiet => 1,
                                                 _infile_name => $fifoName,
                                                 _reenable_disabled_constraints => 1,
                                                 _table_name => "ApiDB.AttributeValue",
                                                 _fields => $fields,
                                                 _rows => 100000
                                                });

  $sqlldr->setLineDelimiter($eorLiteral);
  $sqlldr->setFieldDelimiter($eocLiteral);

  $sqlldr->writeConfigFile();

  my $fifo = ApiCommonData::Load::Fifo->new($fifoName);

  my $sqlldrProcessString = $sqlldr->getCommandLine();

  my $pid = $fifo->attachReader($sqlldrProcessString);
  $self->addActiveForkedProcess($pid);

  my $sqlldrInfileFh = $fifo->attachWriter();

  return $fifo;
}

sub error {
  my ($self, $msg) = @_;
  print STDERR "\nERROR: $msg\n";

  foreach my $pid (@{$self->getActiveForkedProcesses()}) {
    kill(9, $pid); 
  }

  $self->SUPER::error($msg);
}


sub undoTables {
  my ($self) = @_;
  return (
    'ApiDB.Attribute',
    'ApiDB.AttributeValue',
      );
}

1;
