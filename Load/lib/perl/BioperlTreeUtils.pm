package ApiCommonData::Load::BioperlTreeUtils;

require Exporter;
@ISA = qw(Exporter);
@EXPORT_OK = qw(makeBioperlFeature);
use strict;

sub makeBioperlFeature {
  my ($type, $loc, $bioperlSeq) = @_;
  my $feature = Bio::SeqFeature::Generic->new();
  $feature->attach_seq($bioperlSeq);
  $feature->primary_tag($type);
  $feature->start($loc->start());
  $feature->end($loc->end());
  my $location = Bio::Location::Simple->new();
  $location->start($loc->start());  $location->end($loc->end());
  $location->seq_id($loc->seq_id());
  $location->strand($loc->strand());
  $feature->location($location);
  return $feature;
}
