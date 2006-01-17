package ApiComplexa::DataLoad::SequenceIterator;

use strict;
use vars qw(@ISA);

@ISA = qw(Bio::Factory::SequenceStreamI);

sub new {
  my ($class, $seqs) = @_;
  $class = ref $class || $class;
  return bless $seqs, $class;
}
                                                                                                                             
sub next_seq {
  my $self = shift;
  if (@$self) {
    return shift @$self;
  } else {
    return undef;
  }
}
                                                                                                                             
                                                                                                                             
return 1;
                                                                                                                             
