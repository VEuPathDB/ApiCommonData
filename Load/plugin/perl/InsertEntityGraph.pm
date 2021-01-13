package ApiCommonData::Load::Plugin::InsertEntityGraph;

@ISA = qw(GUS::PluginMgr::Plugin);
use GUS::PluginMgr::Plugin;
use strict;

use CBIL::ISA::Investigation;
use CBIL::ISA::InvestigationSimple;

use File::Basename;

use GUS::Model::SRes::OntologyTerm;

use GUS::Model::ApiDB::Study;
use GUS::Model::ApiDB::EntityAttributes;
use GUS::Model::ApiDB::EntityType;
use GUS::Model::ApiDB::AttributeUnit;

use GUS::Model::ApiDB::ProcessAttributes;
use GUS::Model::ApiDB::ProcessType;
use GUS::Model::ApiDB::ProcessTypeComponent;

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

        $self->checkProcessTypesAndSetIds($study->getProtocols());

        my $iOntologyTermAccessions = $investigation->getOntologyAccessionsHash();

        my ($ontologyTermToIdentifiers, $ontologyTermToNames) = $self->checkOntologyTermsAndFetchIds($iOntologyTermAccessions);

        $self->checkMaterialEntitiesHaveMaterialType($study->getNodes());

        $self->loadStudy($ontologyTermToIdentifiers, $ontologyTermToNames, $study);
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
      $self->logOrError("Material Entity $value is required to have a [Material Type]");
    }
  }
}

sub checkProcessTypesAndSetIds {
  my ($self, $protocols) = @_;

  my $sql = "select name, process_type_id from apidb.processtype";

  my $dbh = $self->getQueryHandle();
  my $sh = $dbh->prepare($sql);
  $sh->execute();
  my %processTypes;
  while(my ($processType, $processTypeId) = $sh->fetchrow_array()) {
    $processTypes{$processType} = $processTypeId;
  }
  $sh->finish();

  foreach my $protocol (@$protocols) {
    my $protocolName = $protocol->getProtocolName();

    if($processTypes{$protocolName}) {
      $protocol->{_PROCESS_TYPE_ID} = $processTypes{$protocolName};
    }
    else {
      $self->log("WARNING:  Protocol [$protocolName] Not found in the database") ;
    }
  }
}

sub loadStudy {
  my ($self, $ontologyTermToIdentifiers, $ontologyTermToNames, $study) = @_;
  my $extDbRlsSpec = $self->getArg('extDbRlsSpec');
  my $extDbRlsId = $self->getExtDbRlsId($extDbRlsSpec);

  my $identifier = $study->getIdentifier();
  my $description = $study->getDescription();

  my $internalAbbrev = $identifier;
  $internalAbbrev =~ s/-/_/g; #clean name/id for use in oracle table name

  my $gusStudy = GUS::Model::ApiDB::Study->new({stable_id => $identifier, external_database_release_id => $extDbRlsId, internal_abbrev => $internalAbbrev});
  $gusStudy->submit() unless ($gusStudy->retrieveFromDB());

  my $nodeNameToIdMap = $self->loadNodes($ontologyTermToIdentifiers, $ontologyTermToNames, $study->getNodes(), $gusStudy);
  my $processTypeNamesToIdMap = $self->loadProcessTypes($ontologyTermToIdentifiers, $study->getProtocols());

  $self->loadProcesses($ontologyTermToIdentifiers, $study->getEdges(), $nodeNameToIdMap, $processTypeNamesToIdMap);

  if($self->{_max_attr_value} > $gusStudy->getMaxAttrLength()) {
    $gusStudy->setMaxAttrLength($self->{_max_attr_value});
    $gusStudy->submit();
  }
}


sub addEntityTypeForNode {
  my ($self, $ontologyTermToIdentifiers, $node, $gusStudyId) = @_;

  my $isaClassName = ref($node);
  my($isaType) = $isaClassName =~ /\:\:(\w+)$/;

  my $materialType = $node->hasAttribute("MaterialType") ? $node->getMaterialType()->getTerm() : 'NA';

  my $mtKey = $materialType . "_" . $isaType;

  if($self->{_ENTITY_TYPE_IDS}->{$mtKey}) {
    return $self->{_ENTITY_TYPE_IDS}->{$mtKey};
  }

  my $entityType = GUS::Model::ApiDB::EntityType->new();
  $entityType->setStudyId($gusStudyId);
  $entityType->setIsaType($isaType);

  if($node->hasAttribute("MaterialType")) {
    my $materialTypeOntologyTerm = $node->getMaterialType();
    my $gusOntologyTerm = $self->getOntologyTermGusObj($ontologyTermToIdentifiers, $materialTypeOntologyTerm, 0);
    $entityType->setTypeId($gusOntologyTerm->getId());
    $entityType->setName($gusOntologyTerm->getName());
  }
  else {
    $entityType->setName($isaType);
  }


  my $internalAbbrev = $entityType->getName();
  $internalAbbrev =~ s/([\w']+)/\u$1/g;
  $internalAbbrev =~ s/\s//g;

  $entityType->setInternalAbbrev($internalAbbrev);

  $entityType->submit(undef, 1);

  my $id = $entityType->getId();

  $self->{_ENTITY_TYPE_IDS}->{$mtKey} = $id;

  return $id;
}


sub addAttributeUnit {
  my ($self, $entityTypeId, $attrOntologyTermId, $unitOntologyTermId) = @_;

  if($self->{_attribute_units}->{$entityTypeId}->{$attrOntologyTermId}->{$unitOntologyTermId}) {
    return;
  }

  $self->{_attribute_units}->{$entityTypeId}->{$attrOntologyTermId}->{$unitOntologyTermId} = 1;
  

  if(keys %{$self->{_attribute_units}->{$entityTypeId}->{$attrOntologyTermId}} > 1) {
    $self->error("Multiple Units found for EntityTypeId=$entityTypeId and AttributeOntologyTermId=$attrOntologyTermId");
  }

  
  my $attributeValue = GUS::Model::ApiDB::AttributeUnit->new({entity_type_id => $entityTypeId, 
                                                              attr_ontology_term_id => $attrOntologyTermId,
                                                              unit_ontology_term_id => $unitOntologyTermId
                                                             });

  $attributeValue->submit(undef, 1);
}


sub loadNodes {
  my ($self, $ontologyTermToIdentifiers, $ontologyTermToNames, $nodes, $gusStudy) = @_;

  my %rv;

  my $gusStudyId = $gusStudy->getId();

  my $nodeCount = 0;
  $self->getDb()->manageTransaction(0, 'begin');

  foreach my $node (@$nodes) {
    my $charsForLoader = {};

    my $entity = GUS::Model::ApiDB::EntityAttributes->new({stable_id => $node->getValue()});

    my $entityTypeId = $self->addEntityTypeForNode($ontologyTermToIdentifiers, $node, $gusStudyId);
    $entity->setEntityTypeId($entityTypeId);

    if ($node->hasAttribute("Characteristic")) {
      my $characteristics = $node->getCharacteristics();
      foreach my $characteristic (@$characteristics) {

        my $charQualifierOntologyTerm = $self->getOntologyTermGusObj($ontologyTermToIdentifiers, $characteristic, 1);
        my $charQualifierSourceId = $charQualifierOntologyTerm->getSourceId();

        if($characteristic->getUnit()) {
          my $unitOntologyTerm = $self->getOntologyTermGusObj($ontologyTermToIdentifiers, $characteristic->getUnit(), 0);
          $self->addAttributeUnit($entityTypeId, $charQualifierOntologyTerm->getId(), $unitOntologyTerm->getId());
         }

        my ($charValue);

        if(lc $characteristic->getTermSourceRef() eq 'ncbitaxon') {
          my $value = $ontologyTermToNames->{$characteristic->getTermSourceRef()}->{$characteristic->getTermAccessionNumber()};
          $charValue = $value;
        }
        elsif($characteristic->getTermAccessionNumber() && $characteristic->getTermSourceRef()) {
          my $valueOntologyTerm = $self->getOntologyTermGusObj($ontologyTermToIdentifiers, $characteristic, 0);
          $charValue = $valueOntologyTerm->getName();
        }
        else {
              $charValue = $characteristic->getTerm();
        }

        $charValue =~ s/\r//;

        push @{$charsForLoader->{$charQualifierSourceId}}, $charValue;

        if(length $charValue > $self->{_max_attr_value}) {
          $self->{_max_attr_value} = length $charValue;
        }

      }
    }

    my $atts = encode_json($charsForLoader);
    $entity->setAtts($atts);

    $entity->submit(undef, 1);

    # keep the cache up to date as we add new nodes
    $self->{_NODE_MAP}->{$entity->getStableId()} = $entity->getId();

    $rv{$entity->getStableId()} = [$entity->getId(), $entity->getEntityTypeId()];

    $self->undefPointerCache();

    if(++$nodeCount % 1000 == 0) {
      $self->getDb()->manageTransaction(0, 'commit');
      $self->getDb()->manageTransaction(0, 'begin');
    }
  }

  $self->getDb()->manageTransaction(0, 'commit');

  return \%rv;
}

sub getOntologyTermGusObj {
    my ($self, $ontologyTermToIdentifiers, $ontologyTerm, $useQualifier) = @_;

    my $ontologyTermTerm = $ontologyTerm->getTerm();
    my $ontologyTermClass = blessed($ontologyTerm);
    my $ontologyTermAccessionNumber = $ontologyTerm->getTermAccessionNumber();
    my $ontologyTermSourceRef = $ontologyTerm->getTermSourceRef();

    $self->logDebug("OntologyTerm=$ontologyTermTerm\tClass=$ontologyTermClass\tAccession=$ontologyTermAccessionNumber\tSource=$ontologyTermSourceRef\n");

    my $ontologyTermId;
    if(($ontologyTermClass eq 'CBIL::ISA::StudyAssayEntity::ParameterValue' || $ontologyTermClass eq 'CBIL::ISA::StudyAssayEntity::Characteristic') && $useQualifier) {
      my $qualifier = $ontologyTerm->getQualifier();
      $ontologyTermId = $ontologyTermToIdentifiers->{QUALIFIER}->{$qualifier};
      $self->userError("No ontology entry found for qualifier [$qualifier]") unless($ontologyTermId);
    }
    elsif($ontologyTermAccessionNumber && $ontologyTermSourceRef) {
      $ontologyTermId = $ontologyTermToIdentifiers->{$ontologyTermSourceRef}->{$ontologyTermAccessionNumber};
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


sub loadProcessTypes {
  my ($self, $ontologyTermToIdentifiers, $protocols) = @_;

  my $pNameToId = {};

  foreach my $protocol (@$protocols) {
    my $processTypeId = $protocol->{_PROCESS_TYPE_ID};

    my $gusProcessType;

    my $protocolName = $protocol->getProtocolName();

    unless($processTypeId) {
      my $protocolDescription = $protocol->getProtocolDescription();
      $gusProcessType = GUS::Model::ApiDB::ProcessType->new({name => $protocolName, description => $protocolDescription});

      if($protocol->getProtocolType()) {
        my $gusProtocolType = $self->getOntologyTermGusObj($ontologyTermToIdentifiers, $protocol->getProtocolType(), 0);
        $gusProcessType->setParent($gusProtocolType);
      }

      $self->log("Adding ProcessType $protocolName to the database");
      $gusProcessType->submit();
      $processTypeId = $gusProcessType->getId();
    }

    $pNameToId->{$protocolName} = $processTypeId;
  }

  return $pNameToId;
}


sub getOrMakeProcessTypeId {
  my ($self, $process, $processTypeNamesToIdMap) = @_;

  my $protocolCount = scalar @{$process->getProtocolApplications()};
  my $protocolName;

  my @seriesProtocolNames;
  if($protocolCount > 1) {
    @seriesProtocolNames = map { $_->getProtocol()->getProtocolName() } @{$process->getProtocolApplications()};
    # check they have already been loaded and make a name for the series
    my @ok = grep { $processTypeNamesToIdMap->{$_} } @seriesProtocolNames;
    $self->error("ERROR: one or more protocolSeries component protocol not already loaded (@seriesProtocolNames)") unless (@ok == @seriesProtocolNames);
    $protocolName = join("; ", @seriesProtocolNames);
  }
  else {
    $protocolName = $process->getProtocolApplications()->[0]->getProtocol()->getProtocolName();
  }
  
  my $gusProcessTypeId = $processTypeNamesToIdMap->{$protocolName};

  unless($gusProcessTypeId) {
    my $gusProcessType = GUS::Model::ApiDB::ProcessType->new({name => $protocolName});
    $gusProcessType->submit(undef, 1);

    $gusProcessTypeId = $gusProcessType->getId();

    $processTypeNamesToIdMap->{$protocolName} = $gusProcessTypeId;
    for (my $i=0; $i<@seriesProtocolNames; $i++) {
      my $processTypeComponent = GUS::Model::ApiDB::ProcessTypeComponent->new({order_num => $i+1});
      $processTypeComponent->setProcessTypeId($gusProcessTypeId);
      $processTypeComponent->setComponentId($processTypeNamesToIdMap->{$seriesProtocolNames[$i]});
      $processTypeComponent->submit(undef, 1);
    }
  }

  return $gusProcessTypeId;
}


sub getGusEntityId {
  my ($self, $node, $nodeNameToIdMap) = @_;

  my $name = $node->getValue();
  my $id = $nodeNameToIdMap->{$name}->[0];
  unless($id) {
    $self->error("No entity_id found for $name");
  }

  return $id;
}


sub getProcessAttributesHash {
  my ($self,$ontologyTermToIdentifiers, $process, $nodeNameToIdMap) = @_;

  my %rv;

  my %entityTypeIds;

  foreach my $output (@{$process->getOutputs()}) {
    my $name = $output->getValue();
    my $id = $nodeNameToIdMap->{$name}->[1];
    $entityTypeIds{$id}++;
  }

  my @vtIds = keys %entityTypeIds;

  foreach my $protocolApp (@{$process->getProtocolApplications()}) {
    my $protocol = $protocolApp->getProtocol();
    my $protocolName = $protocol->getProtocolName();

    foreach my $parameterValue (@{$protocolApp->getParameterValues()}) {
      my $ppValue = $parameterValue->getTerm();
      my $ppQualifier = $parameterValue->getQualifier();
      push @{$rv{$ppQualifier}}, $ppValue;

      if($parameterValue->getUnit()) {
        my $qualifierOntologyTerm = $self->getOntologyTermGusObj($ontologyTermToIdentifiers, $parameterValue, 1);
        my $unitOntologyTerm = $self->getOntologyTermGusObj($ontologyTermToIdentifiers, $parameterValue->getUnit(), 0);

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



sub loadProcesses {
  my ($self, $ontologyTermToIdentifiers, $processes, $nodeNameToIdMap, $processTypeNamesToIdMap) = @_;

  my $processCount;
  $self->getDb()->manageTransaction(0, 'begin');

  foreach my $process (@$processes) {
    my $gusProcessTypeId = $self->getOrMakeProcessTypeId($process, $processTypeNamesToIdMap);

    my $processAttributesHash = $self->getProcessAttributesHash($ontologyTermToIdentifiers, $process, $nodeNameToIdMap);

    my $atts = encode_json($processAttributesHash);

    foreach my $output (@{$process->getOutputs()}) {
      foreach my $input (@{$process->getInputs()}) {
        my $inId = $self->getGusEntityId($input, $nodeNameToIdMap);
        my $outId = $self->getGusEntityId($output, $nodeNameToIdMap);

        my $gusProcessAttributes = GUS::Model::ApiDB::ProcessAttributes->new({process_type_id => $gusProcessTypeId, 
                                                                        in_entity_id => $inId,
                                                                        out_entity_id => $outId,
                                                                        atts => $atts,
                                                                       });

        $gusProcessAttributes->submit(undef, 1);
        $self->undefPointerCache();

        if(++$processCount % 1000 == 0) {
          $self->getDb()->manageTransaction(0, 'commit');
          $self->getDb()->manageTransaction(0, 'begin');
        }
      }
    }
  }

  $self->getDb()->manageTransaction(0, 'commit');
}

sub checkOntologyTermsAndFetchIds {
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

  my $ontologyTermToIdentifiers = {};
  my $ontologyTermToNames = {};


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
        $ontologyTermToIdentifiers->{$os}->{$ota} = $ontologyTermId;

        $ontologyTermToNames->{$os}->{$ota} = $ontologyTermName;

      }
      else {
        $self->logOrError("ERROR:  OntologyTerms with Accession Or Name [$accessionOrName] were not found or were not found uniquely in the database");

      }
    }
  }
  return $ontologyTermToIdentifiers, $ontologyTermToNames;
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
    'ApiDB.ProcessAttributes',
    'ApiDB.EntityAttributes',
    'ApiDB.AttributeUnit',
    'ApiDB.ProcessTypeComponent',
    'ApiDB.ProcessType',
    'ApiDB.EntityType',
    'ApiDB.Study',
     );


}

1;

