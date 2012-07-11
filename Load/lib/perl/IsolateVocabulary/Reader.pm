package ApiCommonData::Load::IsolateVocabulary::Reader;

use strict;

use Carp;
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


sub extract {}

1;
