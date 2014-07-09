package ApiCommonData::Load::IsolateVocabulary::Reader::VocabFileReader;
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

sub new {
  my ($class, $vocabFile) = @_;

  my $args = {};

  my $self = bless $args, $class; 

  $self->setVocabFile($vocabFile);

  return $self;
}

sub getVocabFile {$_[0]->{vocabFile}}
sub setVocabFile {
  my ($self, $vocabFile) = @_;

  if(-e $vocabFile) {
    $self->{vocabFile} = $vocabFile;
  }
  else {
    die "vocabFile [$vocabFile] Does not exist";
  }
}

sub extract {
  my ($self) = @_;

  open(F, $self->getVocabFile()) || die "Can't open vocab file for reading";

  my $vocab;

  while(<F>) {
    chomp;
    my @line = split(/\t/);
    scalar(@line) == 3 || die "invalid line in vocab file";

    my $term = $line[0];
    my $type = $line[2];

    die "duplicate ($type, $term) in vocab file line $.\n" if $vocab->{$type}->{$term};
    $vocab->{$type}->{$term} = 1;
  }

  close F;

  return $vocab;
}


1;
