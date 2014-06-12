package ApiCommonData::Load::SNPSampleTabFilter;
use base qw(ApiCommonData::Load::FileReader);

use strict;


sub skipLine {
  my ($self, $line, $lineAsArray, $fh) = @_;

  return 1 unless($line);

  my $filters = $self->getFilters();

  foreach(@$filters) {
    if($lineAsArray->[2] eq $_) {
      return 1;
    }
  }
  return 0;
}


1;
