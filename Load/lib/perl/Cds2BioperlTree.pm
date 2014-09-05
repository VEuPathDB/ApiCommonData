package ApiCommonData::Load::Cds2BioperlTree;
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
  # GUS4_STATUS | dots.gene                      | manual | reviewed
#die 'This file has broken or unreviewed GUS4_STATUS rules.  Please remove this line when all are fixed or absent';
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
  foreach my $bioperlFeatureTree ($bioperlSeq->get_SeqFeatures()) {
    my $type = $bioperlFeatureTree->primary_tag();
    if (grep {$type eq $_} ("CDS", "tRNA", "rRNA", "snRNA", "misc_RNA", "snoRNA","scRNA","ncRNA")) {
      $type = "coding" if $type eq "CDS";

      if($type eq 'ncRNA'){
	  if($bioperlFeatureTree->has_tag('ncRNA_class')){
	    my $ncRNA_class;
	    ($ncRNA_class) = $bioperlFeatureTree->get_tag_values('ncRNA_class');
	    $type = $ncRNA_class if ($ncRNA_class =~ /RNA/i);
	    $bioperlFeatureTree->remove_tag('ncRNA_class');
	  }
      }

      my($parentID);

      if($bioperlFeatureTree->has_tag('systematic_id')){
	  ($parentID) = $bioperlFeatureTree->get_tag_values('systematic_id');
      }elsif($bioperlFeatureTree->has_tag('locus_tag')){
	  ($parentID) = $bioperlFeatureTree->get_tag_values('locus_tag');
      }
      $bioperlFeatureTree->primary_tag("${type}_gene");
      my $gene = $bioperlFeatureTree;
      my $geneLoc = $gene->location();
      $gene->add_tag_value("parentID",$parentID);
      my $transcript = &makeBioperlFeature("transcript", $geneLoc, $bioperlSeq);
      $gene->add_SeqFeature($transcript);
      my @exonLocations = $geneLoc->each_Location();
      my $codonStart = 0;

      $codonStart = $bioperlFeatureTree->get_tag_values("codon_start") if $bioperlFeatureTree->has_tag("codon_start");
      my $CDSLength = 0;
      my $CDSLocation = $geneLoc; 
      
      my (@exons,@sortedExons);

      foreach my $exonLoc (@exonLocations) {
	my $exon = &makeBioperlFeature("exon", $exonLoc, $bioperlSeq);
	

	my($codingStart,$codingEnd);
	if($type eq 'coding'){
		    if($exon->location->strand == -1){

			$codingStart = $exon->location->end;
			$codingEnd = $exon->location->start;
			
			if($codingStart eq $CDSLocation->end && $codonStart > 0){
			    $codingStart -= $codonStart;
			}
			$exon->add_tag_value('CodingStart',$codingStart);
			$exon->add_tag_value('CodingEnd',$codingEnd);
			
		    }else{
			
			$codingStart = $exon->location->start;
			$codingEnd = $exon->location->end;
				    
			if($codingStart eq $CDSLocation->start && $codonStart > 0){
			    $codingStart += $codonStart;
			}
			$exon->add_tag_value('CodingStart',$codingStart);
			$exon->add_tag_value('CodingEnd',$codingEnd);
		    }
		    $exon->add_tag_value('type','coding');
		}else{
		    $exon->add_tag_value('CodingStart','');
		    $exon->add_tag_value('CodingEnd',''); 
		}
	$CDSLength += (abs($codingStart - $codingEnd) + 1);

	push(@exons,$exon);
      }
      

      $transcript->add_tag_value('CDSLength',$CDSLength);


      my $trailingNAs = $CDSLength%3;


    my $exonCtr = 0;

	  foreach my $exon (sort {$a->location->start() <=> $b->location->start()} @exons){

	      
	      if($exon->location->strand() == -1){
		  if($exonCtr == 0 && $trailingNAs > 0){
		      if($exon->has_tag("CodingStart")){
			  my($codingEnd) = $exon->get_tag_values("CodingEnd");
			  if($codingEnd ne ''){
			      $exon->remove_tag("CodingEnd");
			      $exon->add_tag_value("CodingEnd",$codingEnd+$trailingNAs);
			  }			  
		      }
		  }		  
		  
	      }else{
		  if($exonCtr == $#exons && $trailingNAs > 0){
		      if($exon->has_tag("CodingEnd")){
			  my($codingEnd) = $exon->get_tag_values("CodingEnd");
			  if($codingEnd ne ''){
			      $exon->remove_tag("CodingEnd");
			      $exon->add_tag_value("CodingEnd",$codingEnd-$trailingNAs);
			  }			  
		      }
		  }
	      }

#	      &defaultPrintFeatureTree($exon,"");
	      $exonCtr++;
	      $transcript->add_SeqFeature($exon);
	  }
  }

}
}


sub defaultPrintFeatureTree {
  my ($bioperlFeatureTree, $indent) = @_;



  print("\n") unless $indent;
  my $type = $bioperlFeatureTree->primary_tag();
  print("$indent< $type >\n");
  my @locations = $bioperlFeatureTree->location()->each_Location();
  foreach my $location (@locations) {
    my $seqId =  $location->seq_id();
    my $start = $location->start();
    my $end = $location->end();
    my $strand = $location->strand();
    print("$indent$seqId $start-$end strand:$strand\n");
  }
  my @tags = $bioperlFeatureTree->get_all_tags();
  foreach my $tag (@tags) {
    my @annotations = $bioperlFeatureTree->get_tag_values($tag);
    foreach my $annotation (@annotations) {
      if (length($annotation) > 50) {
	$annotation = substr($annotation, 0, 50) . "...";
      }
      print("$indent$tag: $annotation\n");
    }
  }

  foreach my $bioperlChildFeature ($bioperlFeatureTree->get_SeqFeatures()) {
    &defaultPrintFeatureTree($bioperlChildFeature, "  $indent");
  }
}

1;
