package ApiCommonData::Load::OneCds2BioperlTree;


use strict;
use Bio::SeqFeature::Generic;
use Bio::Location::Simple;

#input: CDS with join location (if multiple exons)
#output: standard api tree: gene->transcript->exons
#                                           ->CDS

sub preprocess {
  my ($bioperlSeq, $plugin) = @_;

  # (1) retype CDS into Gene
  # (2) remember its join locations
  # (4) create transcript, give it a copy of the gene's location
  # (5) add to gene
  # (6) create exons from sublocations
  # (7) add to transcript
  foreach my $bioperlFeatureTree ($bioperlSeq->get_SeqFeatures()) {
    my $type = $bioperlFeatureTree->primary_tag();
    if (grep {$type eq $_} ("CDS", "tRNA", "rRNA", "snRNA")) {
      $type = "coding" if $type eq "CDS";
      $bioperlFeatureTree->primary_tag("${type}_gene");
      my $gene = $bioperlFeatureTree;
      my $geneLoc = $gene->location();
      my $transcript = &makeBioperlFeature("transcript", $geneLoc, $bioperlSeq);
      $gene->add_SeqFeature($transcript);
      my @exonLocations = $geneLoc->each_Location();
      foreach my $exonLoc (@exonLocations) {
	my $exon = &makeBioperlFeature("exon", $exonLoc, $bioperlSeq);
	$transcript->add_SeqFeature($exon);
      }
    }
  }
}

sub makeBioperlFeature {
  my ($type, $loc, $bioperlSeq) = @_;
  my $feature = Bio::SeqFeature::Generic->new();
  $feature->attach_seq($bioperlSeq);
  $feature->primary_tag($type);
  $feature->start($loc->start());
  $feature->end($loc->end());
  my $location = Bio::Location::Simple->new();
  $location->start($loc->start());
  $location->end($loc->end());
  $location->seq_id($loc->seq_id());
  $location->strand($loc->strand());
  $feature->location($location);
  return $feature;
}



1;
