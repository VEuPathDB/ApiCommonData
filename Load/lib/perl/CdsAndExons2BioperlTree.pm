package ApiCommonData::Load::CdsAndExons2BioperlTree;
#vvvvvvvvvvvvvvvvvvvvvvvvv GUS4_STATUS vvvvvvvvvvvvvvvvvvvvvvvvv
  # GUS4_STATUS | SRes.OntologyTerm              | auto   | absent
  # GUS4_STATUS | SRes.SequenceOntology          | auto   | absent
  # GUS4_STATUS | Study.OntologyEntry            | auto   | absent
  # GUS4_STATUS | SRes.GOTerm                    | auto   | absent
  # GUS4_STATUS | Dots.RNAFeatureExon            | auto   | absent
  # GUS4_STATUS | RAD.SageTag                    | auto   | absent
  # GUS4_STATUS | RAD.Analysis                   | auto   | absent
  # GUS4_STATUS | ApiDB.Profile                  | auto   | absent
  # GUS4_STATUS | Study.Study                    | auto   | absent
  # GUS4_STATUS | Dots.Isolate                   | auto   | absent
  # GUS4_STATUS | DeprecatedTables               | auto   | absent
  # GUS4_STATUS | Pathway                        | auto   | absent
  # GUS4_STATUS | DoTS.SequenceVariation         | auto   | absent
  # GUS4_STATUS | RNASeq Junctions               | auto   | absent
  # GUS4_STATUS | Simple Rename                  | auto   | absent
  # GUS4_STATUS | ApiDB Tuning Gene              | auto   | absent
  # GUS4_STATUS | Rethink                        | auto   | absent
  # GUS4_STATUS | dots.gene                      | manual | unreviewed
die 'This file has broken or unreviewed GUS4_STATUS rules.  Please remove this line when all are fixed or absent';
#^^^^^^^^^^^^^^^^^^^^^^^^^ End GUS4_STATUS ^^^^^^^^^^^^^^^^^^^^


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
    if (grep {$type eq $_} ("transcript","CDS", "tRNA", "rRNA", "snRNA","coding","pseudo","coding_gene","rRNA_gene","snRNA_gene","tRNA_gene","miRNA_gene","pseudo_gene","snoRNA_gene","misc_RNA","misc_RNA_gene")) {
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
      
      if($gene->score()){
	  $gene->add_tag_value('score',$gene->score());
      }
      # we have to remove the exons before adding the transcript b/c
      # remove_SeqFeatures() removes all subfeatures of the $gene
      $gene->remove_SeqFeatures();
      $gene->add_SeqFeature($transcript);
    }
  }
}


1;
