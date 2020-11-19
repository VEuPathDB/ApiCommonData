package ApiCommonData::Load::Plugin::InsertPropertyGraph;

@ISA = qw(GUS::PluginMgr::Plugin);
use GUS::PluginMgr::Plugin;
use strict;

use CBIL::ISA::Investigation;
use CBIL::ISA::InvestigationSimple;

use File::Basename;

use GUS::Model::SRes::OntologyTerm;

use GUS::Model::ApiDB::PropertyGraph;
use GUS::Model::ApiDB::VertexAttributes;
use GUS::Model::ApiDB::VertexType;
use GUS::Model::ApiDB::AttributeUnit;

use GUS::Model::ApiDB::EdgeAttributes;
use GUS::Model::ApiDB::EdgeType;
use GUS::Model::ApiDB::EdgeTypeComponent;

use CBIL::ISA::Investigation;
use CBIL::ISA::InvestigationSimple;

use Scalar::Util qw(blessed);
use POSIX qw/strftime/;

use JSON;

use Data::Dumper;

my $argsDeclaration =
  [

   fileArg({name           => 'metaDataRoot',
            descr          => 'directory where to find directories of isa tab files',
            reqd           => 1,
        mustExist      => 1,
        format         => '',
            constraintFunc => undef,
            isList         => 0, }),

   stringArg({name           => 'investigationBaseName',
            descr          => 'name of the investigation file',
            reqd           => 1,
            constraintFunc => undef,
            isList         => 0, }),


   stringArg({name           => 'investigationSubset',
            descr          => 'Skip directory unless it is one of these',
            reqd           => 0,
            constraintFunc => undef,
            isList         => 1, }),

stringArg({name           => 'extDbRlsSpec',
            descr          => 'external database release spec',
            reqd           => 1,
            constraintFunc => undef,
            isList         => 0, }),



   booleanArg({name => 'isSimpleConfiguration',
          descr => 'if true, use CBIL::ISA::InvestigationSimple',
          reqd => 1,
          constraintFunc => undef,
          isList => 0,
         }),


   booleanArg({name => 'skipDatasetLookup',
          descr => 'do not require existing nodes for datasets listed in isa files',
          reqd => 1,
          constraintFunc => undef,
          isList => 0,
         }),



   fileArg({name           => 'ontologyMappingFile',
            descr          => 'For InvestigationSimple Reader',
            reqd           => 0,
        mustExist      => 1,
        format         => '',
            constraintFunc => undef,
            isList         => 0, }),

   fileArg({name           => 'valueMappingFile',
            descr          => 'For InvestigationSimple Reader',
            reqd           => 0,
        mustExist      => 1,
        format         => '',
            constraintFunc => undef,
            isList         => 0, }),


   fileArg({name           => 'dateObfuscationFile',
            descr          => 'For InvestigationSimple Reader',
            reqd           => 0,
        mustExist      => 1,
        format         => '',
            constraintFunc => undef,
            isList         => 0, }),


   stringArg({name           => 'ontologyMappingOverrideFileBaseName',
            descr          => 'For InvestigationSimple Reader',
            reqd           => 0,
            constraintFunc => undef,
            isList         => 0, }),


  ];

my $documentation = { purpose          => "",
                      purposeBrief     => "",
                      notes            => "",
                      tablesAffected   => "",
                      tablesDependedOn => "",
                      howToRestart     => "",
                      failureCases     => "" };

# ----------------------------------------------------------------------

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
  my $metaDataRoot = $self->getArg('metaDataRoot');
  my $investigationBaseName = $self->getArg('investigationBaseName');

  my @investigationFiles;

  my $investigationSubset = $self->getArg('investigationSubset');
  if($investigationSubset) {
    @investigationFiles = map { "$metaDataRoot/$_/$investigationBaseName" } @$investigationSubset;
  }
  else {
    @investigationFiles = glob "$metaDataRoot/*/$investigationBaseName";
  }

  my $investigationCount;
  foreach my $investigationFile (@investigationFiles) {
    my $dirname = dirname $investigationFile;
    $self->log("Processing ISA Directory:  $dirname");

    # clear out the protocol app node hash
    $self->{_NODE_MAP} = {};

    my $investigation;
    if($self->getArg('isSimpleConfiguration')) {
      my $valueMappingFile = $self->getArg('valueMappingFile');
      my $dateObfuscationFile = $self->getArg('dateObfuscationFile');

      my $ontologyMappingFile = $self->getArg('ontologyMappingFile');
      my $ontologyMappingOverrideFileBaseName = $self->getArg('ontologyMappingOverrideFileBaseName');
      my $overrideFile = $dirname . "/" . $ontologyMappingOverrideFileBaseName if($ontologyMappingOverrideFileBaseName);

      $investigation = CBIL::ISA::InvestigationSimple->new($investigationFile, $ontologyMappingFile, $overrideFile, $valueMappingFile, undef, undef, $dateObfuscationFile);
    }
    else {
      $investigation = CBIL::ISA::Investigation->new($investigationBaseName, $dirname, "\t");
    }

    eval {
    $investigation->parseInvestigation();
    };
    if($@) {
      $self->logOrError($@);
      next;
    }

    my $investigationId = $investigation->getIdentifier();
    my $studies = $investigation->getStudies();

    foreach my $study (@$studies) {
      while($study->hasMoreData()) {
        eval {
          $investigation->parseStudy($study);
          $investigation->dealWithAllOntologies();
        };
        if($@) {
          $self->logOrError($@);
          next;
        }

        $self->checkEdgeTypesAndSetIds($study->getProtocols());

        my $iOntologyTermAccessions = $investigation->getOntologyAccessionsHash();

        $self->checkOntologyTermsAndSetIds($iOntologyTermAccessions);

        $self->checkMaterialEntitiesHaveMaterialType($study->getNodes());

        $self->loadPropertyGraph($study);
      }

      # clear out the protocol app node hash
      $self->{_NODE_MAP} = {};
    }

    $investigationCount++;
  }

  my $errorCount = $self->{_has_errors};
  if($errorCount) {
    $self->error("FOUND $errorCount ERRORS!");
  }

  $self->logRowsInserted() if($self->getArg('commit'));

  return("Processed $investigationCount Investigations.");
}

sub countLines {
  my ($self, $charFile) = @_;
  open(FILE, "<", $charFile);
  my $count += tr/\n/\n/ while sysread(FILE, $_, 2 ** 16);
  close(FILE);
  return $count;
}



sub checkMaterialEntitiesHaveMaterialType {
  my ($self, $nodes) = @_;

  foreach my $node (@$nodes) {
    my $value = $node->getValue();
    if($node->hasAttribute("Material Type")) {
      my $materialTypeOntologyTerm = $node->getMaterialType();
      $self->logOrError("Material Entitiy $value is required to have a [Material Type]");
    }
  }
}

sub checkEdgeTypesAndSetIds {
  my ($self, $protocols) = @_;

  my $sql = "select name, edge_type_id from apidb.edgetype";

  my $dbh = $self->getQueryHandle();
  my $sh = $dbh->prepare($sql);
  $sh->execute();
  my %edgeTypes;
  while(my ($edgeType, $edgeTypeId) = $sh->fetchrow_array()) {
    $edgeTypes{$edgeType} = $edgeTypeId;
  }
  $sh->finish();

  foreach my $protocol (@$protocols) {
    my $protocolName = $protocol->getProtocolName();

    if($edgeTypes{$protocolName}) {
      $protocol->{_EDGE_TYPE_ID} = $edgeTypes{$protocolName};
    }
    else {
      $self->log("WARNING:  Protocol [$protocolName] Not found in the database") ;
    }
  }
}

sub loadPropertyGraph {
  my ($self, $study) = @_;
  my $extDbRlsSpec = $self->getArg('extDbRlsSpec');
  my $extDbRlsId = $self->getExtDbRlsId($extDbRlsSpec);

  my $identifier = $study->getIdentifier();
  my $description = $study->getDescription();

  my $gusPropertyGraph = GUS::Model::ApiDB::PropertyGraph->new({name => $identifier, external_database_release_id=>$extDbRlsId});
  $gusPropertyGraph->submit() unless ($gusPropertyGraph->retrieveFromDB());

  my $nodeNameToIdMap = $self->loadNodes($study->getNodes(), $gusPropertyGraph);
  my $edgeTypeNamesToIdMap = $self->loadEdgeTypes($study->getProtocols());

  $self->loadEdges($study->getEdges, $nodeNameToIdMap, $edgeTypeNamesToIdMap);

  if($self->{_max_attr_value} > $gusPropertyGraph->getMaxAttrLength()) {
    $gusPropertyGraph->setMaxAttrLength($self->{_max_attr_value});
    $gusPropertyGraph->submit();
  }
}


sub getVertexTypeId {
  my ($self, $node, $gusPropertyGraphId) = @_;

  my $isaClassName = ref($node);
  my($isaType) = $isaClassName =~ /\:\:(\w+)$/;

  my $materialType = $node->hasAttribute("MaterialType") ? $node->getMaterialType()->getTerm() : 'NA';

  my $mtKey = $materialType . "_" . $isaType;

  if($self->{_VERTEX_TYPE_IDS}->{$mtKey}) {
    return $self->{_VERTEX_TYPE_IDS}->{$mtKey};
  }

  my $vertexType = GUS::Model::ApiDB::VertexType->new();
  $vertexType->setPropertyGraphId($gusPropertyGraphId);
  $vertexType->setIsaType($isaType);

  if($node->hasAttribute("MaterialType")) {
    my $materialTypeOntologyTerm = $node->getMaterialType();
    my $gusOntologyTerm = $self->getOntologyTermGusObj($materialTypeOntologyTerm, 0);
    $vertexType->setTypeId($gusOntologyTerm->getId());
    $vertexType->setName($gusOntologyTerm->getName());
  }
  else {
    $vertexType->setName($isaType);
  }

  $vertexType->submit(undef, 1);

  my $id = $vertexType->getId();

  $self->{_VERTEX_TYPE_IDS}->{$mtKey} = $id;

  return $id;
}


sub addAttributeUnit {
  my ($self, $vertexTypeId, $attrOntologyTermId, $unitOntologyTermId) = @_;

  if($self->{_attribute_units}->{$vertexTypeId}->{$attrOntologyTermId}->{$unitOntologyTermId}) {
    return;
  }

  $self->{_attribute_units}->{$vertexTypeId}->{$attrOntologyTermId}->{$unitOntologyTermId} = 1;
  

  if(keys %{$self->{_attribute_units}->{$vertexTypeId}->{$attrOntologyTermId}} > 1) {
    $self->error("Multiple Units found for VertexTypeId=$vertexTypeId and AttributeOntologyTermId=$attrOntologyTermId");
  }

  
  my $attributeValue = GUS::Model::ApiDB::AttributeUnit->new({vertex_type_id => $vertexTypeId, 
                                                              attr_ontology_term_id => $attrOntologyTermId,
                                                              unit_ontology_term_id => $unitOntologyTermId
                                                             });

  $attributeValue->submit(undef, 1);
}


sub loadNodes {
  my ($self, $nodes, $gusPropertyGraph) = @_;

  my %rv;

  my $gusPropertyGraphId = $gusPropertyGraph->getId();

  my $nodeCount = 0;
  $self->getDb()->manageTransaction(0, 'begin');

  foreach my $node (@$nodes) {
    my $charsForLoader = {};

    my $vertex = GUS::Model::ApiDB::VertexAttributes->new({name => $node->getValue()});

    my $vertexTypeId = $self->getVertexTypeId($node, $gusPropertyGraphId);
    $vertex->setVertexTypeId($vertexTypeId);

    if ($node->hasAttribute("Characteristic")) {
      my $characteristics = $node->getCharacteristics();
      foreach my $characteristic (@$characteristics) {

        my $charQualifierOntologyTerm = $self->getOntologyTermGusObj($characteristic, 1);
        my $charQualifierSourceId = $charQualifierOntologyTerm->getSourceId();

        if($characteristic->getUnit()) {
          my $unitOntologyTerm = $self->getOntologyTermGusObj($characteristic->getUnit(), 0);
          $self->addAttributeUnit($vertexTypeId, $charQualifierOntologyTerm->getId(), $unitOntologyTerm->getId());
         }

        my ($charValue);

        if(lc $characteristic->getTermSourceRef() eq 'ncbitaxon') {
          my $value = $self->{_ontology_term_to_names}->{$characteristic->getTermSourceRef()}->{$characteristic->getTermAccessionNumber()};
          $charValue = $value;
        }
        elsif($characteristic->getTermAccessionNumber() && $characteristic->getTermSourceRef()) {
          my $valueOntologyTerm = $self->getOntologyTermGusObj($characteristic, 0);
          $charValue = $valueOntologyTerm->getName();
        }
        else {
              $charValue = $characteristic->getTerm();
        }

        $charValue =~ s/\r//;

        if($charsForLoader->{$charQualifierSourceId}) {
          $self->error("Qualifier $charQualifierSourceId can only be used one time for node " . $vertex->getName());
        }
        $charsForLoader->{$charQualifierSourceId} = $charValue;

        if(length $charValue > $self->{_max_attr_value}) {
          $self->{_max_attr_value} = length $charValue;
        }

      }
    }

    my $atts = encode_json($charsForLoader);
    $vertex->setAtts($atts);

    $vertex->submit(undef, 1);

    # keep the cache up to date as we add new nodes
    $self->{_NODE_MAP}->{$vertex->getName()} = $vertex->getId();

    $rv{$vertex->getName()} = [$vertex->getId(), $vertex->getVertexTypeId()];

    $self->undefPointerCache();

    if($nodeCount++ % 1000 == 0) {
      $self->getDb()->manageTransaction(0, 'commit');
      $self->getDb()->manageTransaction(0, 'begin');
    }
  }

  $self->getDb()->manageTransaction(0, 'commit');

  return \%rv;
}

sub getOntologyTermGusObj {
    my ($self, $ontologyTerm, $useQualifier) = @_;

    my $ontologyTermTerm = $ontologyTerm->getTerm();
    my $ontologyTermClass = blessed($ontologyTerm);
    my $ontologyTermAccessionNumber = $ontologyTerm->getTermAccessionNumber();
    my $ontologyTermSourceRef = $ontologyTerm->getTermSourceRef();

    $self->logDebug("OntologyTerm=$ontologyTermTerm\tClass=$ontologyTermClass\tAccession=$ontologyTermAccessionNumber\tSource=$ontologyTermSourceRef\n");

    my $ontologyTermId;
    if(($ontologyTermClass eq 'CBIL::ISA::StudyAssayEntity::ParameterValue' || $ontologyTermClass eq 'CBIL::ISA::StudyAssayEntity::Characteristic') && $useQualifier) {
      my $qualifier = $ontologyTerm->getQualifier();
      $ontologyTermId = $self->{_ontology_term_to_identifiers}->{QUALIFIER}->{$qualifier};
      $self->userError("No ontology entry found for qualifier [$qualifier]") unless($ontologyTermId);
    }
    elsif($ontologyTermAccessionNumber && $ontologyTermSourceRef) {
      $ontologyTermId = $self->{_ontology_term_to_identifiers}->{$ontologyTermSourceRef}->{$ontologyTermAccessionNumber};
      $self->userError("No ontology entry found for $ontologyTermSourceRef and $ontologyTermAccessionNumber") unless($ontologyTermId);
    }
    else {
      $self->logOrError("OntologyTerm of class $ontologyTermClass and value [$ontologyTermTerm] must provide accession&source OR a qualifier in the case of Characteristics must map to an ontologyterm");
    }


    if(my $gusObj = $self->{_gus_ontologyterm_objects}->{$ontologyTermId}) {
      return $gusObj;
    }

    my $gusOntologyTerm = GUS::Model::SRes::OntologyTerm->new({ontology_term_id => $ontologyTermId});
    unless($gusOntologyTerm->retrieveFromDB()) {
      $self->error("ERROR:  Found TaxonID ($ontologyTermId).  Was expecting OntologyTerm ID");
    }

    $self->{_gus_ontologyterm_objects}->{$ontologyTermId} = $gusOntologyTerm;
    return $gusOntologyTerm;
}


sub loadEdgeTypes {
  my ($self, $protocols) = @_;

  my $pNameToId = {};

  foreach my $protocol (@$protocols) {
    my $edgeTypeId = $protocol->{_EDGE_TYPE_ID};

    my $gusEdgeType;

    my $protocolName = $protocol->getProtocolName();

    unless($edgeTypeId) {
      my $protocolDescription = $protocol->getProtocolDescription();
      $gusEdgeType = GUS::Model::ApiDB::EdgeType->new({name => $protocolName, description => $protocolDescription});

      if($protocol->getProtocolType()) {
        my $gusProtocolType = $self->getOntologyTermGusObj($protocol->getProtocolType(), 0);
        $gusEdgeType->setParent($gusProtocolType);
      }

      $self->log("Adding EdgeType $protocolName to the database");
      $gusEdgeType->submit();
      $edgeTypeId = $gusEdgeType->getId();
    }

    $pNameToId->{$protocolName} = $edgeTypeId;
  }

  return $pNameToId;
}


sub getOrMakeEdgeTypeId {
  my ($self, $edge, $edgeTypeNamesToIdMap) = @_;

  my $protocolCount = scalar @{$edge->getProtocolApplications()};
  my $protocolName;

  my @seriesProtocolNames;
  if($protocolCount > 1) {
    @seriesProtocolNames = map { $_->getProtocol()->getProtocolName() } @{$edge->getProtocolApplications()};
    # check they have already been loaded and make a name for the series
    my @ok = grep { $edgeTypeNamesToIdMap->{$_} } @seriesProtocolNames;
    $self->error("ERROR: one or more protocolSeries component protocol not already loaded (@seriesProtocolNames)") unless (@ok == @seriesProtocolNames);
    $protocolName = join("; ", @seriesProtocolNames);
  }
  else {
    $protocolName = $edge->getProtocolApplications()->[0]->getProtocol()->getProtocolName();
  }
  
  my $gusEdgeTypeId = $edgeTypeNamesToIdMap->{$protocolName};

  unless($gusEdgeTypeId) {
    my $gusEdgeType = GUS::Model::ApiDB::EdgeType->new({name => $protocolName});
    $gusEdgeType->submit(undef, 1);

    $gusEdgeTypeId = $gusEdgeType->getId();

    $edgeTypeNamesToIdMap->{$protocolName} = $gusEdgeTypeId;
    for (my $i=0; $i<@seriesProtocolNames; $i++) {
      my $edgeTypeComponent = GUS::Model::ApiDB::EdgeTypeComponent->new({order_num => $i+1});
      $edgeTypeComponent->setEdgeTypeId($gusEdgeTypeId);
      $edgeTypeComponent->setComponentId($edgeTypeNamesToIdMap->{$seriesProtocolNames[$i]});
      $edgeTypeComponent->submit(undef, 1);
    }
  }

  return $gusEdgeTypeId;
}


sub getGusVertexId {
  my ($self, $node, $nodeNameToIdMap) = @_;

  my $name = $node->getValue();
  my $id = $nodeNameToIdMap->{$name}->[0];
  unless($id) {
    $self->error("No vertex_id found for $name");
  }

  return $id;
}


sub getEdgeAttributesHash {
  my ($self, $edge, $nodeNameToIdMap) = @_;

  my %rv;

  my %vertexTypeIds;

  foreach my $output (@{$edge->getOutputs()}) {
    my $name = $output->getValue();
    my $id = $nodeNameToIdMap->{$name}->[1];
    $vertexTypeIds{$id}++;
  }

  my @vtIds = keys %vertexTypeIds;

  foreach my $protocolApp (@{$edge->getProtocolApplications()}) {
    my $protocol = $protocolApp->getProtocol();
    my $protocolName = $protocol->getProtocolName();

    foreach my $parameterValue (@{$protocolApp->getParameterValues()}) {
      my $ppValue = $parameterValue->getTerm();
      my $ppQualifier = $parameterValue->getQualifier();
      $rv{$protocolName}->{$ppQualifier} = $ppValue;

      if($parameterValue->getUnit()) {
        my $qualifierOntologyTerm = $self->getOntologyTermGusObj($parameterValue, 1);
        my $unitOntologyTerm = $self->getOntologyTermGusObj($parameterValue->getUnit(), 0);

        foreach(@vtIds) {
          $self->addAttributeUnit($_, $qualifierOntologyTerm->getId(), $unitOntologyTerm->getId());
        }
      }
      
      if(length $ppValue > $self->{_max_attr_value}) {
        $self->{_max_attr_value} = length $ppValue;
      }
    }
  }
  return \%rv;
}



sub loadEdges {
  my ($self, $edges, $nodeNameToIdMap, $edgeTypeNamesToIdMap) = @_;

  my $edgeCount;
  $self->getDb()->manageTransaction(0, 'begin');

  foreach my $edge (@$edges) {
    my $gusEdgeTypeId = $self->getOrMakeEdgeTypeId($edge, $edgeTypeNamesToIdMap);

    my $edgeAttributesHash = $self->getEdgeAttributesHash($edge, $nodeNameToIdMap);

    my $atts = encode_json($edgeAttributesHash);

    foreach my $output (@{$edge->getOutputs()}) {
      foreach my $input (@{$edge->getInputs()}) {
        my $inId = $self->getGusVertexId($input, $nodeNameToIdMap);
        my $outId = $self->getGusVertexId($output, $nodeNameToIdMap);

        my $gusEdgeAttributes = GUS::Model::ApiDB::EdgeAttributes->new({edge_type_id => $gusEdgeTypeId, 
                                                                        in_vertex_id => $inId,
                                                                        out_vertex_id => $outId,
                                                                        atts => $atts,
                                                                       });

        $gusEdgeAttributes->submit(undef, 1);
        $self->undefPointerCache();

        if($edgeCount++ % 1000 == 0) {
          $self->getDb()->manageTransaction(0, 'commit');
          $self->getDb()->manageTransaction(0, 'begin');
        }
      }
    }
  }

  $self->getDb()->manageTransaction(0, 'commit');
}

sub checkOntologyTermsAndSetIds {
  my ($self, $iOntologyTermAccessionsHash) = @_;

  my $sql = "select 'OntologyTerm', ot.source_id, ot.ontology_term_id id, name
from sres.ontologyterm ot
where ot.source_id = ?
and lower(ot.source_id) not like 'ncbitaxon%'
UNION
select 'NCBITaxon', 'NCBITaxon_' || t.ncbi_tax_id, t.taxon_id id, tn.name
from sres.taxon t, sres.taxonname tn
where 'NCBITaxon_' || t.ncbi_tax_id = ?
and lower(?) like  'ncbitaxon%'
and t.taxon_id = tn.taxon_id
and tn.name_class = 'scientific name'
";

  my $dbh = $self->getQueryHandle();
  my $sh = $dbh->prepare($sql);

  my $rv = {};
  my $oeToName = {};


  foreach my $os (keys %$iOntologyTermAccessionsHash) {

    foreach my $ota (keys %{$iOntologyTermAccessionsHash->{$os}}) {
      my $accessionOrName = basename $ota;
      $sh->execute($accessionOrName, $accessionOrName, $accessionOrName);
      my $count=0;
      my ($ontologyTermId, $ontologyTermName);
      while(my ($dName, $sourceId, $id, $name) = $sh->fetchrow_array()) {
        $ontologyTermId = $id;
        $ontologyTermName = $name;
    $count++;
      }
      $sh->finish();
      if($count == 1) {
        $rv->{$os}->{$ota} = $ontologyTermId;

        $oeToName->{$os}->{$ota} = $ontologyTermName;

      }
      else {
        $self->logOrError("ERROR:  OntologyTerms with Accession Or Name [$accessionOrName] were not found or were not found uniquely in the database");

      }
    }
  }

  $self->{_ontology_term_to_identifiers} = $rv;
  $self->{_ontology_term_to_names} = $oeToName;
}


sub logOrError {
  my ($self, $msg) = @_;

  $self->{_has_errors}++;

  if($self->getArg('commit')) {
    $self->userError($msg);
  }
  else {
    $self->log($msg);
  }
}


sub undoTables {
  my ($self) = @_;

  return (
    'ApiDB.EdgeAttributes',
    'ApiDB.VertexAttributes',
    'ApiDB.EdgeAttributeUnit',
    'ApiDB.EdgeTypeComponent',
    'ApiDB.VertexAttributeUnit',
    'ApiDB.EdgeType',
    'ApiDB.VertexType',
    'ApiDB.PropertyGraph',
     );


}

1;

