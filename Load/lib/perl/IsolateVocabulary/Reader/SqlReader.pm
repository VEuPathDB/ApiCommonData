package ApiCommonData::Load::IsolateVocabulary::Reader::SqlReader;
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
  my ($class, $gusConfigFile, $type) = @_;

  my $args = {};

  my $self = bless $args, $class; 

  $self->setGusConfigFile($gusConfigFile);

  my $dbh = ApiCommonData::Load::IsolateVocabulary::Utils::createDbh($gusConfigFile);
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
select distinct i.original
from (select $queryField as original, regexp_replace($queryField, ':.*\$', '') as term from dots.$table) i 
 left join apidb.isolatevocabulary v
 on i.term = v.term and  v.type = '$type'
where i.term is not null 
 and v.term is null
 order by i.original
SQL

  my $sh = $dbh->prepare($sql);
  $sh->execute();

  my @existingTerms;
  while(my ($value) = $sh->fetchrow_array()) {
    my $table = undef;
    my $field = $type;

    my $term = ApiCommonData::Load::IsolateVocabulary::VocabularyTerm->new($value, $table, $field);
    push @existingTerms, $term;
  }
  $sh->finish();
  $self->disconnect();

  return \@existingTerms;
}


1;

