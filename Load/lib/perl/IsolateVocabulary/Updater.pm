package ApiCommonData::Load::IsolateVocabulary::Updater;

use strict;
use Carp;

use Data::Dumper;

use ApiCommonData::Load::IsolateVocabulary::Utils;

sub getTerms {$_[0]->{terms}}
sub setTerms {$_[0]->{terms} = $_[1]}

sub getGusConfigFile {$_[0]->{gusConfigFile}}
sub setGusConfigFile {$_[0]->{gusConfigFile} = $_[1]}

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


sub new {
  my ($class, $gusConfigFile, $type, $terms) = @_;

  my $args = {};

  my $self = bless $args, $class; 

  $self->setGusConfigFile($gusConfigFile);

  my $dbh = ApiCommonData::Load::IsolateVocabulary::Utils::createDbh($gusConfigFile);

  $self->setDbh($dbh);
  $self->setType($type);
  $self->setTerms($terms);

  return $self;
}

sub update {
  my ($self) = @_;

  my $updateCounts;

  my $dbh = $self->getDbh();

  # ensure the terms in the mapping file are valid
  $self->checkOntology();

  # create a data structure:   @naSequenceIds = @{$hash{$table}->{$field}->{$value}}
  my $existingIsolateValues = $self->queryForExisting();

  foreach my $term (@{$self->getTerms()}) {
    my $table = $term->getTable();
    my $field = uc($term->getField());
    my $value = $term->getValue();

    my $maps = $term->getMaps();

    unless($existingIsolateValues->{$table}->{$field}->{$value}) {
      print STDERR "WARNING:  Term [$value] for Table [$table] and field [$field] was not found in the database.\n";      
      next;
    }

    my @naSequenceIds = @{$existingIsolateValues->{$table}->{$field}->{$value}};

    foreach my $map (@$maps) {
      my $mapTable = $map->getTable();
      my $mapField = $map->getField();
      my $mapValue = $map->getValue();

      $mapValue =~ s/\'//g;

      my $updateSql = "update dots.$mapTable set $mapField = '$mapValue', modification_date = sysdate where na_sequence_id = ?";

      unless($mapValue) {
        print STDERR Dumper $term;
        croak "ERROR.  MAP Value cannot be null";
      }

      unless(scalar @naSequenceIds > 0) {
        print STDERR Dumper $term;
        croak "ERROR.  No NaSequenceIds found for term";
      }

      my $updateSh = $dbh->prepare($updateSql);

      foreach my $naSequenceId (@naSequenceIds) {
        $updateSh->execute($naSequenceId);

        my $rows = $updateSh->rows();
        $updateCounts = $updateCounts + $rows;
      }

      $updateSh->finish();
    }
  }

  $self->disconnect();
  print STDERR "Updated $updateCounts rows in Dots.IsolateSource Or IsolateFeature\n";
}


sub queryForExisting {
  my ($self) = @_;

  my $data = {};

  my %all_sql = ('IsolateFeature' => <<Sql,
select distinct na_sequence_id, product from dots.isolatefeature
Sql
             'IsolateSource' => <<Sql,
select distinct na_sequence_id, country, specific_host, isolation_source from dots.isolatesource
Sql
             'ExternalNaSequence' => <<Sql,
select distinct s.na_sequence_id, s.source_id from dots.nasequence s, dots.isolatesource i where i.na_sequence_id = s.na_sequence_id
Sql
            );

  my @tables = ('IsolateFeature', 'IsolateSource', 'ExternalNaSequence');

  my $dbh = $self->getDbh();

  foreach my $table (@tables) {
    my $sql = $all_sql{$table};
    my $sh = $dbh->prepare($sql);
    $sh->execute();

    while(my $row = $sh->fetchrow_hashref) {
      my $naSequenceId = $row->{NA_SEQUENCE_ID};

      foreach my $field (keys %$row) {
        my $rowValue = $row->{$field};

        unless($field eq 'NA_SEQUENCE_ID') {
          push @{$data->{$table}->{$field}->{$rowValue}}, $naSequenceId;
        }
      }
    }
    $sh->finish();
  }
  return $data;
}

sub checkOntology {
  my ($self) = @_;

  my $existingOntology = $self->getAllOntologies();

  foreach my $term (@{$self->getTerms}) {
    my $maps = $term->getMaps();
    my $value = $term->getValue();

    unless($term->isValid(1)) {
      print STDERR Dumper $term;
      croak "Term [$value] is NOT valid";
    }

    foreach my $map (@$maps) {
      my $mapField = $map->getField();
      my $mapValue = $map->getValue();

      my ($ontologyTerm, $extra) = split(':', $mapValue);

      unless($self->isIncluded($existingOntology->{$ontologyTerm}, $mapField)) {
        croak "No valid ontology for term [$ontologyTerm] of type [$mapField]";
      }
    }
  }
}


sub isIncluded {
  my ($self, $a, $v) = @_;

  unless($a) {
    return 0;
  }

  foreach(@$a) {
    return 1 if $v eq $_;
  }
  return 0;
}


sub getAllOntologies {
  my ($self)  = @_;

  my $dbh = $self->getDbh();

  my $sql = "select term, type from apidb.isolatevocabulary";
  my $sh = $dbh->prepare($sql);
  $sh->execute();

  my %res;

  while(my ($term, $type) = $sh->fetchrow_array()) {
    $type = 'country' if($type eq 'geographic_location');
    push @{$res{$term}}, $type;
  }
  $sh->finish();

  return \%res;
}

1;
