package ApiCommonData::Load::IsolateVocabulary::Updater;

use strict;
use Carp;

use ApiCommonData::Load::IsolateVocabulary::Utils;

sub getTerms {$_[0]->{terms}}
sub setTerms {$_[0]->{terms} = $_[1]}

sub getGusConfigFile {$_[0]->{gusConfigFile}}
sub setGusConfigFile {$_[0]->{gusConfigFile} = $_[1]}

sub disconnect {$_[0]->{dbh}->disconnect()}

sub getDbh {$_[0]->{dbh}}
sub setDbh {$_[0]->{dbh} = $_[1]}

sub getType {$_[0]->{_type}}

sub setType {
  my ($self, $type) = @_;

  unless(ApiCommonData::Load::IsolateVocabulary::Utils::isValidType($type)) {
    croak "Type $type is not supported";
  }

  $self->{_type} = $type;  
}


sub new {
  my ($class, $gusConfigFile, $type, $terms) = @_;

  my $args = {};

  my $self = bless $args, $class; 

  $self->setGusConfigFile($gusConfigFile);

  my $dbh = ApiCommonData::Load::IsolateVocabulary::Utils::createDbh($gusConfigFile);
  $self->setDbh($dbh);
  $self->setType($type);

  return $self;
}

sub update {
  #TODO:  loop through $self->{terms} and perform database updates.  First make a map of $term->getValue => na_feature_id;  use the na_feature_id to do the updates!!!

  # CHECK the existing Ontologies to ensure the NEW term is legal!!!
}



1;
