package ApiCommonData::Load::IsolateVocabulary::Reader::VocabFileReader;
use base qw(ApiCommonData::Load::IsolateVocabulary::Reader);

# create VocabularyTerm objects for all terms found in loaded isolates.
# use provided vocab file to determine which terms are already known.

use strict;
use Carp;

use ApiCommonData::Load::IsolateVocabulary::VocabularyTerm;

use ApiCommonData::Load::IsolateVocabulary::Utils;

sub setDbh {$_[0]->{dbh} = $_[1]}
sub getDbh {$_[0]->{dbh}}

sub getType {$_[0]->{_type}}

sub setType {
  my ($self, $type) = @_;

  unless(ApiCommonData::Load::IsolateVocabulary::Utils::isValidType($type)) {
    croak "Type $type is not supported";
  }

  $self->{_type} = $type;  
}

sub new {
  my ($class, $dbh, $vocabFile, $type) = @_;

  my $args = {};

  my $self = bless $args, $class; 

  $self->setVocabFile($vocabFile);
  $self->setDbh($dbh);
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


  open(F, $self->getVocabFile()) || die "Can't open vocab file for reading";
  my $vocabFromFile;
  while(<F>) {
    chomp;
    my @line = split(/\t/);
    scalar(@line) == 3 || die "invalid line in vocab file";
    my $term = $line[0];
    my $type = $line[2];
    die "duplicate ($type, $term) in vocab file line $.\n" if $vocabFromFile->{$type}->{$term};
    $vocabFromFile->{$type}->{$term} = 1;
  }

  my $dbh = $self->getDbh();

  my $queryField = $self->getType() eq 'geographic_location' ? 'country' : $self->getType();
  my $type = $self->getType();

  my $table = 'IsolateSource';

  my $sql = <<SQL;
select distinct $queryField as term
from dots.$table
where $queryField is not null
SQL

  my $sh = $dbh->prepare($sql);
  $sh->execute();

  my @sqlTerms;
  my $count;
  while(my ($term) = $sh->fetchrow_array()) {

    my $term = ApiCommonData::Load::IsolateVocabulary::VocabularyTerm->new($term, '', $table, $queryField, $type, $vocabFromFile->{$type}->{$term});
    push @sqlTerms, $term;
    $count++
  }
  $sh->finish();
  print STDERR "Found $count unique terms used by isolates in the database for type '$type'\n";

  return \@sqlTerms;
}


1;

