package ApiCommonData::Load::AlignmentFileReader;
use base qw(ApiCommonData::Load::FileReader);

use CBIL::Bio::BLAT::Alignment;

use strict;


sub new {
  my ($class, $file, $filters, $delimiter) = @_;

  my $sortFile = "sort -k 14,14 $file|";

  return $class->SUPER::new($sortFile, $filters, $delimiter);
}

# @OVERRIDE
sub hasDictionary {
  return 1;
}

# @OVERRIDE
sub makeDictionary {
  my ($self, $lineAsArray) = @_;

  return CBIL::Bio::BLAT::Alignment->new($lineAsArray);
}

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


