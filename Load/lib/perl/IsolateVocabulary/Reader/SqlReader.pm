package ApiCommonData::Load::IsolateVocabulary::Reader::SqlReader;
use base qw(ApiCommonData::Load::IsolateVocabulary::Reader);

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
  my ($class, $dbh, $type) = @_;

  my $args = {};

  my $self = bless $args, $class; 

  $self->setDbh($dbh);
  $self->setType($type);

  return $self;
}

sub extract {
  my ($self) = @_;

  my $dbh = $self->getDbh();

  my $queryField = $self->getType() eq 'geographic_location' ? 'country' : $self->getType();
  my $type = $self->getType();

  my $table = $type eq 'product' ? 'IsolateFeature' : 'IsolateSource';

  my $sql = <<SQL;
select distinct i.term, v.term as preexists
from (select $queryField as term  from dots.$table) i 
 left join apidb.isolatevocabulary v
 on i.term = v.term and  v.type = '$type'
where i.term is not null 
SQL

  my $sh = $dbh->prepare($sql);
  $sh->execute();

  my @sqlTerms;
  while(my ($term, $preexists) = $sh->fetchrow_array()) {
    $preexists = $preexists ? 1 : 0;

    my $term = ApiCommonData::Load::IsolateVocabulary::VocabularyTerm->new($term, '', $table, $queryField, $type, $preexists);
    push @sqlTerms, $term;
  }
  $sh->finish();

  return \@sqlTerms;
}


1;

