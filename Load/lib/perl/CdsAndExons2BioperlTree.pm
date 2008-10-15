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

  # (1) retype CDS or transcript into Gene
  # (4) create transcript, give it a copy of the gene's location
  # (5) add to gene
  # (6) add exons to transcript
  # (7) remove exons from gene
  foreach my $bioperlFeatureTree ($bioperlSeq->get_SeqFeatures()) {
    my $type = $bioperlFeatureTree->primary_tag();

    if ($bioperlFeatureTree->has_tag('GeneType')) {
	($type) = $bioperlFeatureTree->get_tag_values('GeneType');
    }
    if (grep {$type eq $_} ("transcript","CDS", "tRNA", "rRNA", "snRNA","coding","pseudo","coding_gene","rRNA_gene","snRNA_gene","tRNA_gene","miRNA_gene","pseudo_gene","snoRNA_gene")) {
      $type = "coding" if ($type eq "CDS" || $type eq "transcript");
      if($type =~ /\_gene/){
	  $bioperlFeatureTree->primary_tag("$type");
      }else{
	  $bioperlFeatureTree->primary_tag("${type}_gene");
      }
      my $gene = $bioperlFeatureTree;
      my $geneLoc = $gene->location();
      my $transcript = &makeBioperlFeature("transcript", $geneLoc, $bioperlSeq);
      my @exons = $gene->get_SeqFeatures();
      foreach my $exon (@exons) {
	my $t = $exon->primary_tag();
	die "expected bioperl exon but got '$t'" unless $t = "exon";
	$transcript->add_SeqFeature($exon);

        # the frame loade to gus will be 1,2 or 3
        my $frame = $exon->frame();
        if($frame =~ /[012]/) {
          $frame++;
          $exon->add_tag_value('reading_frame', $frame);
        }
      }
      # we have to remove the exons before adding the transcript b/c
      # remove_SeqFeatures() removes all subfeatures of the $gene
      $gene->remove_SeqFeatures();
      $gene->add_SeqFeature($transcript);
    }
  }
}


1;
