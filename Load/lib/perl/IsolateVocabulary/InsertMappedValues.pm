package ApiCommonData::Load::IsolateVocabulary::InsertMappedValues;

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

sub insert {
  my ($self) = @_;

  my $insertCounts;

  my $dbh = $self->getDbh();

  # ensure the terms in the mapping file are valid
  $self->checkOntology();

  my $currentVocabulary = $self->queryForVocabulary();

  my $insertSql = "insert into apidb.isolatevocabulary (term, original_term, type, source) values (?,?,?,?)";
  my $insert = $dbh->prepare($insertSql);

  my $source = 'mapping file';

  foreach my $term (@{$self->getTerms()}) {
    my $original = $term->getOriginal();
    my $value = $term->getValue();
    my $type = $term->getType();

    if($currentVocabulary->{$original} && $currentVocabulary->{$original}->{type} eq $type) {
      my $mappedValue = $currentVocabulary->{$original}->{term};
      print STDERR "SKIPPING:  Original Term [$original] for type [$type] already mapped to value: $mappedValue\n";
      next;
    }

    $insert->execute($value, $original, $type, $source);

    $insertCounts = $insertCounts + $insert->rows();
  }

  $self->disconnect();
  print STDERR "Inserted $insertCounts rows into apidb.isolatevocabulary\n";
}


sub queryForVocabulary {
   my ($self) = @_;

   my $dbh = $self->getDbh();

   my $sql = "select original_term, type, source, term from apidb.isolatevocabulary";

   my $sh = $dbh->prepare($sql);
   $sh->execute();

   my $rv = {};

   while(my ($original, $type, $source, $term) = $sh->fetchrow_array()) {
     $rv->{$original} = {type => $type, source => $source, term => $term};
   }
   $sh->finish();

   return $rv;
}

sub checkOntology {
  my ($self) = @_;

  my $existingOntology = $self->getAllOntologies();

  foreach my $term (@{$self->getTerms}) {
    my $value = $term->getValue();
    my $original = $term->getOriginal();
    my $type = $term->getType();

    unless($term->isValid()) {
      print STDERR Dumper $term;
      croak "Term [$original] is NOT valid";
    }

    unless($value) {
      croak "Value not defined for term [$original]";
    }

    unless($self->isIncluded($existingOntology->{$value}, $type)) {
      croak "No valid ontology for term [$value] of type [$type]";
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

  my $sql = "select distinct term, type from apidb.isolatevocabulary where source = 'isolate vocabulary'";
  my $sh = $dbh->prepare($sql);
  $sh->execute();

  my %res;

  while(my ($term, $type) = $sh->fetchrow_array()) {
#    $type = 'country' if($type eq 'geographic_location');
    push @{$res{$term}}, $type;
  }
  $sh->finish();

  return \%res;
}

1;
