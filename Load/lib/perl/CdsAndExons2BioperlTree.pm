package ApiCommonData::Load::CdsAndExons2BioperlTree;


use strict;
use Bio::SeqFeature::Generic;
use Bio::Location::Simple;
use ApiCommonData::Load::BioperlTreeUtils qw{makeBioperlFeature};


#input: CDS with join location (if multiple exons)
#output: standard api tree: gene->transcript->exons
#                                           ->CDS

sub preprocess {
  my ($bioperlSeq, $plugin) = @_;

  # (1) retype CDS into Gene
  # (4) create transcript, give it a copy of the gene's location
  # (5) add to gene
  # (6) remove exons from gene and add to transcript
  foreach my $bioperlFeatureTree ($bioperlSeq->get_SeqFeatures()) {
    my $type = $bioperlFeatureTree->primary_tag();
    if (grep {$type eq $_} ("CDS", "tRNA", "rRNA", "snRNA")) {
      $type = "coding" if $type eq "CDS";
      $bioperlFeatureTree->primary_tag("${type}_gene");
      my $gene = $bioperlFeatureTree;
      my $geneLoc = $gene->location();
      my $transcript = &makeBioperlFeature("transcript", $geneLoc, $bioperlSeq);
      my @exons = $gene->get_SeqFeatures();
      foreach my $exon (@exons) {
	my $t = $exon->primary_tag();
	die "expected bioperl exon but got '$t'" unless $t = "exon";
	$gene->remove_SeqFeature($exon);
	$transcript->add_SeqFeature($exon);
      }
      $gene->add_SeqFeature($transcript);
    }
  }
}


1;
