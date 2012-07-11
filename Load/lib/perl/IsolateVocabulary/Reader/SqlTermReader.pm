package ApiCommonData::Load::IsolateVocabulary::Reader::SqlTermReader;
use base qw(ApiCommonData::Load::IsolateVocabulary::Reader);

use strict;
use Carp;

use ApiCommonData::Load::IsolateVocabulary::VocabularyTerm;


sub setVocabulary {$_[0]->{_vocabulary} = $_[1]}
sub getVocabulary {$_[0]->{_vocabulary}}


sub new {
  my ($class, $dbh, $type, $vocabulary) = @_;

  my $args = {};

  my $self = bless $args, $class; 

  $self->setDbh($dbh);
  $self->setType($type);
  $self->setVocabulary($vocabulary);

  return $self;
}

sub extract {
  my ($self) = @_;

  my $dotsIsolateSourceTerms = $self->getDotsIsolateSourceTerms();
  my $studyOntologyEntryTerms = $self->getStudyOntologyEntryTerms();

  my @rv = (@$dotsIsolateSourceTerms, @$studyOntologyEntryTerms);

  return \@rv;
}

sub getStudyOntologyEntryTerms {
  my ($self) = @_;

  my $dbh = $self->getDbh();
  my $type = $self->getType();
  my $vocabulary = $self->getVocabulary();

  my $table = 'OntologyEntry';

  my $typeMap = {geographic_location => 'GeographicLocation',
                 isolation_source => 'BioSourceType',
                 specific_host => 'Host',
                };

  my $category = $typeMap->{$type};

  my $sql = <<SQL;
select distinct oe.value as term
from study.ontologyentry oe, STUDY.biomaterialcharacteristic bc
where bc.ontology_entry_id = oe.ontology_entry_id 
and oe.category = '$category'
and oe.value is not null
SQL

  my $sh = $dbh->prepare($sql);
  $sh->execute();

  my @sqlTerms;
  while(my ($term) = $sh->fetchrow_array()) {
    my $preexists = 0;
    if($vocabulary->{$type}->{$term}) {
      $preexists = 1;
    }

    my $term = ApiCommonData::Load::IsolateVocabulary::VocabularyTerm->new($term, '', $table, $category, $type, $preexists);
    push @sqlTerms, $term;
  }
  $sh->finish();

  return \@sqlTerms;
}


sub getDotsIsolateSourceTerms {
  my ($self) = @_;

  my $dbh = $self->getDbh();
  my $queryField = $self->getType() eq 'geographic_location' ? 'country' : $self->getType();
  my $type = $self->getType();
  my $vocabulary = $self->getVocabulary();

  my $table = 'IsolateSource';

  my $sql = <<SQL;

select $queryField as term  from dots.$table
where $queryField is not null 
SQL

  my $sh = $dbh->prepare($sql);
  $sh->execute();

  my @sqlTerms;
  while(my ($term) = $sh->fetchrow_array()) {

    my $preexists = 0;
    if($vocabulary->{$type}->{$term}) {
      $preexists = 1;
    }

    my $term = ApiCommonData::Load::IsolateVocabulary::VocabularyTerm->new($term, '', $table, $queryField, $type, $preexists);
    push @sqlTerms, $term;
  }
  $sh->finish();

  return \@sqlTerms;
}


1;

###############################################3


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

sub getTermsInVocab {
  my ($self) = @_;
  my @termsInVocab;

  open(F, $self->getVocabFile()) || die "Can't open vocab file for reading";
  my $res = {};

  while(<F>) {
    chomp;
    my @line = split(/\t/);
    scalar(@line) == 3 || die "invalid line in vocab file";

    my ($term, $type) = ($line[0], $line[2]);
    $res->{$term}->{$type} = 1;
  }

  return $res;
}

1;

