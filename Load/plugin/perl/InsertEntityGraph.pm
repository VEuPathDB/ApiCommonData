package ApiCommonData::Load::Plugin::InsertEntityGraph;
use base qw(ApiCommonData::Load::Plugin::ParameterizedSchema);

use strict;
use warnings;

use GUS::PluginMgr::Plugin;

use CBIL::ISA::Investigation;
use CBIL::ISA::InvestigationSimple;

use File::Basename;

use GUS::Model::SRes::OntologyTerm;
use GUS::Model::ApidbUserDatasets::OntologyTerm;
use GUS::Model::SRes::TaxonName;

use CBIL::ISA::Investigation;
use CBIL::ISA::InvestigationSimple;

use ApiCommonData::Load::StudyUtils;

use Scalar::Util qw(blessed);
use POSIX qw/strftime/;

use Encode;
use Text::Unidecode;

use JSON;

use ApiCommonData::Load::GeoLookup;

use Data::Dumper;
my $GEOHASH_PRECISION = ${ApiCommonData::Load::StudyUtils::GEOHASH_PRECISION};
my @GEOHASH_SOURCE_IDS = sort { $GEOHASH_PRECISION->{$a} <=> $GEOHASH_PRECISION->{$b} } keys %$GEOHASH_PRECISION;

my $SCHEMA;
my $TERM_SCHEMA = "SRES";

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
   stringArg({name           => 'schema',
            descr          => 'GUS::Model schema for entity tables',
            reqd           => 1,
            constraintFunc => undef,
            isList         => 0, }),

 integerArg({  name           => 'userDatasetId',
	       descr          => 'For use with Schema=ApidbUserDatasets; this is the user_dataset_id',
	       reqd           => 0,
	       constraintFunc => undef,
	       isList         => 0 }),


   booleanArg({name => 'isSimpleConfiguration',
          descr => 'if true, use CBIL::ISA::InvestigationSimple',
          reqd => 1,
          constraintFunc => undef,
          isList => 0,
         }),


   booleanArg({name => 'skipDatasetLookup',
          descr => 'UNUSED (was: do not require existing nodes for datasets listed in isa filesi)',
          reqd => 0,
          constraintFunc => undef,
          isList => 0,
         }),

      booleanArg({name => 'loadProtocolTypeAsVariable',
          descr => 'should we add protocol types in processattributes',
          reqd => 0,
          constraintFunc => undef,
          isList => 0,
         }),

   stringArg({name           => 'protocolVariableSourceId',
            descr          => 'If set, will load protocol names as values attached to this term',
            reqd           => 0,
            constraintFunc => undef,
            isList         => 0, }),

      booleanArg({name => 'useOntologyTermTableForTaxonTerms',
          descr => 'should we use sres.ontologyterm instead of sres.taxonname',
          reqd => 0,
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


   stringArg({name           => 'gadmDsn',
            descr          => 'dbi dsn for gadm postgres database',
            reqd           => 0,
            constraintFunc => undef,
            isList         => 0, }),
  ];

our $documentation = { purpose          => "",
                      purposeBrief     => "",
                      notes            => "",
                      tablesAffected   => "",
                      tablesDependedOn => "",
                      howToRestart     => "",
                      failureCases     => "" };

# ----------------------------------------------------------------------
# our @UNDO_TABLES =qw(
#   ProcessAttributes
#   EntityAttributes
#   EntityClassification
#   AttributeUnit
#   ProcessTypeComponent
#   EntityType
#   Study
# ); ## undo is not run on ProcessType


our @REQUIRE_TABLES = qw(
  Study
  EntityType
  EntityAttributes
  EntityClassification
  AttributeUnit
  ProcessAttributes
  ProcessType
  ProcessTypeComponent
);

# JohnB/Jay: undo is not run on ProcessType
our @UNDO_TABLES = grep {$_ ne 'ProcessType' } reverse @REQUIRE_TABLES;

# ----------------------------------------------------------------------

sub new {
  my ($class) = @_;
  my $self = bless({},$class);

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
  $self->requireModelObjects();
  $self->resetUndoTables(); # for when logRowsInserted() is called after loading

  if (my $gadmDsn = $self->getArg('gadmDsn')) {
    $self->{_geolookup} = ApiCommonData::Load::GeoLookup->new(gadmDsn => $gadmDsn);
  }

  my $metaDataRoot = $self->getArg('metaDataRoot');
  my $investigationBaseName = $self->getArg('investigationBaseName');

  my @investigationFiles;

  my $investigationSubset = $self->getArg('investigationSubset');
  if($investigationSubset) {
    @investigationFiles = map { "$metaDataRoot/$_/$investigationBaseName" } @$investigationSubset;
  }
  else {
    @investigationFiles = glob "$metaDataRoot/*/$investigationBaseName";
    if (-f "$metaDataRoot/$investigationBaseName"){
      push @investigationFiles, "$metaDataRoot/$investigationBaseName"; 
    }
  }
  $self->userError("No investigation files") unless @investigationFiles;

  $SCHEMA = $self->getArg('schema');

  if(uc($SCHEMA) eq 'APIDBUSERDATASETS' && $self->getArg("userDatasetId")) {
    $TERM_SCHEMA = 'APIDBUSERDATASETS';
  }

  my $extDbRlsId = $self->getExtDbRlsId($self->getArg('extDbRlsSpec'));
  my $investigationCount;
  foreach my $investigationFile (@investigationFiles) {
    my $dirname = dirname $investigationFile;
    $self->log("Processing ISA Directory:  $dirname");

    my $investigation;
    if($self->getArg('isSimpleConfiguration')) {
      my $valueMappingFile = $self->getArg('valueMappingFile');
      my $dateObfuscationFile = $self->getArg('dateObfuscationFile');

      my $ontologyMappingFile = $self->getArg('ontologyMappingFile');
      my $ontologyMappingOverrideFile = $self->getArg('ontologyMappingOverrideFileBaseName');
      if ($ontologyMappingOverrideFile && ! -f $ontologyMappingOverrideFile){ ## prepend path
        $ontologyMappingOverrideFile = join("/", $metaDataRoot, $ontologyMappingOverrideFile);
      }
      $investigation = CBIL::ISA::InvestigationSimple->new($investigationFile, $ontologyMappingFile, $ontologyMappingOverrideFile, $valueMappingFile, undef, undef, $dateObfuscationFile, undef);
    }
    else {
      $investigation = CBIL::ISA::Investigation->new($investigationBaseName, $dirname, "\t");
    }
    $self->loadInvestigation($investigation, $extDbRlsId);
    $investigationCount++;
  }
  $self->logRowsInserted() if($self->getArg('commit'));

  if(my $gl = $self->{_geolookup}) {
    $gl->disconnect();
  }

  $self->log("Processed $investigationCount Investigations.");
}

# called by the run methods
# here and also in ApiCommonData::Load::Plugin::MBioInsertEntityGraph
sub loadInvestigation {
  my ($self, $investigation, $extDbRlsId) = @_;
  do {
    my %errors;
    my $c = $investigation->{_on_error};
    $investigation->setOnError(sub {
      my ($error) = @_;
      $c->(@_) if $c;
      $self->log("Error found when parsing:\n$error") unless $errors{$error}++;
    });
    $investigation->setOnLog(sub { $self->log(@_);});

    $investigation->parseInvestigation();

    my $investigationId = $investigation->getIdentifier();
    my $studies = $investigation->getStudies();

    my $nodeToIdMap = {};
    my $seenProcessMap = {};

    foreach my $study (@$studies) {
      my $gusStudy = $self->createGusStudy($extDbRlsId, $study);

      # add the user_dataset_id if we are in that mode
      if(uc($SCHEMA) eq 'APIDBUSERDATASETS' && $self->getArg("userDatasetId")) {
        $gusStudy->setUserDatasetId($self->getArg("userDatasetId"));
      }

      unless($gusStudy->retrieveFromDB()){
        $gusStudy->submit; 
      }

      while($study->hasMoreData()) {
        $investigation->parseStudy($study);
        $investigation->dealWithAllOntologies();

        my $nodes = $study->getNodes();
        my $protocols = $self->protocolsCheckProcessTypesAndSetIds($study->getProtocols());
        my $edges = $study->getEdges();

        my $iOntologyTermAccessions = $investigation->getOntologyAccessionsHash();

        my ($ontologyTermToIdentifiers, $ontologyTermToNames) = $self->checkOntologyTermsAndFetchIds($iOntologyTermAccessions);

        $self->loadBatchOfStudyData($ontologyTermToIdentifiers, $ontologyTermToNames, $gusStudy->getId, $nodes, $protocols, $edges, $nodeToIdMap, $seenProcessMap)
         unless %errors;
      }
      $self->ifNeededUpdateStudyMaxAttrLength($gusStudy);
      $self->updateEntityCardinality($gusStudy->getId);
    }

    foreach my $output (keys %$seenProcessMap) {
      foreach my $input (keys %{$seenProcessMap->{$output}}) {
        if(keys %{$seenProcessMap->{$output}} > 1) {
          $self->userError("Entity [$output] has multiple inputs");
        }
      }
    }

    my $errorCount = scalar keys %errors;
    if($errorCount) {
      $self->error(join("\n","FOUND $errorCount DIFFERENT ERRORS!", keys %errors));
    }
  };
}

sub countLines {
  my ($self, $charFile) = @_;
  open(FILE, "<", $charFile);
  my $count += tr/\n/\n/ while sysread(FILE, $_, 2 ** 16);
  close(FILE);
  return $count;
}



sub protocolsCheckProcessTypesAndSetIds {
  my ($self, $protocols) = @_;

  my $sql = "select name, process_type_id from $SCHEMA.processtype";

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
  return $protocols;
}

sub createGusStudy {
  my ($self, $extDbRlsId, $study) = @_;
  my $identifier = $study->getIdentifier();
  my $cleanedIdentifier = unidecode($identifier);
  # Remove punctuation and non-word characters
  $cleanedIdentifier =~ s/[^\w]/-/g;

  my $description = $study->getDescription();
  my $studyInternalAbbrev = $cleanedIdentifier;
  $studyInternalAbbrev =~ s/[-\.\s]/_/g; #clean name/id for use in oracle table name
  return $self->getGusModelClass('Study')->new({stable_id => $cleanedIdentifier, external_database_release_id => $extDbRlsId, internal_abbrev => $studyInternalAbbrev});
}
sub ifNeededUpdateStudyMaxAttrLength {
  my ($self, $gusStudy) = @_;
  if(! $gusStudy->getMaxAttrLength() || ($self->{_max_attr_value} //0) > $gusStudy->getMaxAttrLength()) {
    $gusStudy->setMaxAttrLength($self->{_max_attr_value});
    $gusStudy->submit();
  }
}

sub loadBatchOfStudyData {
  my ($self, $ontologyTermToIdentifiers, $ontologyTermToNames, $gusStudyId,
   $nodes, $protocols, $edges, $nodeToIdMap, $seenProcessMap) = @_;

  $self->loadNodes($ontologyTermToIdentifiers, $ontologyTermToNames, $nodes, $gusStudyId, $nodeToIdMap);
  my $processTypeNamesToIdMap = $self->loadProcessTypes($ontologyTermToIdentifiers, $protocols);
  $self->loadProcesses($ontologyTermToIdentifiers, $edges, $nodeToIdMap, $processTypeNamesToIdMap, $seenProcessMap, $ontologyTermToNames);

}


sub addEntityTypeForNode {
  my ($self, $ontologyTermToIdentifiers, $node, $gusStudyId) = @_;

  my $isaClassName = ref($node);
  my($isaType) = $isaClassName =~ /\:\:(\w+)$/;

  my $materialOrAssayType;
  if(blessed($node) eq 'CBIL::ISA::StudyAssayEntity::Assay' and $node->getStudyAssay()) {
    print STDERR "ASSAY!\n";
    $materialOrAssayType = $node->getStudyAssay()->getAssayMeasurementType(); 
  }
  else {
    print STDERR "NOT ASSAY!\n";
    $materialOrAssayType = $node->getMaterialType();
  }

  unless($materialOrAssayType) {
    print STDERR Dumper $node;
    $self->userError("Node of value " . $node->getValue . " missing material type - unable to set typeId");
  }

  my $mtKey = join("_", $materialOrAssayType->getTerm, $isaType);

  if($self->{_ENTITY_TYPE_IDS}->{$mtKey}) {
    return $self->{_ENTITY_TYPE_IDS}->{$mtKey};
  }

  my $entityType = $self->getGusModelClass('EntityType')->new();
  $entityType->setStudyId($gusStudyId);
  $entityType->setIsaType($isaType);

  my $gusOntologyTerm = $self->getOntologyTermGusObj($ontologyTermToIdentifiers, $materialOrAssayType, 0);
  $entityType->setTypeId($gusOntologyTerm->getId());
  $entityType->setName($gusOntologyTerm->getName());

  my $entityTypeInternalAbbrev = $entityType->getName();
  $entityTypeInternalAbbrev =~ s/([\w']+)/\u$1/g;
  $entityTypeInternalAbbrev =~ s/\W//g;
  $entityTypeInternalAbbrev = "entity_$entityTypeInternalAbbrev" if $entityTypeInternalAbbrev =~ m {^\d+};

  $entityType->setInternalAbbrev($entityTypeInternalAbbrev);

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
  

  if(scalar keys %{$self->{_attribute_units}->{$entityTypeId}->{$attrOntologyTermId}} > 1) {
    $self->error("Multiple Units found for EntityTypeId=$entityTypeId and AttributeOntologyTermId=$attrOntologyTermId");
  }

  
  my $attributeValue = $self->getGusModelClass('AttributeUnit')->new({entity_type_id => $entityTypeId, 
                                                              attr_ontology_term_id => $attrOntologyTermId,
                                                              unit_ontology_term_id => $unitOntologyTermId
                                                             });

  $attributeValue->submit(undef, 1);
}

sub updateMaxAttrValue {
  my ($self, $charValue) = @_;
  if( length $charValue > ($self->{_max_attr_value}//0)) {
    $self->{_max_attr_value} = length $charValue;
  }
}

sub loadNodes {
  my ($self, $ontologyTermToIdentifiers, $ontologyTermToNames, $nodes, $gusStudyId, $nodeToIdMap) = @_;

  my $nodeCount = 0;
  $self->getDb()->manageTransaction(0, 'begin');

  foreach my $node (@$nodes) {
    my $charsForLoader = {};
    my $charsForLoaderUniqueValues = {};

    if($nodeToIdMap->{$node->getValue()}) {
      if($node->hasAttribute("Characteristic") && scalar @{$node->getCharacteristics()} > 0) {
        # Wojtek: this can happen if parsing study in batches, and a new batch contains a previously seen node
        #         I worked around it in MBioInsertEntityGraph with a $investigation->setRowLimit(999999999); 
        $self->log("Characteristics for node ". $node->getValue() . " were defined on multiple rows.  Only loading the first");
      }
      next;
    }

    my $entity = $self->getGusModelClass('EntityAttributes')->new({stable_id => $node->getValue()});

    my $entityTypeId = $self->addEntityTypeForNode($ontologyTermToIdentifiers, $node, $gusStudyId);

    my $characteristics = $node->getCharacteristics() // [];
    foreach my $characteristic (@$characteristics) {

      my ($charQualifierSourceId, $charValue);

      if ($characteristic->getQualifier =~ m{ncbitaxon}i && !$self->getArg('useOntologyTermTableForTaxonTerms')){
          # taxon id Wojtek: I think we don't want that
          # $charQualifierSourceId = $ontologyTermToIdentifiers->{QUALIFIER}->{$characteristic->getQualifier};
          # stable id
          $charQualifierSourceId = $characteristic->getQualifier;
          $charValue = $characteristic->getTerm();
      } else { # usual case

        my $charQualifierOntologyTerm = $self->getOntologyTermGusObj($ontologyTermToIdentifiers, $characteristic, 1);
  
        $charQualifierSourceId = $charQualifierOntologyTerm->getSourceId();
  
        if($characteristic->getUnit()) {
          my $unitOntologyTerm = $self->getOntologyTermGusObj($ontologyTermToIdentifiers, $characteristic->getUnit(), 0);
          $self->addAttributeUnit($entityTypeId, $charQualifierOntologyTerm->getId(), $unitOntologyTerm->getId());
        }
  
        if($characteristic->getTermAccessionNumber() && $characteristic->getTermSourceRef()) { #value is ontology term

          if($characteristic->getTermSourceRef() eq 'NCBITaxon' && !$self->getArg('useOntologyTermTableForTaxonTerms')) {
            my $valueTaxonName = $self->getTaxonNameGusObj($ontologyTermToIdentifiers, $characteristic, 0);
            $charValue = $valueTaxonName->getName();
          }
          else {
            my $valueOntologyTerm = $self->getOntologyTermGusObj($ontologyTermToIdentifiers, $characteristic, 0);
            $charValue = $valueOntologyTerm->getName();
          }
        }
        else {
          $charValue = $characteristic->getTerm();
        }
      }

      if (ref $charValue eq 'HASH'){
        #MBio children
        $charsForLoader->{$charQualifierSourceId} = [$charValue];
        for my $v (values %$charValue){
           
          $self->updateMaxAttrValue(ref $v eq 'ARRAY' ? $v->[1] : ref $v ? die "Unexpected ref: " . ref $v :  $v);
        }
      } else {
        die "Unexpected ref type? " . ref $charValue if ref $charValue;
        $charValue =~ s/\r//;
        $self->updateMaxAttrValue($charValue);
        $charsForLoaderUniqueValues->{$charQualifierSourceId}->{$charValue}=1;

      }
      
    }
    # Convert hashref to arrayref
    # makes sure there is no duplicates
    while(my ($charQualifierSourceId,$charValuesHashref) = each %$charsForLoaderUniqueValues){
      my @charValues = keys %$charValuesHashref;
      $charsForLoader->{$charQualifierSourceId} = \@charValues;
    }

    $self->addGeohashAndGadm($charsForLoader,$ontologyTermToIdentifiers);  # TO DO: $ontologyTermToIdentifiers not used, remove?

    my $atts = encode_json($charsForLoader);
    $atts = decode("UTF-8", $atts);

    $entity->setAtts($atts) unless($atts eq '{}');
    $entity->setEntityTypeId($entityTypeId);
    ## NEVER load empty JSON - avoids having to cull this from the loadAttributes() query in ::LoadAttributesFromEntityGraph

    my $entityClassification = $self->getGusModelClass('EntityClassification')->new({entity_type_id => $entityTypeId});
    $entityClassification->setParent($entity);

    $entity->submit(undef, 1);

    $nodeToIdMap->{$entity->getStableId()} = [$entity->getId(), $entity->getEntityTypeId()];

    $self->undefPointerCache();

    if(++$nodeCount % 1000 == 0) {
      $self->getDb()->manageTransaction(0, 'commit');
      #$self->log("Loaded $nodeCount nodes");
      $self->getDb()->manageTransaction(0, 'begin');
    }
  }

  $self->getDb()->manageTransaction(0, 'commit');
  #$self->log("Loaded $nodeCount nodes");
}

sub addGeohashAndGadm {
  my ($self, $hash, $ontologyTermToIdentifiers) = @_;

  my $geohashLength = scalar @GEOHASH_SOURCE_IDS;

  my $latitudeSourceId = ${ApiCommonData::Load::StudyUtils::latitudeSourceId};
  my $longitudeSourceId = ${ApiCommonData::Load::StudyUtils::longitudeSourceId};

  return unless(defined($hash->{$latitudeSourceId}) && defined($hash->{$longitudeSourceId}));

  my $geohash = $self->encodeGeohash($hash->{$latitudeSourceId}->[0], $hash->{$longitudeSourceId}->[0], $geohashLength);

  for my $n (1 .. $geohashLength) {
    my $subvalue = substr($geohash, 0, $n);         
    my $geohashSourceId = $GEOHASH_SOURCE_IDS[$n - 1];


    unless($geohashSourceId) {
      print Dumper \@GEOHASH_SOURCE_IDS;
      print Dumper $GEOHASH_PRECISION;
      $self->error("Could not determine geohashSourceId for geohash=$geohash and length=$n")
    }


    $hash->{$geohashSourceId} = [$subvalue];
  }
  if ($self->getArg('gadmDsn')) {
    $self->addLookedUpPlacenames($hash);
  }


}

sub encodeGeohash {
  my($self, $latitude, $longitude, $precision ) = @_;
  my @Geo32 = qw/0 1 2 3 4 5 6 7 8 9 b c d e f g h j k m n p q r s t u v w x y z/;
  my @coord = ($latitude, $longitude);
  my @range = ([-90, 90], [-180, 180]);
  my($which,$value) = (1, '');
  while (length($value) < $precision * 5) {
      my $tot = 0;
      $tot += $_ for @{$range[$which]};
      my $mid = $tot / 2;
      $value .= my $upper = $coord[$which] <= $mid ? 0 : 1;
      $range[$which][$upper ? 0 : 1] = $mid;
      $which = $which ? 0 : 1;
  }
  my $enc;
  my $start = 0;
  my @valArr = split('', $value);
  my $end = $#valArr;
  while($start < $end){
    my @n = @valArr[$start..$start+4];
      $enc .= $Geo32[ord pack 'B8', '000' . join '', @n]; # binary to decimal, very specific to the task
    $start += 5;
  }
  return $enc
}

sub addLookedUpPlacenames {
  my ($self, $hash) = @_;

  # find $lat and $long from $hash
  my $latitudeSourceId = ${ApiCommonData::Load::StudyUtils::latitudeSourceId};
  my $longitudeSourceId = ${ApiCommonData::Load::StudyUtils::longitudeSourceId};
  my $maxAdminLevelSourceId = ${ApiCommonData::Load::StudyUtils::maxAdminLevelSourceId};

  my ($lat, $long) = ($hash->{$latitudeSourceId}[0], $hash->{$longitudeSourceId}[0]);
  return unless(defined $lat && defined $long);

  # maxAdminLevel is a per row value the data provider can use to control how many levels of placenames
  # are looked up. It's OK to be undefined, will fall back to default (2) in lookup method:

  my $maxAdminLevel;
  if($hash->{$maxAdminLevelSourceId}) {
    $maxAdminLevel = $hash->{$maxAdminLevelSourceId}[0];
  }

  my ($gadm_names, $gadm_ids, $veugeo_names) = @{$self->{_geolookup}->lookup($lat, $long, $maxAdminLevel)};
  foreach (my $level = 0; $level < @{$gadm_names}; $level++) {
    next unless(defined $gadm_names->[$level]);
    my $variable_iri = ${ApiCommonData::Load::StudyUtils::adminLevelSourceIds}[$level];
    if ($variable_iri) {
      ### TODO: find disambiguated name with vgeo
      $hash->{$variable_iri} = [ $gadm_names->[$level] ];
    }
  }
}

sub getTaxonNameGusObj {
  my ($self, $ontologyTermToIdentifiers, $ontologyTerm) = @_;

  my $ontologyTermAccessionNumber = $ontologyTerm->getTermAccessionNumber() || "";
  my $ontologyTermSourceRef = $ontologyTerm->getTermSourceRef() || "";

  unless($ontologyTermAccessionNumber && $ontologyTermSourceRef) {
    $self->error("OntologyTermAccessionNumber is required for NCBI Taxon Id Lookup");
  }

  my $taxonId = $ontologyTermToIdentifiers->{$ontologyTermSourceRef}->{$ontologyTermAccessionNumber};

  $self->error("No Taxon ID for $ontologyTermAccessionNumber|$ontologyTermSourceRef") unless $taxonId;

  if(my $gusObj = $self->{_gus_taxonname_objects}->{$taxonId}) {
    return $gusObj;
  }

  my $gusTaxonName = GUS::Model::SRes::TaxonName->new({taxon_id => $taxonId, name_class => 'scientific name'});

  unless($gusTaxonName->retrieveFromDB()) {
    $self->error("ERROR:  Could not fine taxonname for taxon_id $taxonId; $ontologyTermAccessionNumber");
  }

  $self->{_gus_taxonname_objects}->{$taxonId} = $gusTaxonName;
  return $gusTaxonName;
}

sub getOntologyTermGusObj {
    my ($self, $ontologyTermToIdentifiers, $ontologyTerm, $useQualifier) = @_;

    my $ontologyTermTerm = $ontologyTerm->getTerm() || "";
    my $ontologyTermClass = blessed($ontologyTerm) || "";
    my $ontologyTermAccessionNumber = $ontologyTerm->getTermAccessionNumber() || "";
    my $ontologyTermSourceRef = $ontologyTerm->getTermSourceRef() || "";

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
      $self->userError("OntologyTerm of class $ontologyTermClass and value [$ontologyTermTerm] must provide accession&source OR a qualifier in the case of Characteristics must map to an ontologyterm");
    }


    if(my $gusObj = $self->{_gus_ontologyterm_objects}->{$ontologyTermId}) {
      return $gusObj;
    }

    my $gusOntologyTerm;
    if(uc($SCHEMA) eq 'APIDBUSERDATASETS' && $self->getArg("userDatasetId")) {
      $gusOntologyTerm = GUS::Model::ApidbUserDatasets::OntologyTerm->new({ontology_term_id => $ontologyTermId});
    }
    else {
      $gusOntologyTerm = GUS::Model::SRes::OntologyTerm->new({ontology_term_id => $ontologyTermId});
    }

    unless($gusOntologyTerm->retrieveFromDB()) {
      print Dumper $ontologyTerm;

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
      $gusProcessType = $self->getGusModelClass('ProcessType')->new({name => $protocolName, description => $protocolDescription});

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
    my $gusProcessType = $self->getGusModelClass('ProcessType')->new({name => $protocolName});
    $gusProcessType->submit(undef, 1);

    $gusProcessTypeId = $gusProcessType->getId();

    $processTypeNamesToIdMap->{$protocolName} = $gusProcessTypeId;
    for (my $i=0; $i<@seriesProtocolNames; $i++) {
      my $processTypeComponent = $self->getGusModelClass('ProcessTypeComponent')->new({order_num => $i+1});
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
  my ($self,$ontologyTermToIdentifiers, $process, $nodeNameToIdMap, $ontologyTermToNames) = @_;

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

    if(my $protocolSourceId = $self->getArg('protocolVariableSourceId')) {
#      push @{$rv{$protocolSourceId}}, $protocolName; #this is not reliable

       my $protocolType = $protocol->getProtocolType();
       my $protocolTypeSourceId = $protocolType->getTermAccessionNumber();
       my $protocolTypeOntologyValue = $ontologyTermToNames->{$protocolTypeSourceId};

       $self->error("No Ontology term found for protocol type source id:  $protocolTypeSourceId") unless($protocolTypeOntologyValue);

       #my $protocolTypeValue = $protocolType->getTerm(); # this is not reliable

       # :tada: :crossed_fingers:
       push @{$rv{$protocolSourceId}}, $protocolTypeOntologyValue;

       $self->updateMaxAttrValue($protocolTypeOntologyValue);
    }

    # if($self->getArg('loadProtocolTypeAsVariable')) {
    #   my $protocolType = $protocol->getProtocolType();
    #   my $protocolTypeSourceId = $protocolType->getTermAccessionNumber();
    #   my $protocolTypeValue = $protocolType->getTerm();
    #   push @{$rv{$protocolTypeSourceId}}, $protocolTypeValue;
    # }

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
      
      $self->updateMaxAttrValue($ppValue);
    }
  }
  return \%rv;
}



sub loadProcesses {
  my ($self, $ontologyTermToIdentifiers, $processes, $nodeNameToIdMap, $processTypeNamesToIdMap, $seenProcessMap, $ontologyTermToNames) = @_;

  my $processCount = 0;
  $self->getDb()->manageTransaction(0, 'begin');

  foreach my $process (@$processes) {
    my $gusProcessTypeId = $self->getOrMakeProcessTypeId($process, $processTypeNamesToIdMap);

    my $processAttributesHash = $self->getProcessAttributesHash($ontologyTermToIdentifiers, $process, $nodeNameToIdMap, $ontologyTermToNames);

    my $atts = encode_json($processAttributesHash);
    $atts = decode("UTF-8", $atts);
    if($atts eq '{}'){ $atts = undef }
      ## NEVER load empty JSON - avoids having to cull this from the loadAttributes() query in ::LoadAttributesFromEntityGraph

    foreach my $output (@{$process->getOutputs()}) {
      my $outputName = $output->getValue();
      foreach my $input (@{$process->getInputs()}) {
        my $inputName = $input->getValue();

        next if($seenProcessMap->{$outputName} && $seenProcessMap->{$outputName}->{$inputName});

        my $inId = $self->getGusEntityId($input, $nodeNameToIdMap);
        my $outId = $self->getGusEntityId($output, $nodeNameToIdMap);

        my $gusProcessAttributes = $self->getGusModelClass('ProcessAttributes')->new({process_type_id => $gusProcessTypeId, 
                                                                        in_entity_id => $inId,
                                                                        out_entity_id => $outId,
                                                                        atts => $atts,
                                                                       });

        $gusProcessAttributes->submit(undef, 1);
        $self->undefPointerCache();

        if(++$processCount % 1000 == 0) {
          $self->getDb()->manageTransaction(0, 'commit');
          # $self->log("Loaded $processCount processes");
          $self->getDb()->manageTransaction(0, 'begin');
        }

        $seenProcessMap->{$outputName}->{$inputName}++;
      }
    }
  }

  $self->getDb()->manageTransaction(0, 'commit');
  $self->log("Loaded $processCount processes");
}

sub checkOntologyTermsAndFetchIds {
  my ($self, $iOntologyTermAccessionsHash) = @_;

  my $ncbiTaxon = 'ncbitaxon%';
  if($self->getArg('useOntologyTermTableForTaxonTerms')) {
    $ncbiTaxon = 'PREFIX_WE_DONT_WANT';
  }



  my $sql = "select 'OntologyTerm', ot.source_id, ot.ontology_term_id id, name
from ${TERM_SCHEMA}.ontologyterm ot
where ot.source_id = ?
and lower(ot.source_id) not like '$ncbiTaxon'
UNION
select 'NCBITaxon', 'NCBITaxon_' || t.ncbi_tax_id, t.taxon_id id, tn.name
from sres.taxon t, sres.taxonname tn
where 'NCBITaxon_' || t.ncbi_tax_id = ?
and lower(?) like  '$ncbiTaxon'
and t.taxon_id = tn.taxon_id
and tn.name_class = 'scientific name'
";


  # ensure the database has the geo hash ids
  if(defined($iOntologyTermAccessionsHash->{QUALIFIER}->{OBI_0001620}) && defined($iOntologyTermAccessionsHash->{QUALIFIER}->{OBI_0001621})){
    foreach(@GEOHASH_SOURCE_IDS) {
      $iOntologyTermAccessionsHash->{"QUALIFIER"}->{$_}++;
    }
  }
  # TO DO?
  # check that $latitudeSourceId, $longitudeSourceId
  # and @adminLevelSourceIds
  # are in the database?
  # presumably these are only needed if geohashing
  # or geocoding is needed (if $shapeFilesDirectory is defined)

  my $dbh = $self->getQueryHandle();
  my $sh = $dbh->prepare($sql);

  my $ontologyTermToIdentifiers = {};
  my $ontologyTermToNames = {};

  my @multipleCounts;
  my @missingTerms;

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
        $ontologyTermToNames->{$ota} = $ontologyTermName;
      }
      elsif($count > 1) {
        push (@multipleCounts, "$accessionOrName ($ota)");
      } else {
        push (@missingTerms, "$accessionOrName ($ota)");
      }
    }
  }
  if(@multipleCounts or @missingTerms){
    my $msg = "checkOntologyTermsAndFetchIds FAILED";
    $msg .= "\nTerms with multiple records: " . join (", ", @multipleCounts) if @multipleCounts;
    $msg .= "\nTerms missing from the database: " . join (", ", @missingTerms) if @missingTerms;
    $self->userError($msg);
  }
  return $ontologyTermToIdentifiers, $ontologyTermToNames;
}

sub updateEntityCardinality {
  my ($self, $gusStudyId) = @_;
  my $gusEntityType = $self->getGusModelClass('EntityType');
  return unless ($gusEntityType->new()->can('getCardinality'));
  my $dbh = $self->getQueryHandle();
  my $sql = "SELECT et.ENTITY_TYPE_ID, COUNT(1) from EDA.EntityType et LEFT JOIN EDA.EntityAttributes ea on et.Entity_Type_Id = ea.Entity_Type_Id where STUDY_ID=? GROUP BY et.ENTITY_TYPE_ID";
  my $sh = $dbh->prepare($sql);
  $sh->execute($gusStudyId);
  while(my ($entityTypeId, $count) = $sh->fetchrow_array()) {
    my $et = $gusEntityType->new({entity_type_id => $entityTypeId});
    if($et->retrieveFromDB()){
      $et->setCardinality($count);
      $et->submit();
    }
  }
}

1;

