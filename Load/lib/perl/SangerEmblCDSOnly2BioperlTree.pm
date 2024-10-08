package ApiCommonData::Load::SangerEmblCDSOnly2BioperlTree;
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
use Data::Dumper;

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

  my (%UTR3Prime,%UTR5Prime);

  my @seqFeatures = $bioperlSeq->remove_SeqFeatures;

  foreach my $bioperlFeatureTree (@seqFeatures) {

    my $type = $bioperlFeatureTree->primary_tag();

    if($type eq "3'UTR"){
        my $geneID;
        if($bioperlFeatureTree->has_tag('locus_tag')){
            ($geneID) = $bioperlFeatureTree->get_tag_values('locus_tag');
        }
        $UTR3Prime{$geneID} = $bioperlFeatureTree if (!$UTR3Prime{$geneID});
    }

    if($type eq "5'UTR"){
        my $geneID;
        if($bioperlFeatureTree->has_tag('locus_tag')){
            ($geneID) = $bioperlFeatureTree->get_tag_values('locus_tag');
        }
        $UTR5Prime{$geneID} = $bioperlFeatureTree if (!$UTR5Prime{$geneID});
    }
  }



  foreach my $bioperlFeatureTree (@seqFeatures) {

    my $type = $bioperlFeatureTree->primary_tag();

    if (grep {$type eq $_} ("CDS", "tRNA", "rRNA", "snRNA", "misc_RNA", "snoRNA", "ncRNA")) {
      $type = "coding" if $type eq "CDS";

      if ($type eq 'ncRNA') {
        if ($bioperlFeatureTree->has_tag('ncRNA_class') ) {
          my $ncRNA_class;
          ($ncRNA_class) = $bioperlFeatureTree->get_tag_values('ncRNA_class');
          $type = $ncRNA_class if ($ncRNA_class =~ /RNA/i);
          $bioperlFeatureTree->remove_tag('ncRNA_class');
        }
      }

      $bioperlFeatureTree->primary_tag("${type}_gene");

      my ($sharedId, $geneID, $UTR5PExon, $UTR3PExon);

      my $codonStart = 0;

      for my $qualifier ($bioperlFeatureTree->get_all_tags()) {
	  if($qualifier eq 'codon_start'){
	      foreach my $value ($bioperlFeatureTree->get_tag_values($qualifier)){
		  $codonStart = $value - 1;
	      }
	  }
      }

      if($bioperlFeatureTree->has_tag('locus_tag')){
	  ($geneID) = $bioperlFeatureTree->get_tag_values('locus_tag');
	  print STDERR "processing $geneID...\n";
      }

      my $gene = $bioperlFeatureTree;
      my $geneLoc = $gene->location();
      my $codingLoc = $geneLoc;
      my @codingLocs = $codingLoc->each_Location();

      my (@codingStart,@codingEnd);

      my $codingLocCtr = 0;
      foreach my $CDSLoc (sort {$a->start <=> $b->start} @codingLocs){

        if ($type eq 'coding') {
	  if($geneLoc->strand == -1){
	      $codingStart[$codingLocCtr] = $CDSLoc->end();
	      $codingEnd[$codingLocCtr] = $CDSLoc->start();
	  }else{
	      $codingStart[$codingLocCtr] = $CDSLoc->start();
	      $codingEnd[$codingLocCtr] = $CDSLoc->end();
	  }
        } else {
          $codingStart[$codingLocCtr] = "";
          $codingEnd[$codingLocCtr] = "";
        }
	  $codingLocCtr++;
      }

      my @subLocs = $geneLoc->each_Location();

q{
      if($UTR5Prime{$geneID}){
          if($geneLoc->strand == -1){
              if(($UTR5Prime{$geneID}->start() -1) != $subLocs[$#subLocs]->end() && ($UTR5Prime{$geneID}->start()) != $subLocs[$#subLocs]->end()){
                  $UTR5PExon = $UTR5Prime{$geneID};
              }else{
                  $subLocs[$#subLocs]->end($UTR5Prime{$geneID}->end);
              }

          }else{
              if(($UTR5Prime{$geneID}->end() + 1) != $subLocs[0]->start() && ($UTR5Prime{$geneID}->end()) != $subLocs[0]->start()){
                  $UTR5PExon = $UTR5Prime{$geneID};
              }else{
                  $subLocs[0]->start($UTR5Prime{$geneID}->start);
              }
          }
      }

      if($UTR3Prime{$geneID}){
          if($geneLoc->strand == -1){
              if((($UTR3Prime{$geneID}->end() + 1) != $subLocs[0]->start())&&(($UTR3Prime{$geneID}->end()) != $subLocs[0]->start())){
                  $UTR3PExon = $UTR3Prime{$geneID};
              }else{
                  $subLocs[0]->start($UTR3Prime{$geneID}->start);   
              }
          }else{
              if((($UTR3Prime{$geneID}->start() - 1) != $subLocs[$#subLocs]->end())&&(($UTR3Prime{$geneID}->start()) != $subLocs[$#subLocs]->end())){
                  $UTR3PExon = $UTR3Prime{$geneID};
              }else{
                  $subLocs[$#subLocs]->end($UTR3Prime{$geneID}->end);
              }
          }
      }
};

      my(@geneTags) = $gene->get_all_tags();
      my $transcriptLoc = Bio::Location::Split->new();

      foreach my $loc ($geneLoc->each_Location()){
	  $transcriptLoc->add_sub_Location($loc);
      }

      $transcriptLoc->seq_id($geneLoc->seq_id);
      my $transcript = &makeBioperlFeature("transcript", $transcriptLoc, $bioperlSeq);

      $gene->add_SeqFeature($transcript);
      my @exonLocations = $transcriptLoc->each_Location();

      $codingLocCtr = 0;
      foreach my $exonLoc (@exonLocations) {
	my $exon = &makeBioperlFeature("exon", $exonLoc, $bioperlSeq);
	if($type eq 'coding'){
	    if($exonLoc->strand == -1){
		$exon->add_tag_value('CodingStart',$codingStart[$codingLocCtr] - $codonStart);
		$exon->add_tag_value('CodingEnd',$codingEnd[$codingLocCtr]);
	    }else{
		$exon->add_tag_value('CodingStart',$codingStart[$codingLocCtr] + $codonStart);
		$exon->add_tag_value('CodingEnd',$codingEnd[$codingLocCtr]);
	    }
	}

	$codingLocCtr++;

	$transcript->add_SeqFeature($exon);
      }

q{
      if($UTR5PExon){
	  if($gene->location->strand() == -1){
	      $gene->location->end($UTR5PExon->end());
	  }else{
	      $gene->location->start($UTR5PExon->start());
	  }

	  if(ref($transcript) == 'Bio::Location::Simple'){
	      my $newTranscriptLoc = Bio::Location::Split->new();
	      $newTranscriptLoc->add_sub_Location($transcript->location());
	      $newTranscriptLoc->add_sub_Location($UTR5PExon->location());	      
	      $transcript->location($newTranscriptLoc);

	  }else{
	      $transcript->location()->add_sub_Location($UTR5PExon->location());
	  }
         my $exon = &makeBioperlFeature("exon",$UTR5PExon->location(), $bioperlSeq);
          $exon->add_tag_value('CodingStart','');
          $exon->add_tag_value('CodingEnd','');
          $transcript->add_SeqFeature($exon);
      }

      if($UTR3PExon){

	  if($gene->location->strand() == -1){
	      $gene->location->start($UTR3PExon->start());

	  }else{
	      $gene->location->end($UTR3PExon->end());
	  }

	  if(ref($transcript) == 'Bio::Location::Simple'){
	      my $newTranscriptLoc = Bio::Location::Split->new();
	      $newTranscriptLoc->add_sub_Location($transcript->location());
	      $newTranscriptLoc->add_sub_Location($UTR3PExon->location());	      
	      $transcript->location($newTranscriptLoc);

	  }else{
	      $transcript->location()->add_sub_Location($UTR3PExon->location());
	  }

          my $exon = &makeBioperlFeature("exon", $UTR3PExon->location(), $bioperlSeq);
          $exon->add_tag_value('CodingStart','');
          $exon->add_tag_value('CodingEnd','');
          $transcript->add_SeqFeature($exon);
      }
};

      $bioperlSeq->add_SeqFeature($gene);
  }else{
    if (!($bioperlFeatureTree->has_tag("locus_tag") ) ) {
      $bioperlFeatureTree->add_tag_value("locus_tag",$bioperlSeq->accession());
    }
      $bioperlSeq->add_SeqFeature($bioperlFeatureTree);

  }
}
}



1;
