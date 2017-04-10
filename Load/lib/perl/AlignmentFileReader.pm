package ApiCommonData::Load::AlignmentFileReader;
use base qw(ApiCommonData::Load::FileReader);

use strict;

# @OVERRIDE
sub isSameGroup {
  my ($self, $a, $b) = @_;

  return $a->[13] eq $b->[13]
}

# @OVERRIDE
sub skipLine {
  my ($self, $line, $a, $fh) = @_;

  if($line =~ /^\d/) {
    return 0;
  }
  return 1;
}


1;


