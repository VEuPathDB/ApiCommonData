package ApiCommonData::Load::IsolateVocabulary::Reader::XmlTermReader;
#vvvvvvvvvvvvvvvvvvvvvvvvv GUS4_STATUS vvvvvvvvvvvvvvvvvvvvvvvvv
  # GUS4_STATUS | SRes.OntologyTerm              | auto   | absent
  # GUS4_STATUS | SRes.SequenceOntology          | auto   | absent
  # GUS4_STATUS | Study.OntologyEntry            | auto   | absent
  # GUS4_STATUS | SRes.GOTerm                    | auto   | absent
  # GUS4_STATUS | Dots.RNAFeatureExon            | auto   | absent
  # GUS4_STATUS | RAD.SageTag                    | auto   | absent
  # GUS4_STATUS | RAD.Analysis                   | auto   | absent
  # GUS4_STATUS | ApiDB.Profile                  | auto   | absent
  # GUS4_STATUS | Study.Study                    | auto   | absent
  # GUS4_STATUS | Dots.Isolate                   | auto   | absent
  # GUS4_STATUS | DeprecatedTables               | auto   | absent
  # GUS4_STATUS | Pathway                        | auto   | absent
  # GUS4_STATUS | DoTS.SequenceVariation         | auto   | absent
  # GUS4_STATUS | RNASeq Junctions               | auto   | absent
  # GUS4_STATUS | Simple Rename                  | auto   | absent
  # GUS4_STATUS | ApiDB Tuning Gene              | auto   | absent
  # GUS4_STATUS | Rethink                        | auto   | absent
  # GUS4_STATUS | dots.gene                      | manual | unreviewed
die 'This file has broken or unreviewed GUS4_STATUS rules.  Please remove this line when all are fixed or absent';
#^^^^^^^^^^^^^^^^^^^^^^^^^ End GUS4_STATUS ^^^^^^^^^^^^^^^^^^^^
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
    my $original = $node->{original}->[0];
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

