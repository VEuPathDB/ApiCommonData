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
    my $value = $node->{value};
    my $table = $node->{table};
    my $field = $node->{field};

    my $vocabTerm = ApiCommonData::Load::IsolateVocabulary::VocabularyTerm->new($value, $table, $field);

    foreach my $map (@{$node->{maps}->[0]->{row}}) {
      my $mapValue = $map->{value};
      my $mapTable = $map->{table};
      my $mapField = $map->{field};

      my $mapTerm = ApiCommonData::Load::IsolateVocabulary::VocabularyTerm->new($mapValue, $mapTable, $mapField);
      $vocabTerm->addMaps($mapTerm);
    }

    push @vocabularyTerms, $vocabTerm;
  }

  return \@vocabularyTerms;
}

1;

