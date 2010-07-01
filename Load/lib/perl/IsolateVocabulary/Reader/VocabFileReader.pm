package ApiCommonData::Load::IsolateVocabulary::Reader::VocabFileReader;
use base qw(ApiCommonData::Load::IsolateVocabulary::Reader);

use strict;
use Carp;

use CBIL::Util::PropertySet;
use ApiCommonData::Load::IsolateVocabulary::VocabularyTerm;

use ApiCommonData::Load::IsolateVocabulary::Utils;

sub getGusConfigFile {$_[0]->{gusConfigFile}}
sub setGusConfigFile {$_[0]->{gusConfigFile} = $_[1]}

sub disconnect {$_[0]->{dbh}->disconnect()}

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
  my ($class, $flatFile, $gusConfigFile, $type) = @_;

  my $args = {};

  my $self = bless $args, $class; 

  $self->setFlatFile($flatFile);
  $self->setGusConfigFile($gusConfigFile);

  my $dbh = ApiCommonData::Load::IsolateVocabulary::Utils::createDbh($gusConfigFile);
  $self->setDbh($dbh);
  $self->setType($type);

  return $self;
}

sub getFlatFile {$_[0]->{flatFile}}
sub setFlatFile {
  my ($self, $flatFile) = @_;

  if(-e $flatFile) {
    $self->{flatFile} = $flatFile;
  }
  else {
    croak "flatFile $flatFile Does not exist";
  }
}

sub extract {
  my ($self) = @_;

  # make hash of vocab terms found in flat file
  my $vocab;
  my @types = ('geographic_location', 'isolation_source', 'specific_host', 'product');
  open(F, $self->getFlatFile()) || die "Can't open flat file for reading";
  while(<F>) {
      my @line = split(//);
      scalar(@line) == 3 || die "invalid line in flat file";
      my $type = $line[2];
      grep(/$type/,@types) || die "illegal type '$type'";
      $vocab->{$type}->{$line[0]} = 1;
  }

  my $dbh = $self->getDbh();

  my $queryField = $self->getType() eq 'geographic_location' ? 'country' : $self->getType();
  my $type = $self->getType();

  my $table = $type eq 'product' ? 'IsolateFeature' : 'IsolateSource';

  my $sql = <<SQL;
  select distinct $queryField as term  from dots.$table where term is not null;
SQL

  my $sh = $dbh->prepare($sql);
  $sh->execute();

  my @sqlTerms;
  while(my ($term) = $sh->fetchrow_array()) {
      my $preexists = $vocab->{$type}->{$term};
      my $term = ApiCommonData::Load::IsolateVocabulary::VocabularyTerm->new($term, '', $table, $queryField, $type, $preexists);
      push @sqlTerms, $term;
  }
  $sh->finish();
  $self->disconnect();

  return \@sqlTerms;
}


1;

