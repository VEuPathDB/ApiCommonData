package ApiCommonData::Load::IsolateVocabulary::Reader::VocabFileReader;
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
