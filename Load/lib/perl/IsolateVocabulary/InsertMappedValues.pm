package ApiCommonData::Load::IsolateVocabulary::InsertMappedValues;

use strict;
use Carp;

use Data::Dumper;

use ApiCommonData::Load::IsolateVocabulary::Utils;
use ApiCommonData::Load::IsolateVocabulary::VocabularyTerm;

use GUS::Model::ApiDB::VocabularyBiomaterial;
use GUS::Model::ApiDB::IsolateMapping;

sub getSqlTerms {$_[0]->{_sql_terms}}
sub setSqlTerms {$_[0]->{_sql_terms} = $_[1]}

sub getXmlMapTerms {$_[0]->{_xml_map_terms}}
sub setXmlMapTerms {$_[0]->{_xml_map_terms} = $_[1]}

sub setVocabulary {$_[0]->{_vocabulary} = $_[1]}
sub getVocabulary {$_[0]->{_vocabulary}}

sub getDbh {$_[0]->getPlugin()->getDbHandle() }

sub getType {$_[0]->{_type}}
sub setType {
  my ($self, $type) = @_;

  unless(ApiCommonData::Load::IsolateVocabulary::Utils::isValidType($type)) {
    croak "Type $type is not supported";
  }

  $self->{_type} = $type;  
}

sub getPlugin {$_[0]->{Plugin}}
sub setPlugin {$_[0]->{Plugin} = $_[1]}

sub new {
  my ($class, $plugin, $type, $xmlTerms, $sqlTerms, $vocabulary) = @_;

  my $args = {};

  my $self = bless $args, $class; 

  $self->setType($type);
  $self->setXmlMapTerms($xmlTerms);
  $self->setSqlTerms($sqlTerms);
  $self->setPlugin($plugin);
  $self->setVocabulary($vocabulary);

  return $self;
}

sub mapTableIdTypeLookup {
  my ($self, $mapTable) = @_;

  if($mapTable eq 'IsolateSource') {
    return 'na_sequence_id';
  }

  if($mapTable eq 'OntologyEntry') {
    return 'bio_material_id';
  }

  die "Map Table $mapTable must be either [IsolateSource or OntologyEntry]";
}

sub insert {
  my ($self) = @_;

  my $dbh = $self->getDbh();

  # $isolateVocabularyId = $hash->{$type}->{$term}
  my $isolateVocabularyIds =  $self->getVocabulary();

  # create a data structure for loaded isolates and their primary key
  #    @identifiers = @{$hash{$idType}->{$type}->{$originalTerm}}
  my $isolateTermIdentifiers = $self->queryLoadedIsolates();

  # insert mapping for terms which don't require manual mapping (ie. the value in the dots table == value in apidb table)
  my $automaticCounts = $self->insertAutomaticTerms($isolateTermIdentifiers, $isolateVocabularyIds);

  # insert mapping for manual terms (from xml mapping file)
  my $manualCounts = $self->insertManuallyMappedTerms($isolateTermIdentifiers, $isolateVocabularyIds);

  my $mappingTotalCount = $automaticCounts + $manualCounts;

  return ($mappingTotalCount, "Inserted $automaticCounts automatic counts and $manualCounts manual counts (total=$mappingTotalCount)");
}

# for terms where original is null, map to the term "unkown"
sub insertNullMappedTerms {
  my ($self) = @_;

  my $isolateVocabularyIds =  $self->getVocabulary();
  my $dotsIsolatesNaSequences = $self->queryLoadedIsolates();


  my $count;

  my $type = $self->getType();
  my $term = 'Unknown';

  my $vocabTerm = ApiCommonData::Load::IsolateVocabulary::VocabularyTerm->new($term, '', '', $type, $type, 1);

  my $isolateVocabularyId = $isolateVocabularyIds->{$type}->{$term};

  my $naSequenceIds = $self->queryForNullNaSequences($type);

  $count = $count + $self->doMappingInsert($vocabTerm, $isolateVocabularyId, $naSequenceIds, 'na_sequence_id');

  # Check that every biomaterial has specific_host, source, and geographic_location
  # These may be Unknown ... but we are requiring each biomaterial to put something for these
  $self->checkForNullBioMaterials();

  return $count;
}

sub checkForNullBioMaterials {
  my ($self) = @_;

  my @bioMaterialIds;

my $sql = "select bio_material_id
from study.biomaterialcharacteristic bc, study.ontologyentry oe
where oe.ontology_entry_id = bc.ontology_entry_id
and oe.category in ('Host', 'GeographicLocation', 'BioSourceType')
group by bio_material_id
having count(*) != 3";

  my $dbh = $self->getDbh();
  my $sh = $dbh->prepare($sql);
  $sh->execute();

  while(my ($b) = $sh->fetchrow_array()) {
    push @bioMaterialIds, $b;
  }
  $sh->finish();

  if(scalar @bioMaterialIds > 0) {
    die "Not all biomaterials have been matched to vocabulary terms";
  }
}


sub queryForNullNaSequences {
  my ($self, $type) = @_;

  my @naSequenceIds;

  my $sql = "select s.na_sequence_id
from dots.isolatesource s 
  left join (select im.*
             from apidb.isolatevocabulary v, apidb.isolatemapping im
             where v.isolate_vocabulary_id = im.isolate_vocabulary_id
             and v.type = ?
             ) im
  on s.na_sequence_id = im.na_sequence_id
where im.na_sequence_id is null";

  my $dbh = $self->getDbh();
  my $sh = $dbh->prepare($sql);
  $sh->execute($type);

  while(my ($naSequenceId) = $sh->fetchrow_array()) {
    push @naSequenceIds, $naSequenceId;
  }
  $sh->finish();

  return \@naSequenceIds;
}


sub insertManuallyMappedTerms {
  my ($self, $allIsolateIds, $vocabularyIds) = @_;

  my $count;

  foreach my $xmlTerm (@{$self->getXmlMapTerms()}) {

    my $term = $xmlTerm->getTerm();
    my $mapTerm = $xmlTerm->getMapTerm();
    my $table = $xmlTerm->getTable();
    my $field = $xmlTerm->getField();
    my $type = $xmlTerm->getType();

    my $idType = $self->mapTableIdTypeLookup($table);

    # Get na_sequence_id or bio_material_id for the orig, BUT isolate vocabulary id for the mapTerm
    my $isolateVocabularyId = $vocabularyIds->{$type}->{$mapTerm};
    my $isolateIds = $allIsolateIds->{$idType}->{lc($field)}->{$term};

    next if (!$isolateIds);
    $count = $count + $self->doMappingInsert($xmlTerm, $isolateVocabularyId, $isolateIds, $idType);
  }
  return $count;
}

sub insertAutomaticTerms {
  my ($self, $allIsolateIds, $vocabularyIds) = @_;

  my $count;

# idType type term

  foreach my $sqlTerm (@{$self->getSqlTerms()}) {
    next unless($sqlTerm->getAlreadyMaps());

    my $term = $sqlTerm->getTerm();
    my $table = $sqlTerm->getTable();
    my $field = $sqlTerm->getField();
    my $type = $sqlTerm->getType();

    my $idType = $self->mapTableIdTypeLookup($table);

    # Get na_sequence_id or bio_material_id && vocab_id for the orig
    my $isolateVocabularyId = $vocabularyIds->{$type}->{$term};
    my $isolateIds = $allIsolateIds->{$idType}->{lc($type)}->{$term};

    $count = $count + $self->doMappingInsert($sqlTerm, $isolateVocabularyId, $isolateIds, $idType);

  }
  return $count;
}

sub doMappingInsert {
  my ($self, $term, $isolateVocabularyId, $isolateIds, $idType) = @_;

  my $count;

  my $plugin = $self->getPlugin();

  unless($isolateIds) {
    die "ERROR:  No $idType found for Term " . $term->toString();
  }

  unless($isolateVocabularyId) {
    die "ERROR:  No ISOLATE_VOCABULARY_ID for Term " . $term->toString();
  }

  foreach my $isolateId (@$isolateIds) {
    my $mapping;

    if($idType eq 'bio_material_id') {
      $mapping = GUS::Model::ApiDB::VocabularyBiomaterial -> new({BIO_MATERIAL_ID => $isolateId,
                                                                  ISOLATE_VOCABULARY_ID => $isolateVocabularyId});
    }

    if($idType eq 'na_sequence_id') {
      $mapping = GUS::Model::ApiDB::IsolateMapping -> new({NA_SEQUENCE_ID => $isolateId, 
                                                           ISOLATE_VOCABULARY_ID => $isolateVocabularyId});
    }

    $mapping->submit();
    $count++;
    $plugin->undefPointerCache();
  }
  return $count;
}


sub queryLoadedIsolates {
  my ($self) = @_;
  my $data = {};

my $sql = <<Sql;
select bc.bio_material_id as id, oe.value as term, 'bio_material_id' as id_type, 'specific_host' as type
from STUDY.ontologyentry oe, STUDY.biomaterialcharacteristic bc
where oe.ontology_entry_id = bc.ontology_entry_id
and oe.category = 'Host'
UNION
select bc.bio_material_id as id, oe.value as term, 'bio_material_id' as id_type, 'geographic_location' as type
from STUDY.ontologyentry oe, STUDY.biomaterialcharacteristic bc
where oe.ontology_entry_id = bc.ontology_entry_id
and oe.category = 'GeographicLocation'
UNION
select bc.bio_material_id as id, oe.value as term, 'bio_material_id' as id_type, 'isolation_source' as type
from STUDY.ontologyentry oe, STUDY.biomaterialcharacteristic bc
where oe.ontology_entry_id = bc.ontology_entry_id
and oe.category = 'BioSourceType'
UNION
select i.na_sequence_id as id, i.country as term, 'na_sequence_id' as id_type, 'geographic_location' as type
from dots.isolatesource i
union
select i.na_sequence_id as id, i.specific_host as term, 'na_sequence_id' as id_type, 'specific_host' as type
from dots.isolatesource i
union
select i.na_sequence_id as id, i.isolation_source as term, 'na_sequence_id' as id_type, 'isolation_source' as type
from dots.isolatesource i
Sql

  my $dbh = $self->getDbh();

  my $sh = $dbh->prepare($sql);
  $sh->execute();

  while(my $row = $sh->fetchrow_hashref) {
    my $id = $row->{ID};
    my $idType = $row->{ID_TYPE};
    my $term = $row->{TERM};
    my $type = $row->{TYPE};

    push @{$data->{$idType}->{$type}->{$term}}, $id;
  }
  $sh->finish();

  return $data;
}


1;
