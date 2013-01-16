package ApiCommonData::Load::SangerGFF2BioperlTree;

# Remove existing gene features, promote CDS, tRNA, etc to gene

use strict;
use Bio::Location::Simple;
use ApiCommonData::Load::BioperlTreeUtils qw{makeBioperlFeature};
use Data::Dumper;
use Bio::SeqFeature::Tools::Unflattener;
use Data::Dumper;

#input:
#
# gene  [folded into CDS]
# mRNA  (optional)  [discarded]
# CDS
#
#output: standard api tree: gene->transcript->exons

# (0) remove all seq features, add back the non-genes
# (1) copy old gene qualifiers to cds/rna feature
# (2) retype CDS into Gene
# (3) remember its join locations
# (4) create transcript, give it a copy of the gene's location
# (5) add to gene
# (6) create exons from sublocations
# (7) add to transcript

#Need to check if codon_start qualifier (reading frame) in Genbank files for CDS is relative to the CDS positions. This code assumes that it is

sub preprocess {
    my ($bioperlSeq, $plugin) = @_;

    my ($geneFeature, $source);
    my  $primerPair = '';

#    my $unflattener = Bio::SeqFeature::Tools::Unflattener->new;

	#$unflattener->unflatten_seq(-seq=>$bioperlSeq,-use_magic=>1);
	my @topSeqFeatures = $bioperlSeq->get_SeqFeatures;
	my @seqFeatures = $bioperlSeq->remove_SeqFeatures;
	
        my %polypeptide;

        my %rnas;
	foreach my $bioperlFeatureTree (@seqFeatures){
	    my $type = $bioperlFeatureTree->primary_tag();


	    if($type eq 'polypeptide'){
		my $id;
		my $sourceId = "";
		($sourceId) = $bioperlFeatureTree->get_tag_values("ID") if $bioperlFeatureTree->has_tag("ID");
		if ($bioperlFeatureTree->has_tag("Derives_from")){
		    ($id) = $bioperlFeatureTree->get_tag_values("Derives_from");
		}else{
		    print STDERR "Error: $sourceId polypeptide feature has no associated parent$id\n";
		}

		if($polypeptide{$id}){
		    print STDERR "Error: Multiple polypeptides for $id\n";
		}

		$polypeptide{$id} = $bioperlFeatureTree if($id);
	    }

	}
	    


	foreach my $bioperlFeatureTree (@topSeqFeatures) {
	    my $type = $bioperlFeatureTree->primary_tag();
	    
	    if($type eq 'pseudogene'){
		$bioperlFeatureTree->primary_tag('gene');
		$bioperlFeatureTree->add_tag_value("pseudo","");
		$type = "gene";
	    }


	    if($type eq 'repeat_region'){
		if($bioperlFeatureTree->has_tag("satellite")){
		    $bioperlFeatureTree->primary_tag("microsatellite");
		}
		if(!($bioperlFeatureTree->has_tag("ID"))){
		    $bioperlFeatureTree->add_tag_value("ID",$bioperlSeq->accession());
		}

		$bioperlSeq->add_SeqFeature($bioperlFeatureTree);
	    }

            if($type eq 'centromere'){
                if(!($bioperlFeatureTree->has_tag("ID"))){
                    $bioperlFeatureTree->add_tag_value("ID",$bioperlSeq->accession());
                }

                $bioperlSeq->add_SeqFeature($bioperlFeatureTree);
            }

	    if($type eq 'STS'){
		if(!($bioperlFeatureTree->has_tag("ID"))){
		    $bioperlFeatureTree->add_tag_value("ID",$bioperlSeq->accession());
		}
		$bioperlSeq->add_SeqFeature($bioperlFeatureTree);
	    }
	    if ($type eq 'gene') {

		$geneFeature = $bioperlFeatureTree; 
		if(!($geneFeature->has_tag("ID"))){
		    $geneFeature->add_tag_value("ID",$bioperlSeq->accession());
		}   

		for my $tag ($geneFeature->get_all_tags) {    
		    
		    if($tag eq 'pseudo'){

			if ($geneFeature->get_SeqFeatures){
			    next;
			}else{
			    $geneFeature->primary_tag("coding_gene");
			    my $geneLoc = $geneFeature->location();
			    my $transcript = &makeBioperlFeature("transcript", $geneLoc, $bioperlSeq);
			    my @exonLocs = $geneLoc->each_Location();
			    foreach my $exonLoc (@exonLocs){
				my $exon = &makeBioperlFeature("exon",$exonLoc,$bioperlSeq);
				$transcript->add_SeqFeature($exon);
			    }
			    $geneFeature->add_SeqFeature($transcript);
			    $bioperlSeq->add_SeqFeature($geneFeature);
			}
			
		    }
		}       
		my ($geneArrayRef,$UTRArrayRef,$polypeptideRef) = &traverseSeqFeatures($geneFeature, $bioperlSeq,\%polypeptide);

		my @UTRs = @{$UTRArrayRef};
		
		my @genes = @{$geneArrayRef};

		%polypeptide = %{$polypeptideRef};

		
		

		foreach my $gene (@genes){
		    $bioperlSeq->add_SeqFeature($gene);
		}
		
		foreach my $UTR (@UTRs){


		#    print STDERR Dumper $UTR;
		    $bioperlSeq->add_SeqFeature($UTR);
		}

	    
	    }else{

		if($type eq 'gap' || $type eq 'direct_repeat' || $type eq 'three_prime_UTR' || $type eq 'five_prime_UTR' || $type eq 'splice_acceptor_site'){
		    $bioperlSeq->add_SeqFeature($bioperlFeatureTree);
		}
	    }

	}
    
    foreach my $rnaId (keys %polypeptide){

	if(!($polypeptide{$rnaId}->{flag})){
	    print STDERR "Error: No genes/mRNAs for this polypeptide : $rnaId\n";
	}
    }

}

sub traverseSeqFeatures {
    my ($geneFeature, $bioperlSeq,$polypeptideHashRef) = @_;
    
    my (@genes,$gene,@UTRs);

    my %polypeptide = %{$polypeptideHashRef};
    my @RNAs = $geneFeature->get_SeqFeatures;

    my $transcriptFlag = 0;




    # This will accept genes of type misc_feature (e.g. cgd4_1050 of GI:46229367)
    # because it will have a geneFeature but not standalone misc_feature 
    # as found in GI:32456060.
    # And will accept transcripts that do not have 'gene' parents (e.g. tRNA
    # in GI:32456060)

    my $transcriptCount = scalar @RNAs;

    my $ctr = 1;


    foreach my $RNA (sort {$a->location->start <=> $b->location->start || $a->location->end <=> $b->location->end} @RNAs){ 
	my $type = $RNA->primary_tag;
        if (grep {$type eq $_} (
             'mRNA',
             'misc_RNA',
             'rRNA',
             'snRNA',
             'snoRNA',
             'tRNA',
             'ncRNA',
	     'pseudogenic_transcript',	
             'scRNA',
				
             )
        ) {


	    my ($CDSLocation,$rnaId);
	    
	   # print STDERR "-----------------$type----------------------\n";

	    if($type eq 'ncRNA'){
		if($RNA->has_tag('ncRNA_class')){
		    ($type) = $RNA->get_tag_values('ncRNA_class');
		    $RNA->remove_tag('ncRNA_class');

		}
	    }
	    if($type eq 'pseudogenic_transcript'){
	
		$RNA->add_tag_value("pseudo","");
		($rnaId) = $RNA->get_tag_values('ID');
		if ($polypeptide{$rnaId}){
		    $type = 'coding';
		    $RNA = &copyQualifiers($polypeptide{$rnaId},$RNA);
		    $CDSLocation  = $polypeptide{$rnaId}->location;
		    $polypeptide{$rnaId}->{flag} = 1;
		}else{
		    print STDERR "Missing polypeptide for: $rnaId\n";
		}
		    

	    }

	    if($type eq 'mRNA'){
		$type = 'coding';
		($rnaId) = $RNA->get_tag_values('ID');

		if($polypeptide{$rnaId}){
		    $RNA = &copyQualifiers($polypeptide{$rnaId},$RNA);
		    $polypeptide{$rnaId}->{flag} = 1;
		}else{
		    print STDERR "Missing polypeptide for: $rnaId\n";
		}

		$CDSLocation  = $polypeptide{$rnaId}->location;
	    }
	    $gene = &makeBioperlFeature("${type}_gene", $geneFeature->location, $bioperlSeq);
	    my($geneID) = $geneFeature->get_tag_values('ID');

	    my($parentID) = $RNA->get_tag_values('Parent') if $RNA->has_tag('Parent');
	    if($transcriptCount > 1){
		
		$rnaId =~ s/\:mRNA$//g;
		if($rnaId eq $geneID){
		    $geneID = $rnaId."\.$ctr";
		}else{
		    $geneID = $rnaId;
		}

		$ctr++;
		
	    }
	    
	    #print "ID:$geneID\n";
	    $gene->add_tag_value("ID",$geneID);
	    $gene = &copyQualifiers($geneFeature, $gene);
            $gene = &copyQualifiers($RNA,$gene);
	    $gene->add_tag_value("parentID",$parentID);

	    my $transcript = &makeBioperlFeature("transcript", $RNA->location, $bioperlSeq);
  	    #$transcript = &copyQualifiers($RNA,$transcript);

	    my @containedSubFeatures = $RNA->get_SeqFeatures;
	    
	    my $codonStart = 0;
	    
	    
	    ($codonStart) = $gene->get_tag_values('codon_start') if $gene->has_tag('codon_start');

	    if($gene->has_tag('selenocysteine')){
		$gene->remove_tag('selenocysteine');
		$gene->add_tag_value('selenocysteine','selenocysteine');
	    }

	    $codonStart -= 1 if $codonStart > 0;

	    my (@fixedExons, $prevExon);
	    
	    my ($codingStart, $codingEnd);
	    my $exonType = '';
	    my $prevExonType = '';
	    
	    foreach my $subFeature (sort {$a->location->start <=> $b->location->start} @containedSubFeatures){
		$exonType = '';
		if($subFeature->primary_tag eq 'region'){
		    my($exonId) = $subFeature->get_tag_values('ID') if $subFeature->has_tag('ID');
		    
		    #print STDERR "$id\n";
		    if($exonId =~ /splice acceptor/i || $exonId =~ /splice addition/i){
			#print STDERR "Splice Acceptor\n";
			$subFeature->primary_tag('splice_acceptor_site');
		    }

		
		}

		if ($subFeature->primary_tag eq 'five_prime_UTR' || $subFeature->primary_tag eq 'three_prime_UTR' || $subFeature->primary_tag eq 'splice_acceptor_site'){
		    


		    $exonType = $subFeature->primary_tag;
		    my $UTR = &makeBioperlFeature($subFeature->primary_tag,$subFeature->location,$bioperlSeq);

		    
		    $UTR = &copyQualifiers($subFeature,$UTR);

		    my($exonID) = $subFeature->get_tag_values('ID') if $subFeature->has_tag('ID');
		    my($parent) = $subFeature->get_tag_values('Parent') if $subFeature->has_tag('Parent');
		    $UTR->add_tag_value('ID',$exonID) if $exonID;
		    $UTR->add_tag_value('Parent',$parent) if $parent;
		    
		    
		    $subFeature->primary_tag('exon');
		    push(@UTRs, $UTR);

			if(($polypeptide{$rnaId}->location->start <= $subFeature->location->start && $polypeptide{$rnaId}->location->end >= $subFeature->location->end)){

			    next;
			}
		}elsif($type eq 'coding'){
		    $exonType = 'coding';

		    $codonStart = $subFeature->frame();
		}else{
		    $exonType = 'non_coding';

		}
		if($subFeature->primary_tag eq 'pseudogenic_exon' || $subFeature->primary_tag eq 'CDS'){
		    $subFeature->primary_tag('exon');
		   
		}

		if($exonType eq 'coding'){
		    if($subFeature->location->strand == -1){

			$codingStart = $subFeature->location->end;
			$codingEnd = $subFeature->location->start;
			
			if($codingStart eq $CDSLocation->end && $codonStart > 0){
			    $codingStart -= $codonStart;
			}
			$subFeature->add_tag_value('CodingStart',$codingStart);
			$subFeature->add_tag_value('CodingEnd',$codingEnd);
		    }else{
			
			$codingStart = $subFeature->location->start;
			$codingEnd = $subFeature->location->end;
				    
			if($codingStart eq $CDSLocation->start && $codonStart > 0){
			    $codingStart += $codonStart;
			}
			$subFeature->add_tag_value('CodingStart',$codingStart);
			$subFeature->add_tag_value('CodingEnd',$codingEnd);
		    }
		    $subFeature->add_tag_value('type','coding');
		}

		if($prevExon){
		    
		    if($prevExon->location->end >= $subFeature->location->start - 1){

			pop(@fixedExons);

			$subFeature->location->start($prevExon->location->start);

			if($prevExonType eq 'coding'){
			    $subFeature->remove_tag('type') if $subFeature->has_tag('type');
			    $subFeature->add_tag_value('type','coding');

			    $exonType = 'coding';
			    ($codingEnd) = $prevExon->get_tag_values('CodingEnd');
			    ($codingStart) = $prevExon->get_tag_values('CodingStart');
			    if($subFeature->location->strand == -1){
				
				if ($subFeature->has_tag('CodingEnd')){
				    $subFeature->remove_tag('CodingEnd') ;
				    $subFeature->add_tag_value('CodingEnd',$codingEnd);
				}else{
				    my($prevExonId) = $prevExon->get_tag_values('ID');
				    if ($subFeature->has_tag('ID')){
					$subFeature->remove_tag('ID') ;
					$subFeature->add_tag_value('ID',$prevExonId);
				    }
				    $subFeature->add_tag_value('CodingEnd',$codingEnd);
				    $subFeature->add_tag_value('CodingStart',$codingStart);				    
				}
			    }else{

				if($subFeature->has_tag('CodingStart')){
				    $subFeature->remove_tag('CodingStart');
				    $subFeature->add_tag_value('CodingStart',$codingStart);
				}else{
				    my($prevExonId) = $prevExon->get_tag_values('ID');
				    if ($subFeature->has_tag('ID')){
					$subFeature->remove_tag('ID') ;
					$subFeature->add_tag_value('ID',$prevExonId);
				    }
				    $subFeature->add_tag_value('CodingEnd',$codingEnd);
				    $subFeature->add_tag_value('CodingStart',$codingStart);
				}
			    }	    
			    
			}
		       

		    }


		}

		$prevExon = $subFeature;
		$prevExonType = $exonType;
		push @fixedExons , $subFeature;
	    }
	
		

	    my $CDSLength = 0;
	    my $first = 0;
	    my $last = 0;
	    my $exonCtr = 0;
	    foreach my $exon (sort {$a->location->start() <=> $b->location->start()} @fixedExons){
		if($gene->primary_tag ne 'coding_gene' && $gene->primary_tag ne 'pseudo_gene' ){
		    $exon->add_tag_value('CodingStart', '');
		    $exon->add_tag_value('CodingEnd', '');	
		}else{
		    if(!($exon->has_tag('CodingStart'))){
			$exon->add_tag_value('CodingStart', '');
			$exon->add_tag_value('CodingEnd', '');	
			if($exonCtr == $first){
			    $first++;
			}

		    }else{
			my ($cStart) = $exon->get_tag_values('CodingStart');
			my ($cEnd) = $exon->get_tag_values('CodingEnd');
			$CDSLength += (abs($cEnd - $cStart)+1);
			$last = $exonCtr;
		    }
		   
		}
		$exonCtr++;


	    }

	    
	    my $trailingNAs = $CDSLength%3;
	    $transcript->add_tag_value("CDSLength",$CDSLength);


	    $exonCtr=0;

	  foreach my $exon (sort {$a->location->start() <=> $b->location->start()} @fixedExons){

	      
	      if($exon->location->strand() == -1){
		  if($exonCtr == $first  && $trailingNAs > 0){
		      if($exon->has_tag("CodingStart")){
			  my($codingEnd) = $exon->get_tag_values("CodingEnd");

			  if($codingEnd ne ''){
			      $exon->remove_tag("CodingEnd");
			      $exon->add_tag_value("CodingEnd",$codingEnd+$trailingNAs);
			  }			  
		      }
		  }		  
		  
	      }else{
		  if($exonCtr == $last && $trailingNAs > 0){
		      if($exon->has_tag("CodingEnd")){
			  my($codingEnd) = $exon->get_tag_values("CodingEnd");
			  if($codingEnd ne ''){
			      $exon->remove_tag("CodingEnd");
			      $exon->add_tag_value("CodingEnd",$codingEnd-$trailingNAs);
			  }			  
		      }
		  }
	      }


	      $exonCtr++;
	      $transcript->add_SeqFeature($exon);
	  }

	    
	    if(!($transcript->get_SeqFeatures())){
		my @exonLocs = $RNA->location->each_Location();
		foreach my $exonLoc (@exonLocs){
		    my $exon = &makeBioperlFeature("exon",$exonLoc,$bioperlSeq);
		    $transcript->add_SeqFeature($exon);
		    if($gene->primary_tag ne 'coding_gene' && $gene->primary_tag ne 'pseudo_gene' ){
			$exon->add_tag_value('CodingStart', '');
			$exon->add_tag_value('CodingEnd', '');	
		    }else{
			if(!($exon->has_tag('CodingStart'))){
			    $exon->add_tag_value('CodingStart', '');
			    $exon->add_tag_value('CodingEnd', '');	
			}
		    }

		}
	    }

	    
	    if($gene->location->start > $transcript->location->start){
		print STDERR "The transcript for gene $geneID is not within parent boundaries.\n";
		$gene->location->start($transcript->location->start);
	    }

	    
	    if($gene->location->end < $transcript->location->end){
		print STDERR "The transcript for gene $geneID is not within parent boundaries.\n";
		$gene->location->end($transcript->location->end);
	    }

	    
	    $gene->add_SeqFeature($transcript);
	    push(@genes,$gene);


	}
    }
    return (\@genes,\@UTRs,\%polypeptide);
}


sub copyQualifiers {
  my ($geneFeature, $bioperlFeatureTree) = @_;
  
  for my $qualifier ($geneFeature->get_all_tags()) {

    if ($bioperlFeatureTree->has_tag($qualifier) && $qualifier ne "ID" && $qualifier ne "Parent" && $qualifier ne "Derives_from") {
      # remove tag and recreate with merged non-redundant values
      my %seen;
      my @uniqVals = grep {!$seen{$_}++} 
                       $bioperlFeatureTree->remove_tag($qualifier), 
                       $geneFeature->get_tag_values($qualifier);
                       
      $bioperlFeatureTree->add_tag_value(
                             $qualifier, 
                             @uniqVals
                           );    
    } elsif($qualifier ne "ID" && $qualifier ne "Parent" && $qualifier ne "Derives_from") {
      $bioperlFeatureTree->add_tag_value(
                             $qualifier,
                             $geneFeature->get_tag_values($qualifier)
                           );
    }
     
  }
  return $bioperlFeatureTree;
}

1;
