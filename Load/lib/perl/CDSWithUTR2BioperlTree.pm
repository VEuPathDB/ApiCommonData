package ApiCommonData::Load::CDSWithUTR2BioperlTree;


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
        my $systematicId;
        if($bioperlFeatureTree->has_tag('systematic_id')){

            ($systematicId) = $bioperlFeatureTree->get_tag_values('systematic_id');

	    $systematicId =~ /([^\:]+)\:/;
	    $systematicId = $1;
 
            $bioperlFeatureTree->remove_tag('systematic_id');
            $bioperlFeatureTree->add_tag_value('systematic_id',$systematicId);
        }
        $UTR3Prime{$systematicId} = $bioperlFeatureTree;
    }
    
    if($type eq "5'UTR"){
        my $systematicId;
        if($bioperlFeatureTree->has_tag('systematic_id')){
            ($systematicId) = $bioperlFeatureTree->get_tag_values('systematic_id');
	    $systematicId =~ /([^\:]+)\:/;
	    $systematicId = $1;



            $bioperlFeatureTree->remove_tag('systematic_id');
            $bioperlFeatureTree->add_tag_value('systematic_id',$systematicId);
        }
        $UTR5Prime{$systematicId} = $bioperlFeatureTree;
    }
    

    
}



  foreach my $bioperlFeatureTree (@seqFeatures) {
    my $type = $bioperlFeatureTree->primary_tag();
    if (grep {$type eq $_} ("CDS", "tRNA", "rRNA", "snRNA", "misc_RNA", "snoRNA", "ncRNA")) {
      my $suffixes = "abcdefghijklmnopqrstuvwxyz";
      my @suffix = split(//,$suffixes);

      $type = "coding" if $type eq "CDS";
      $bioperlFeatureTree->primary_tag("${type}_gene");
      my ($sharedId, $systematicId, $UTR5PExon, $UTR3PExon);

      my $codonStart = 0;


      for my $qualifier ($bioperlFeatureTree->get_all_tags()) {
	  if($qualifier eq 'codon_start'){
	      foreach my $value ($bioperlFeatureTree->get_tag_values($qualifier)){
		  $codonStart = $value - 1;
	      }
	  }
	  if($bioperlFeatureTree->has_tag('shared_id')){
	      ($sharedId) = $bioperlFeatureTree->get_tag_values('shared_id');
	  }
      }
  

      if($bioperlFeatureTree->has_tag('systematic_id')){
	  ($systematicId) = $bioperlFeatureTree->get_tag_values('systematic_id');

	  if($sharedId){
	      $systematicId =~ /\.(\d+)$/;

	      my $altNo = $1;

	      $systematicId = "$sharedId-$suffix[$altNo-1]";
	      $bioperlFeatureTree->remove_tag("systematic_id");
	      $bioperlFeatureTree->add_tag_value("systematic_id",$systematicId);
	  }
      }

 
      my $gene = $bioperlFeatureTree;
      my $geneLoc = $gene->location();
      my $codingLoc = $geneLoc;
      my @codingLocs = $codingLoc->each_Location();
      my @subLocs = $geneLoc->each_Location();
      
      my(@utr5Locs,@utr3Locs);
      if($UTR5Prime{$systematicId}){
	  @utr5Locs = $UTR5Prime{$systematicId}->location->each_Location();
	  
      }

      if($UTR3Prime{$systematicId}){
	  @utr3Locs = $UTR3Prime{$systematicId}->location->each_Location();
	  
      }

      
      my (@codingStart,@codingEnd);

      my $codingLocCtr = 0;
      foreach my $CDSLoc (@codingLocs){

	  if($geneLoc->strand == -1){
	      $codingStart[$codingLocCtr] = $CDSLoc->end();
	      $codingEnd[$codingLocCtr] = $CDSLoc->start();
	  }else{
	      $codingStart[$codingLocCtr] = $CDSLoc->start();
	      $codingEnd[$codingLocCtr] = $CDSLoc->end();
	  }
	  $codingLocCtr++;
      }

      my @exonLocs;

 

      if($geneLoc->strand == -1){

	  push(@exonLocs,@utr3Locs,@codingLocs,@utr5Locs);


      }else{
	  push(@exonLocs,@utr5Locs,@codingLocs,@utr3Locs);

	  
      }

      #print "Hello\n";
      #print Dumper @exonLocs;

      

      
  #    print Dumper $geneLoc;

      #print "------------------------\n";

      my @exonLocations;

 #     my $prevStart = 0;
      my $prevEnd = 0;
      
      my $exonCtr = 0;
      foreach my $exonLoc (@exonLocs){

	  if($prevEnd == $exonLoc->start() || $prevEnd == $exonLoc->start()-1){
#	      splice(@exonLocations,$exonCtr-2,1);
	      #print "$prevEnd ".$exonLoc->start();
	      $exonLocations[$exonCtr-1]->end($exonLoc->end());
	  }else{
	      push(@exonLocations,$exonLoc);
	      $exonCtr++;
	  }

	  $prevEnd = $exonLoc->end();
	   
      }

     #print Dumper @exonLocations;

      if($geneLoc->strand == -1){



	  if($utr3Locs[0]){
	      $subLocs[0]->start($utr3Locs[0]->start());
	  }
	  if($utr5Locs[0]){
	      $subLocs[$#subLocs]->end($utr5Locs[$#utr5Locs]->end());
	  }	  
      }else{


	  if($utr5Locs[0]){
	      $subLocs[0]->start($utr5Locs[0]->start());
	  }
	  if($utr3Locs[0]){
	      $subLocs[$#subLocs]->end($utr3Locs[$#utr3Locs]->end());
	  }	  
      }
            my $transcriptLoc = Bio::Location::Split->new();


      foreach my $loc (@subLocs){
	  $transcriptLoc->add_sub_Location($loc);
      }
      
      $transcriptLoc->seq_id($geneLoc->seq_id);
      
 
      my $transcript = &makeBioperlFeature("transcript", $transcriptLoc, $bioperlSeq);


#     foreach my $tag (@geneTags){
#	  if($tag ne 'shared_id' && $tag ne 'temporary_systematic_id' && $tag ne 'temporary_temporary_systematic_id'){
#	      $transcript->add_tag_value($tag,$gene->get_tag_values($tag));
#	  }
#     }



#      print STDERR "$systematicId\n";
#      print STDERR Dumper $geneLoc;

#      print STDERR Dumper $transcriptLoc;

      $gene->add_SeqFeature($transcript);
  #    my @exonLocations2 = $transcriptLoc->each_Location();


      $codingLocCtr = 0;
      foreach my $exonLoc (@exonLocations) {
	my $exon = &makeBioperlFeature("exon", $exonLoc, $bioperlSeq);
	if($type eq 'coding'){
	   if($codingStart[$codingLocCtr] >= $exonLoc->start() && $codingStart[$codingLocCtr] <= $exonLoc->end()){  
	       if($exonLoc->strand == -1){
		   $exon->add_tag_value('CodingStart',$codingStart[$codingLocCtr] - $codonStart);
		   $exon->add_tag_value('CodingEnd',$codingEnd[$codingLocCtr]);
	       }else{
		   $exon->add_tag_value('CodingStart',$codingStart[$codingLocCtr] + $codonStart);
		   $exon->add_tag_value('CodingEnd',$codingEnd[$codingLocCtr]);
	       }
	       $codingLocCtr++;
	   }else{
	       $exon->add_tag_value('CodingStart','');
	       $exon->add_tag_value('CodingEnd','');
	   }

       }else{
	   $exon->add_tag_value('CodingStart','');
	   $exon->add_tag_value('CodingEnd','');
       }

	$transcript->add_SeqFeature($exon);
    }


#      print Dumper $gene;
      $bioperlSeq->add_SeqFeature($gene);

      

  }else{

      $bioperlSeq->add_SeqFeature($bioperlFeatureTree);
  }

}
}


1;
