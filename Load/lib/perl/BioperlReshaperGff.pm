package PlasmoDBData::Load::BioperlReshaperGff;


use strict;
use Bio::SeqFeature::Generic;
use Bio::Location::Simple;

#input: transcript feature followed by exon features
#output: standard api tree: gene->transcript->exons
#                                           ->CDS

sub preprocess {
  my ($bioperlSeq, $plugin) = @_;

  # (1) retype transcript into gene
  # (2) create transcript, give it a copy of the gene's location
  # (3) add exons to transcript
  # (4) remove exons from gene
  # (5) add transcript to gene

  foreach my $bioperlFeatureTree ($bioperlSeq->get_SeqFeatures()) {
    my $type = $bioperlFeatureTree->primary_tag();
    if (grep {$type eq $_} ("transcript")) {
      $type = "coding_gene";
      $bioperlFeatureTree->primary_tag("$type");
      my $gene = $bioperlFeatureTree;
      my $geneLoc = $gene->location();
      my $transcript = &makeBioperlFeature("transcript", $geneLoc, $bioperlSeq);


      # (1) use get_SeqFeatures to retrieve exons from gene,
      # (2) use add_SeqFeature to add exon to transcript
      # (3) after all exons added to transcript, remove all subfeatures
      #     from gene
      # (4) add transcript to gene (don't add before removing exons
      #     or it will also be removed)

      my @exons = $gene->get_SeqFeatures();
      foreach my $exon (@exons) {
	$transcript->add_SeqFeature($exon);
      }

      $gene->remove_SeqFeatures();
      $gene->add_SeqFeature($transcript);

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
