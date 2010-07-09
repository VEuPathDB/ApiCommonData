package ApiCommonData::Load::IsolateVocabulary::Reader::VocabFileReader;
use base qw(ApiCommonData::Load::IsolateVocabulary::Reader);

use strict;
use Carp;

use ApiCommonData::Load::IsolateVocabulary::VocabularyTerm;
use ApiCommonData::Load::IsolateVocabulary::Utils;

sub getType {$_[0]->{_type}}

sub setType {
  my ($self, $type) = @_;

  unless(ApiCommonData::Load::IsolateVocabulary::Utils::isValidType($type)) {
    croak "Type $type is not supported";
  }

  $self->{_type} = $type;
}

sub new {
  my ($class, $vocabFile, $type) = @_;

  my $args = {};

  my $self = bless $args, $class;

  $self->setVocabFile($vocabFile);

  $self->setType($type);

  return $self;
}

sub getVocabFile {$_[0]->{vocabFile}}
sub setVocabFile {
  my ($self, $vocabFile) = @_;

  if(-e $vocabFile) {
    $self->{vocabFile} = $vocabFile;
  }
  else {
    croak "vocabFile $vocabFile Does not exist";
  }
}

sub extract {
  my ($self) = @_;

  my $queryField = $self->getType() eq 'geographic_location' ? 'country' : $self->getType();

  my @vocabTerms;
  open(F, $self->getVocabFile()) || die "Can't open vocab file for reading";
  while(<F>) {
    chomp;
    my @line = split(/\t/);
    scalar(@line) == 3 || die "invalid line in vocab file";
    my $term = $line[0];
    my $type = $line[2];
    my $vocabTerm = ApiCommonData::Load::IsolateVocabulary::VocabularyTerm->new($term, '', undef, $queryField, $type, 1);
    push @vocabTerms, $vocabTerm;
  }

  return \@vocabTerms;
}


1;

