package ApiCommonData::Load::Plugin::InsertHtsSnps;

##subclassing InsertSnps so that undo tables are correct ... don't want to remove snpfeatures

@ISA = qw(ApiCommonData::Load::Plugin::InsertSnps);

use strict;
use ApiCommonData::Load::Plugin::InsertSnps;

sub undoTables {
  my ($self) = @_;
  
  return ('DoTS.SeqVariation'
         );
}

1;
