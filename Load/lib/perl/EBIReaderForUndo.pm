package ApiCommonData::Load::EBIReaderForUndo;
use base qw(ApiCommonData::Load::UniDBTableReader);

use strict;

# there is no data to count
sub getTableCount {
  return 0;
}

# there are no rows to keep
sub nextRowAsHashref {
  return undef;
}

1;
