package ApiCommonData::Load::IsolateVocabulary::InsertMappedValues;

use strict;
use Carp;

use Data::Dumper;

use ApiCommonData::Load::IsolateVocabulary::Utils;
use ApiCommonData::Load::IsolateVocabulary::VocabularyTerm;
use GUS::Model::ApiDB::IsolateMapping;

sub getSqlTerms {$_[0]->{_sql_terms}}
sub setSqlTerms {$_[0]->{_sql_terms} = $_[1]}

sub getXmlMapTerms {$_[0]->{_xml_map_terms}}
sub setXmlMapTerms {$_[0]->{_xml_map_terms} = $_[1]}

sub disconnect {$_[0]->{dbh}->disconnect()}

sub getDbh {$_[0]->{dbh}}
sub setDbh {$_[0]->{dbh} = $_[1]}

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
  my ($class, $plugin, $dbh, $type, $xmlTerms, $sqlTerms) = @_;

  my $args = {};

  my $self = bless $args, $class; 

  $self->setDbh($dbh);
  $self->setType($type);
  $self->setXmlMapTerms($xmlTerms);
  $self->setSqlTerms($sqlTerms);
  $self->setPlugin($plugin);

  return $self;
}

sub insert {
  my ($self) = @_;

  my $dbh = $self->getDbh();

  # create a data structure for all isolates in Dots Tables
  #    @naSequenceIds = @{$hash{$table}->{$field}->{$original}}
  my $dotsIsolatesNaSequences = $self->queryDotsIsolates();

  #    $isolateVocabularyId = $hash->{$type}->{$term}
  my $isolateVocabularyIds =  ApiCommonData::Load::IsolateVocabulary::Utils::getAllOntologies($dbh);

  # insert mapping for terms which don't require manual mapping (ie. the value in the dots table == value in apidb table)
  my $automaticCounts = $self->insertAutomaticTerms($dotsIsolatesNaSequences, $isolateVocabularyIds);

  # insert mapping for manual terms (from xml mapping file)
  my $manualCounts = $self->insertManuallyMappedTerms($dotsIsolatesNaSequences, $isolateVocabularyIds);

  # insert mapping for null/unknown terms
  my $nullCounts = $self->insertNullMappedTerms($dotsIsolatesNaSequences, $isolateVocabularyIds);

  my $mappingTotalCount = $automaticCounts + $manualCounts + $nullCounts;

  return ($mappingTotalCount, "Inserted $automaticCounts automatic counts, $manualCounts manual counts and $nullCounts null counts (total=$mappingTotalCount)");
}

# for terms where original is null, map to the term "unkown"
sub insertNullMappedTerms {
  my ($self, $dotsIsolatesNaSequences, $isolateVocabularyIds) = @_;

  my $count;

  my $type = $self->getType();
  my $term = 'Unknown';

  my $vocabTerm = ApiCommonData::Load::IsolateVocabulary::VocabularyTerm->new($term, '', '', $type, $type, 1);

  my $isolateVocabularyId = $isolateVocabularyIds->{$term}->{$type};

  my $naSequenceIds = $self->queryForNullNaSequences($type);

  $count = $count + $self->doMappingInsert($vocabTerm, $isolateVocabularyId, $naSequenceIds);

  return $count;
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
  my ($self, $dotsIsolatesNaSequences, $isolateVocabularyIds) = @_;

  my $count;

  foreach my $xmlTerm (@{$self->getXmlMapTerms()}) {

    my $term = $xmlTerm->getTerm();
    my $mapTerm = $xmlTerm->getMapTerm();
    my $table = $xmlTerm->getTable();
    my $field = $xmlTerm->getField();
    my $type = $xmlTerm->getType();

    # Get na_sequence_id for the orig, BUT isolate vocabulary id for the mapTerm
    my $isolateVocabularyId = $isolateVocabularyIds->{$mapTerm}->{$type};
    my $naSequenceIds = $dotsIsolatesNaSequences->{$table}->{uc($field)}->{$term};
    next if (!$naSequenceIds);
    $count = $count + $self->doMappingInsert($xmlTerm, $isolateVocabularyId, $naSequenceIds);
  }
  return $count;
}

sub insertAutomaticTerms {
  my ($self, $dotsIsolatesNaSequences, $isolateVocabularyIds) = @_;

  my $count;

  foreach my $sqlTerm (@{$self->getSqlTerms()}) {
    next unless($sqlTerm->getAlreadyMaps());

    my $term = $sqlTerm->getTerm();
    my $table = $sqlTerm->getTable();
    my $field = $sqlTerm->getField();
    my $type = $sqlTerm->getType();

    next if($type eq 'product');

    # Get na_sequence_id for the orig, AND isolate vocabulary id for the mapTerm
    my $isolateVocabularyId = $isolateVocabularyIds->{$term}->{$type};
    my $naSequenceIds = $dotsIsolatesNaSequences->{$table}->{uc($field)}->{$term};

    $count = $count + $self->doMappingInsert($sqlTerm, $isolateVocabularyId, $naSequenceIds);

  }
  return $count;
}

sub doMappingInsert {
  my ($self, $term, $isolateVocabularyId, $naSequenceIds) = @_;

  my $count;

  my $plugin=$self->getPlugin();

  unless($naSequenceIds) {
    die "ERROR:  No NA_SEQUENCE_ID for Term " . $term->toString();
  }

  unless($isolateVocabularyId) {
    die "ERROR:  No ISOLATE_VOCABULARY_ID for Term " . $term->toString();
  }

  foreach my $naSequenceId (@$naSequenceIds) {
      my $mapping = GUS::Model::ApiDB::IsolateMapping -> new({NA_SEQUENCE_ID => $naSequenceId, 
							      ISOLATE_VOCABULARY_ID => $isolateVocabularyId});
      $mapping->submit();
      $count++;
      $plugin->undefPointerCache();
  }

  return $count;
}


sub queryDotsIsolates {
  my ($self) = @_;

  my $data = {};

  my %all_sql = ('IsolateFeature' => <<Sql,
select distinct na_sequence_id, source_id, product from dots.isolatefeature
Sql
             'IsolateSource' => <<Sql,
select distinct na_sequence_id, country, specific_host, isolation_source from dots.isolatesource
Sql
# probably not needed anymore
             'ExternalNaSequence' => <<Sql,
select distinct s.na_sequence_id, s.source_id from dots.nasequence s, dots.isolatesource i where i.na_sequence_id = s.na_sequence_id
Sql
            );

  my @tables = ('IsolateFeature', 'IsolateSource',
		'ExternalNaSequence'
      );

  my $dbh = $self->getDbh();

  foreach my $table (@tables) {
    my $sql = $all_sql{$table};
    my $sh = $dbh->prepare($sql);
    $sh->execute();

    while(my $row = $sh->fetchrow_hashref) {
#      my $identifier = $table eq 'IsolateFeature' ? $row->{NA_FEATURE_ID} : $row->{NA_SEQUENCE_ID};
      my $identifier = $row->{NA_SEQUENCE_ID};

      foreach my $field (keys %$row) {
        my $rowValue = $row->{$field};

        unless($field eq 'NA_SEQUENCE_ID' || $field eq 'NA_FEATURE_ID') {
          push @{$data->{$table}->{$field}->{$rowValue}}, $identifier;
        }
      }
    }
    $sh->finish();
  }
  return $data;
}


1;
