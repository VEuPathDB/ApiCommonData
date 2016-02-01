package ApiCommonData::Load::Plugin::InsertInvestigations;

@ISA = qw(GUS::PluginMgr::Plugin);
use GUS::PluginMgr::Plugin;
use strict;

use CBIL::ISA::Investigation;

use File::Basename;

use GUS::Model::Study::ProtocolAppNode;
use GUS::Model::Study::ProtocolApp;
use GUS::Model::Study::ProtocolAppParam;
use GUS::Model::Study::Input;
use GUS::Model::Study::Output;
use GUS::Model::Study::Protocol;
use GUS::Model::Study::ProtocolParam;
use GUS::Model::Study::Characteristic;
use GUS::Model::Study::StudyLink;
use GUS::Model::Study::Study;

use GUS::Model::SRes::OntologyTerm;

use CBIL::ISA::Investigation;

use Scalar::Util qw(blessed);

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
            descr          => 'directory where to find directories of isa tab files',
            reqd           => 1,
            constraintFunc => undef,
            isList         => 0, }),


   stringArg({name           => 'investigationSubset',
            descr          => 'Skip directory unless it is one of these',
            reqd           => 0,
            constraintFunc => undef,
            isList         => 1, }),

  ];

my $documentation = { purpose          => "",
                      purposeBrief     => "",
                      notes            => "",
                      tablesAffected   => "",
                      tablesDependedOn => "",
                      howToRestart     => "",
                      failureCases     => "" };

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
  foreach my $investigation (@investigationFiles) {
    my $dirname = dirname $investigation;
    $self->log("Processing ISA Directory:  $dirname");

    my $investigation = CBIL::ISA::Investigation->new($investigationBaseName, $dirname, "\t");

    $investigation->parse();

    $self->checkAllOntologyTerms($investigation->getOntologyTerms());

    my $iOntologyTermAccessions = $investigation->getOntologyAccessionsHash();
    $self->checkOntologyTermsAndSetIds($iOntologyTermAccessions);

    my $studies = $investigation->getStudies();
    foreach my $study (@$studies) {
      my %foundDatasets;

      $self->checkProtocolsAndSetIds($study->getProtocols());

      my $studyAssays = $study->getStudyAssays();

      foreach my $studyAssay (@$studyAssays) {
        my $comments = $studyAssay->getComments();
        foreach my $comment (@$comments) {
          next unless($comment->getQualifier() eq 'dataset_names');
          my @datasetNames = split(/;/, $comment->getValue());
          foreach my $datasetName (@datasetNames) {
            $foundDatasets{$datasetName}++;
          }
        }
      }

      $self->checkMaterialEntitiesHaveMaterialType($study->getNodes());
      $self->checkDatabaseNodesAreHandled(\%foundDatasets, $study->getNodes());
      $self->checkDatabaseProtocolApplicationsAreHandledAndMark(\%foundDatasets, $study->getEdges());

      $self->loadStudy($study);
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

sub checkAllOntologyTerms {
  my ($self, $ontologyTerms) = @_;

  foreach my $ontologyTerm (@$ontologyTerms) {
    my $accession = $ontologyTerm->getTermAccessionNumber();
    my $source = $ontologyTerm->getTermSourceRef();
    my $term = $ontologyTerm->getTerm();


    unless(($accession && $source) || blessed($ontologyTerm) eq 'CBIL::ISA::StudyAssayEntity::Characteristic' || blessed($ontologyTerm) eq 'CBIL::ISA::StudyAssayEntity::ParameterValue') {
      $self->logOrError("OntologyTerm $term is required to have accession and source.");
    }
  }
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

sub checkProtocolsAndSetIds {
  my ($self, $protocols) = @_;

  my $sql = "select name, protocol_id from study.protocol";

  my $dbh = $self->getQueryHandle();
  my $sh = $dbh->prepare($sql);
  $sh->execute();
  my %protocols;
  while(my ($protocol, $protocolId) = $sh->fetchrow_array()) {
    $protocols{$protocol} = $protocolId;
  }
  $sh->finish();

  foreach my $protocol (@$protocols) {
    my $protocolName = $protocol->getProtocolName();

    if($protocols{$protocolName}) {
      $protocol->{_PROTOCOL_ID} = $protocols{$protocolName};
    }
    else {
      $self->log("WARNING:  Protocol [$protocolName] Not found in the database ... adding") ;
    }
  }
}

sub loadStudy {
  my ($self, $study) = @_;

  my $identifier = $study->getIdentifier();
  my $title = $study->getTitle();
  $title = $identifier unless($title);
  my $description = $study->getDescription();

  my $gusStudy = GUS::Model::Study::Study->new({name => $title, description => $description, source_id => $identifier});
  $gusStudy->submit();

  my $panNameToIdMap = $self->loadNodes($study->getNodes(), $gusStudy);
  my ($protocolParamsToIdMap, $protocolNamesToIdMap) = $self->loadProtocols($study->getProtocols());

  $self->loadEdges($study->getEdges, $panNameToIdMap, $protocolParamsToIdMap, $protocolNamesToIdMap);
}


sub loadNodes {
  my ($self, $nodes, $gusStudy) = @_;

  my %rv;

  foreach my $node (@$nodes) {
    my $pan;

    if(my $panId = $node->{_PROTOCOL_APP_NODE_ID}) {
      $pan = GUS::Model::Study::ProtocolAppNode->new({protocol_app_node_id => $panId});
      unless($pan->retrieveFromDB()) {
        $self->error("Could not retrieve ProtocolAppNode [$panId] w/ name " . $node->getValue());
      }
    }
    else {
      $pan = GUS::Model::Study::ProtocolAppNode->new({name => $node->getValue()});
    }

    my $gusStudyLink = GUS::Model::Study::StudyLink->new();
    $gusStudyLink->setParent($gusStudy);
    $gusStudyLink->setParent($pan);

    if($node->hasAttribute("MaterialType")) {
      my $materialTypeOntologyTerm = $node->getMaterialType();
      my $gusOntologyTerm = $self->getOntologyTermGusObj($materialTypeOntologyTerm, 0);
      my $ontologyTermId = $gusOntologyTerm->getId();
      $pan->setTypeId($ontologyTermId); # CANNOT Set Parent because OntologyTerm Table has type and subtype.  Both have fk to Sres.ontologyterm

      my $characteristics = $node->getCharacteristics();
      foreach my $characteristic (@$characteristics) {
        if(lc $characteristic->getTermSourceRef() eq 'ncbitaxon') {
       
          my $taxonId = $self->{_ontology_term_to_identifiers}->{$characteristic->getTermSourceRef()}->{$characteristic->getTermAccessionNumber()};
          $pan->setTaxonId($taxonId);
        }
        else {
          my $gusChar = GUS::Model::Study::Characteristic->new();
          $gusChar->setParent($pan);

          # ALWAYS Set the qualifier_id
          my $charQualifierOntologyTerm = $self->getOntologyTermGusObj($characteristic, 1);
          $gusChar->setQualifierId($charQualifierOntologyTerm->getId()); # CANNOT SET Parent because ontology term id and Unit id.  both fk to sres.ontologyterm

          if($characteristic->getUnit()) {
            my $unitOntologyTerm = $self->getOntologyTermGusObj($characteristic->getUnit(), 0);
            $gusChar->setUnitId($unitOntologyTerm->getId());
          }


          if($characteristic->getTermAccessionNumber() && $characteristic->getTermSourceRef()) {
            my $valueOntologyTerm = $self->getOntologyTermGusObj($characteristic, 0);
            $gusChar->setOntologyTermId($valueOntologyTerm->getId()); 
          }
          else {
            $gusChar->setValue($characteristic->getTerm());
          }

        }
      }
    }

    $pan->submit();
    $rv{$pan->getName()} = $pan->getId();

    $self->undefPointerCache();

  }
  return \%rv;
}

sub getOntologyTermGusObj {
    my ($self, $ontologyTerm, $isCharQualifier) = @_;

    my $ontologyTermTerm = $ontologyTerm->getTerm();
    my $ontologyTermClass = blessed($ontologyTerm);
    my $ontologyTermAccessionNumber = $ontologyTerm->getTermAccessionNumber();
    my $ontologyTermSourceRef = $ontologyTerm->getTermSourceRef();

    $self->logDebug("OntologyTerm=$ontologyTermTerm\tClass=$ontologyTermClass\tAccession=$ontologyTermAccessionNumber\tSource=$ontologyTermSourceRef\n");

    my $ontologyTermId;
    if($ontologyTermClass eq 'CBIL::ISA::StudyAssayEntity::Characteristic' && $isCharQualifier) {
      my $qualifier = $ontologyTerm->getQualifier();
      $ontologyTermId = $self->{_ontology_term_to_identifiers}->{CHARACTERISTIC_QUALIFIER}->{$qualifier};
      $self->userError("No ontology entry found for qualifier [$qualifier]") unless($ontologyTermId);
    }
    elsif($ontologyTermAccessionNumber && $ontologyTermSourceRef) {
      $ontologyTermId = $self->{_ontology_term_to_identifiers}->{$ontologyTermSourceRef}->{$ontologyTermAccessionNumber};
    }
    else {
      $self->logOrError("OntologyTerm of class $ontologyTermClass and value [$ontologyTermTerm] must provide accession&source OR a qualifier in the case of Characteristics must map to an ontologyterm");
    }


    if(my $gusObj = $self->{_gus_ontologyterm_objects}->{$ontologyTermId}) {
      return $gusObj;
    }

    my $gusOntologyTerm = GUS::Model::SRes::OntologyTerm->new({ontology_term_id => $ontologyTermId});
    unless($gusOntologyTerm->retrieveFromDB()) {
      $self->error("ERROR:  OntologyTerm ID=$ontologyTermId not found in the database");
    }

    $self->{_gus_ontologyterm_objects}->{$ontologyTermId} = $gusOntologyTerm;
    return $gusOntologyTerm;
}


sub loadProtocols {
  my ($self, $protocols) = @_;


  my $ppNameToId = {};
  my $pNameToId = {};

  foreach my $protocol (@$protocols) {
    my $protocolId = $protocol->{_PROTOCOL_ID};
    my $gusProtocol;

    my $protocolName = $protocol->getProtocolName();

    if($protocolId) {
      $gusProtocol = GUS::Model::Study::Protocol->new({protocol_id => $protocolId});
      unless($gusProtocol->retrieveFromDB()) {
        $self->error("Could not retrieve Study.Protocol w/ protoocl id [$protocolId]");
      }
    }
    else {
      my $protocolDescription = $protocol->getProtocolDescription();
      $gusProtocol = GUS::Model::Study::Protocol->new({name => $protocolName, description => $protocolDescription});

      if($protocol->getProtocolType()) {
        my $gusProtocolType = $self->getOntologyTermGusObj($protocol->getProtocolType(), 0);
        $gusProtocol->setParent($gusProtocolType);
      }
    }

    my @gusProtocolParams = $gusProtocol->getChildren("Study::ProtocolParam", 1);
    my $protocolParams = $protocol->getProtocolParameters();

    foreach my $protocolParam (@$protocolParams) {
      my $found;

      foreach my $gusProtocolParam (@gusProtocolParams) {
        if($gusProtocolParam->getName() eq $protocolParam->getTerm()) {
          $found = 1;
          last;
        }
      }

      unless($found) {
        my $gusProtocolParam = GUS::Model::Study::ProtocolParam->new({name => $protocolParam->getTerm()});
        $gusProtocolParam->setParent($gusProtocol);
      }
    }

    $gusProtocol->submit();
    $pNameToId->{$protocolName} = $gusProtocol->getId();

    foreach my $pp ($gusProtocol->getChildren("Study::ProtocolParam")) { # no need to retrieve here
      my $ppName = $pp->getName();
      my $ppId = $pp->getId();
      $ppNameToId->{$protocolName}->{$ppName} = $ppId;
    }
  }
  return($ppNameToId, $pNameToId);
}


sub loadEdges {
  my ($self, $edges, $panNameToIdMap, $protocolParamsToIdMap, $protocolNamesToIdMap) = @_;

  foreach my $edge (@$edges) {
    my $databaseStatus = $edge->{_DATABASE_STATUS};
    my $protocolAppId = $edge->{_PROTOCOL_APP_ID};

    my $gusProtocolApp;
    my $protocolCount = 1;

    if($protocolAppId) {
      $gusProtocolApp = GUS::Model::Study::ProtocolApp->new({protocol_app_id => $protocolAppId});
      unless($gusProtocolApp->retrieveFromDB()) {
        $self->error("Could not retrieve Study.protocolApp w/ protocol_ap_id [$protocolAppId]");
      }
    }
    else {
      $gusProtocolApp = GUS::Model::Study::ProtocolApp->new();

      $protocolCount = scalar @{$edge->getProtocolApplications()};

      my $protocolName;

      my $gusProtocol;

      if($protocolCount > 1) {
        my @protocolNames = map { $_->getProtocol()->getProtocolName() } @{$edge->getProtocolApplications()};

        $protocolName = join("; ", @protocolNames);
      }
      else {
        $protocolName = $edge->getProtocolApplications()->[0]->getProtocol()->getProtocolName();
      }

      if(my $gusProtocolId = $protocolNamesToIdMap->{$protocolName}) {
        $gusProtocol = GUS::Model::Study::Protocol->new({protocol_id => $gusProtocolId});
        unless($gusProtocol->retrieveFromDB()) {
          $self->error("Could not retrieve protocol w/ protocol id of [$gusProtocolId]");
        }
      }
      else {
        $gusProtocol = GUS::Model::Study::Protocol->new({name => $protocolName});
        $gusProtocol->retrieveFromDB(); # try to retrieve it

        $gusProtocol->submit();
        $protocolNamesToIdMap->{$protocolName} = $gusProtocol->getId();        
      }
      
      $gusProtocolApp->setParent($gusProtocol);
    }

    if($databaseStatus) {
      $self->error("Edge DATABASE_STATUS set but missing protocol_app_id") unless($gusProtocolApp);
    }

    foreach my $output (@{$edge->getOutputs()}) {
      next if($databaseStatus);

      my $gusOutput = GUS::Model::Study::Output->new();

      my $outputName = $output->getValue();
      my $outputId = $panNameToIdMap->{$outputName};
      unless($outputId) {
        $self->error("No protocol app node id found for output $outputName");
      }
      $gusOutput->setProtocolAppNodeId($outputId);
      $gusProtocolApp->addToSubmitList($gusOutput);
      $gusOutput->setParent($gusProtocolApp);
    }

    foreach my $input (@{$edge->getInputs()}) {
      next if($databaseStatus eq 'FOUND_OUTPUTS_AND_INPUTS');

      my $gusInput = GUS::Model::Study::Input->new();

      my $inputName = $input->getValue();
      my $inputId = $panNameToIdMap->{$inputName};
      unless($inputId) {
        $self->error("No protocol app node id for input $inputName");
      }
      $gusInput->setProtocolAppNodeId($inputId);

      $gusInput->setParent($gusProtocolApp);
      $gusProtocolApp->addToSubmitList($gusInput);
    }

    my %existingProtocolAppParam;
    my @gusProtocolAppParams = $gusProtocolApp->getChildren("Study::ProtocolAppParam", 1); # go to the database and get all the children
    foreach my $gusProtocolAppParam (@gusProtocolAppParams) {
      my $gusProtocolParam = $gusProtocolAppParam->getParent("Study::ProtocolParam", 1);
      $existingProtocolAppParam{$gusProtocolParam->getName()} = 1;
    }

    # in the database we have one row in protocolapp w/ pointer to a protocol
    foreach my $protocolApp (@{$edge->getProtocolApplications()}) {
      my $protocol = $protocolApp->getProtocol();
      my $protocolName = $protocol->getProtocolName();

      foreach my $parameterValue (@{$protocolApp->getParameterValues()}) {
        my $ppValue = $parameterValue->getTerm();
        my $ppName = $parameterValue->getQualifier();

        next if($existingProtocolAppParam{$ppName}); #NOTE:  This is a bit easier because we don't deal w/ protocol series for existing protocolapps
        my $gusProtocolParamId = $protocolParamsToIdMap->{$protocolName}->{$ppName};
        unless($gusProtocolParamId) {
          $self->error("Could not find protocol param id for protocol [$protocolName] and protocolParam name [$ppName]");
        }

        my $gusProtocolAppParam = GUS::Model::Study::ProtocolAppParam->new({protocol_param_id => $gusProtocolParamId, value => $ppValue});
        $gusProtocolAppParam->setParent($gusProtocolApp);
      }
    }
    $gusProtocolApp->submit();
    $self->undefPointerCache();
  }
}



sub checkDatabaseProtocolApplicationsAreHandledAndMark {
  my ($self, $foundDatasets, $edges) = @_;

  my $sql = "select * from (
select d.name dataset, p.name protocol, pa.PROTOCOL_APP_ID, pan.name, pan.protocol_app_node_id, 'input' as io
from study.protocolapp pa
   , study.protocol p
   , study.input i
   , study.protocolappnode pan
   , study.studylink sl
   , study.study s
   , study.study i
   , SRES.EXTERNALDATABASE d
   , sres.externaldatabaserelease r
where pa.PROTOCOL_ID = p.protocol_id
and pa.PROTOCOL_APP_ID = i.PROTOCOL_APP_ID
and i.PROTOCOL_APP_NODE_ID = pan.PROTOCOL_APP_NODE_ID
and pan.PROTOCOL_APP_NODE_ID = sl.PROTOCOL_APP_NODE_ID
and sl.STUDY_ID = s.study_id
and s.INVESTIGATION_ID = i.STUDY_ID
and i.EXTERNAL_DATABASE_RELEASE_ID = r.EXTERNAL_DATABASE_RELEASE_ID
and r.EXTERNAL_DATABASE_ID = d.external_database_id
union
select d.name dataset, p.name protocol, pa.PROTOCOL_APP_ID, pan.name, pan.protocol_app_node_id, 'output' as io
from study.protocolapp pa
   , study.protocol p
   , study.Output i
   , study.protocolappnode pan
   , study.studylink sl
   , study.study s
   , study.study i
   , SRES.EXTERNALDATABASE d
   , sres.externaldatabaserelease r
where pa.PROTOCOL_ID = p.protocol_id
and pa.PROTOCOL_APP_ID = i.PROTOCOL_APP_ID
and i.PROTOCOL_APP_NODE_ID = pan.PROTOCOL_APP_NODE_ID
and pan.PROTOCOL_APP_NODE_ID = sl.PROTOCOL_APP_NODE_ID
and sl.STUDY_ID = s.study_id
and s.INVESTIGATION_ID = i.STUDY_ID
and i.EXTERNAL_DATABASE_RELEASE_ID = r.EXTERNAL_DATABASE_RELEASE_ID
and r.EXTERNAL_DATABASE_ID = d.external_database_id
) 
where dataset = ? ";

  my $dbh = $self->getQueryHandle();
  my $sh = $dbh->prepare($sql);

  my $databaseEdges = {};
  foreach my $datasetName(keys %$foundDatasets) {
    $sh->execute($datasetName);
    while(my ($dataset, $protocol, $protocolAppId, $pan, $panId, $io) = $sh->fetchrow_array()) {
      push @{$databaseEdges->{$protocol}->{$protocolAppId}->{$io}}, $pan;
    }
    $sh->finish();
  }

  foreach my $databaseProtocol (keys %$databaseEdges) {
    foreach my $protocolAppId (keys %{$databaseEdges->{$databaseProtocol}}) {

      my @databaseOutputs = sort @{$databaseEdges->{$databaseProtocol}->{$protocolAppId}->{output}};

      unless(scalar @databaseOutputs > 0) {
        $self->logOrError("ERROR: ProtocolApp [$protocolAppId] is missing Outputs");
      }

      my $found;

      foreach my $edge (@$edges) {
        my $protocolApps = $edge->getProtocolApplications();

        # Not in the business of matching protocol series.  
        next if(scalar @$protocolApps > 1);
        my $protocolApp = $protocolApps->[0];

        next unless($databaseProtocol eq $protocolApp->getValue());

        my @outputs = sort map { $_->getValue()} @{$edge->getOutputs()};
        next unless(join(".", @outputs) eq join(".", @databaseOutputs));

        $found++;
        $edge->{_DATABASE_STATUS} = 'FOUND_OUTPUTS';
        $edge->{_PROTOCOL_APP_ID} = $protocolAppId;

        if($databaseEdges->{$databaseProtocol}->{$protocolAppId}->{input}) {
          my @databaseInputs = sort @{$databaseEdges->{$databaseProtocol}->{$protocolAppId}->{input}};
          my @inputs = sort map {$_->getValue()} @{$edge->getInputs()};

          if(join(".", @inputs) eq join(".", @databaseInputs)) {
            $edge->{_DATABASE_STATUS} = 'FOUND_OUTPUTS_AND_INPUTS';
          } 
          else {
            $self->logOrError("ISATAB_ERROR:  Inputs found for ProtocolApp [$protocolApp] but they do not match the Inputs defined for this Edge in the ISA Tab File");
          }
        }
      }
      $self->logOrError("ISATAB_ERROR:  ProtocolApp [$protocolAppId] could not be matched to Edges in the ISA Tab file") unless($found);
    }
  }
}


sub checkOntologyTermsAndSetIds {
  my ($self, $iOntologyTermAccessionsHash) = @_;

  my $sql = "select 'OntologyTerm', ot.source_id, ot.ontology_term_id id
from sres.ontologyterm ot
where (replace(ot.source_id, ':', '_') = ? OR ot.name = ?)
and lower(ot.source_id) not like 'ncbitaxon%'
UNION
select 'NCBITaxon', 'NCBITaxon_' || ncbi_tax_id, taxon_id id
from sres.taxon 
where 'NCBITaxon_' || ncbi_tax_id = ?
and lower(?) like  'ncbitaxon%'
";

  my $dbh = $self->getQueryHandle();
  my $sh = $dbh->prepare($sql);

  my $rv = {};

  foreach my $os (keys %$iOntologyTermAccessionsHash) {
    foreach my $ota (keys %{$iOntologyTermAccessionsHash->{$os}}) {
      my $accessionOrName = basename $ota;
      $sh->execute($accessionOrName, $accessionOrName, $accessionOrName, $accessionOrName);

      my %foundIn;
      while(my ($dName, $sourceId, $id) = $sh->fetchrow_array()) {
        $foundIn{$dName} = [$sourceId, $id];
      }

      if(scalar keys %foundIn < 1) {
        $self->logOrError("ERROR:  Neither OntologyTerm Accession nor Name [$accessionOrName] was found in the database");
        next;
      }
      elsif(scalar keys %foundIn == 1) {
        my @values = values %foundIn;
        $rv->{$os}->{$ota} = $values[0]->[1];
      }
      else {

        my $state = 1000; # really large number

        foreach my $extDbName (keys %foundIn) {
          my $accession = $foundIn{$extDbName}->[0];
          my $identifier = $foundIn{$extDbName}->[1];

          my $lcOs = lc $os;

          my @splitAccession = split(/_/, $accession);
          my $lcSplitAccession = lc($splitAccession[0]);


          # always use the eupath ontology if there is one
          if($extDbName eq 'OntologyTerm_EuPath_RSRC') {
            $rv->{$os}->{$ota} = $identifier;
            $state = 1;
          }

          # If not eupath and there is a direct match to the source extdbrls then use that 
          if($state > 1 && $extDbName =~ /_${lcOs}_/) {
            $rv->{$os}->{$ota} = $identifier;
            $state = 2;
          }

          # Split the accession by _ and try to match the prefix of the ontology term to the extdbrls name
          if($state > 2 && $extDbName =~ /_${lcSplitAccession}_/) {
            $rv->{$os}->{$ota} = $identifier;
            $state = 3;
          }
        }

        unless(defined $rv->{$os}->{$ota}) {
          $self->logOrError("ERROR:  OntologyTerms with Accession Or Name [$accessionOrName] were found multiple times in the database but none for source $os and none where the loaded source matches the prefix of the accession");
        }
      }
    }
  }

  $self->{_ontology_term_to_identifiers} = $rv;
}

sub checkDatabaseNodesAreHandled {
  my ($self, $foundDatasets, $nodes) = @_;

  unless(scalar keys %$foundDatasets > 0) {
    $self->logOrError("ISATAB_ERROR:  Required Comment[dataset_name] for assay not found");
  }

  my $sql = "select pan.name, pan.protocol_app_node_id
from apidb.datasource ds
   , SRES.EXTERNALDATABASE d
   , SRES.EXTERNALDATABASERELEASE r
   , study.study i
   , study.study ps
   , study.studylink sl
   , STUDY.PROTOCOLAPPNODE pan
where ds.name = ?
 and ds.EXTERNAL_DATABASE_NAME = d.name
 and d.EXTERNAL_DATABASE_ID = r.EXTERNAL_DATABASE_ID
 and r.EXTERNAL_DATABASE_RELEASE_ID = i.EXTERNAL_DATABASE_RELEASE_ID
 and i.STUDY_ID = ps.INVESTIGATION_ID
 and ps.study_id = sl.study_id
 and sl.PROTOCOL_APP_NODE_ID = pan.PROTOCOL_APP_NODE_ID
 UNION
select pan.name, pan.protocol_app_node_id
from apidb.datasource ds
   , SRES.EXTERNALDATABASE d
   , SRES.EXTERNALDATABASERELEASE r
   , study.study i
    , study.studylink sl
   , STUDY.PROTOCOLAPPNODE pan
where ds.name = ?
 and ds.EXTERNAL_DATABASE_NAME = d.name
 and d.EXTERNAL_DATABASE_ID = r.EXTERNAL_DATABASE_ID
 and r.EXTERNAL_DATABASE_RELEASE_ID = i.EXTERNAL_DATABASE_RELEASE_ID
 and i.STUDY_ID = sl.study_id
 and sl.PROTOCOL_APP_NODE_ID = pan.PROTOCOL_APP_NODE_ID";

  my $dbh = $self->getQueryHandle();
  my $sh = $dbh->prepare($sql);

  my %studyNodes;

  foreach my $datasetName(keys %$foundDatasets) {
    $sh->execute($datasetName, $datasetName);

    while(my ($pan, $panId) = $sh->fetchrow_array()) {
      if($studyNodes{$pan}) {
        $self->logOrError("DATABASE_ERROR:  Existing ProtocolAppNode name $pan not unique w/in a study");
      }

      $studyNodes{$pan} = 1;

      my $found = 0;
      foreach my $node (@$nodes) {
        if($node->getValue() eq $pan) {
          $node->{_PROTOCOL_APP_NODE_ID} = $panId;
          $found++ ;
        }
      }

      unless($found == 1) {
        $self->logOrError("ISATAB_ERROR:  ProtocolAppNode named $pan for dataset $datasetName was not handled in the ISATab file.  Found it $found times.");
      }
    }
    $sh->finish();
  }
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
    'Study.Input',
    'Study.Output',
    'Study.Characteristic',
    'Study.StudyLink',
    'Study.ProtocolAppNode',
    'Study.ProtocolAppParam',
    'Study.ProtocolApp',
    'Study.ProtocolParam',
    'Study.Study',
     );
}

1;

