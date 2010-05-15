package ApiCommonData::Load::IsolateVocabulary::Reader::XmlReader;
use base qw(ApiCommonData::Load::IsolateVocabulary::Reader);

use strict;
use Carp;

use Data::Dumper;

use XML::Simple;

use ApiCommonData::Load::IsolateVocabulary::VocabularyTerm;

sub getXmlFile {$_[0]->{xmlFile}}
sub setXmlFile {
  my ($self, $xmlFile) = @_;

  if(-e $xmlFile) {
    $self->{xmlFile} = $xmlFile;
  }
  else {
    croak "xmlFile $xmlFile Does not exist";
  }
}

sub new {
  my ($class, $xmlFile) = @_;

  my $args = {};

  my $self = bless $args, $class; 

  $self->setXmlFile($xmlFile);
  return $self;
}

sub extract {
  my ($self) = @_;

  my $xmlFile = $self->getXmlFile();
  my $root = XMLin($xmlFile, ForceArray => 1);

  my @vocabularyTerms;

  foreach my $node (@{$root->{initial}}) {
    my $original = $node->{original};
    my $table = $node->{table};
    my $field = $node->{field};

    foreach my $map (@{$node->{maps}->[0]->{row}}) {
      my $type = $map->{type};
      my $value = $map->{value};

      my $vocabTerm = ApiCommonData::Load::IsolateVocabulary::VocabularyTerm->new($original, $value, $table, $field, $type, 0);

      push @vocabularyTerms, $vocabTerm;
    }
  }

  return \@vocabularyTerms;
}

1;

