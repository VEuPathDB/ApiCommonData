package ApiCommonData::Load::GenesAndCdsWithUTRs2BioperlTree;
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

	foreach my $bioperlFeatureTree (@seqFeatures){
	    my $type = $bioperlFeatureTree->primary_tag();

#	    print "$type\n";
	    if($type eq 'polypeptide'){
		my($id) = $bioperlFeatureTree->get_tag_values("Derives_from") if $bioperlFeatureTree->has_tag("Derives_from");
		#$bioperlFeatureTree->primary_tag("CDS");

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

		if (($geneFeature->has_tag("ID"))){
			my ($cID) = $geneFeature->get_tag_values("ID");
			print STDERR "processing $cID...\n";
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
		my ($gene,$UTRArrayRef) = &traverseSeqFeatures($geneFeature, $bioperlSeq,\%polypeptide);

		my @UTRs = @{$UTRArrayRef};
		if($gene){

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
}

sub traverseSeqFeatures {
    my ($geneFeature, $bioperlSeq,$polypeptideHashRef) = @_;
    
    my ($gene,@UTRs);

    my %polypeptide = %{$polypeptideHashRef};
    my @RNAs = $geneFeature->get_SeqFeatures;

    # This will accept genes of type misc_feature (e.g. cgd4_1050 of GI:46229367)
    # because it will have a geneFeature but not standalone misc_feature 
    # as found in GI:32456060.
    # And will accept transcripts that do not have 'gene' parents (e.g. tRNA
    # in GI:32456060)
    foreach my $RNA (@RNAs){ 
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


	    my $CDSLocation;
	    
	   # print STDERR "-----------------$type----------------------\n";

	    if($type eq 'ncRNA'){
		if($RNA->has_tag('ncRNA_class')){
		    ($type) = $RNA->get_tag_values('ncRNA_class');
		    $RNA->remove_tag('ncRNA_class');

		}
	    }
	    if($type eq 'pseudogenic_transcript'){
	
		$RNA->add_tag_value("pseudo","");
		my($id) = $RNA->get_tag_values('ID');
		if ($polypeptide{$id}){
		    $type = 'coding';

		    $RNA = &copyQualifiers($polypeptide{$id},$RNA);
		    $CDSLocation  = $polypeptide{$id}->location;
		}
		    

	    }

	    if($type eq 'mRNA'){
		$type = 'coding';
		my($id) = $RNA->get_tag_values('ID');
		$RNA = &copyQualifiers($polypeptide{$id},$RNA) if $polypeptide{$id};
		#print STDERR "Missing poly: $id\n";
		$CDSLocation  = $polypeptide{$id}->location;
	    }
	    #$gene = &makeBioperlFeature("${type}_gene", $geneFeature->location, $bioperlSeq);
	    $gene = &makeBioperlFeature("${type}_gene", $RNA->location, $bioperlSeq);  ## for gene use transcript location instead of gene location
	    my($geneID) = $geneFeature->get_tag_values('ID');

	    #print "ID:$geneID\n";
	    $gene->add_tag_value("ID",$geneID);
	    $gene = &copyQualifiers($geneFeature, $gene);
            $gene = &copyQualifiers($RNA,$gene);
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
	    
	    foreach my $subFeature (sort {$a->location->start <=> $b->location->start} @containedSubFeatures){
		$exonType = '';
		if($subFeature->primary_tag eq 'region'){
		    my($id) = $subFeature->get_tag_values('ID') if $subFeature->has_tag('ID');
		    
		    #print STDERR "$id\n";
		    if($id =~ /splice acceptor/i){
			#print STDERR "Splice Acceptor\n";
			$subFeature->primary_tag('splice_acceptor_site');
		    }

		
		}

		if ($subFeature->primary_tag eq 'five_prime_UTR' || $subFeature->primary_tag eq 'three_prime_UTR' || $subFeature->primary_tag eq 'splice_acceptor_site'){
		    

		   my $UTR = &makeBioperlFeature($subFeature->primary_tag,$subFeature->location,$bioperlSeq);

		    
		   $UTR = &copyQualifiers($subFeature,$UTR);

		   my($exonID) = $subFeature->get_tag_values('ID') if $subFeature->has_tag('ID');
		   my($parent) = $subFeature->get_tag_values('Parent') if $subFeature->has_tag('Parent');
		   $UTR->add_tag_value('ID',$exonID) if $exonID;
		   $UTR->add_tag_value('Parent',$parent) if $parent;
		    
		    
#		   print STDERR Dumper $subFeature;
		    push(@UTRs, $UTR);
		    

		    my($type) = $prevExon->get_tag_values('type') if ($prevExon && $prevExon->has_tag('type'));
	
		   # print STDERR "Hello\t$exonID\n";

		    if($prevExon){
		#	print STDERR Dumper $prevExon;
		    }

		 #   print STDERR Dumper $subFeature;
#		    if($prevExon){
	#		print STDERR "$geneID:$exonID:$type:Outside:".$subFeature->primary_tag.":PrevExonStart:".$prevExon->location->start().":PrevExonEnd:".$prevExon->location->end().":SubFeatureStart".$subFeature->location->start().":SubFeatureEnd".$subFeature->location->end()."\n";
		#    }
		    if($prevExon && $prevExon->location->end() == $subFeature->location->start() - 1){
			#print STDERR "$geneID:1stLoop:".$subFeature->primary_tag.":$exonID\n";
			pop @fixedExons;
			$prevExon->location->end($subFeature->location->end);
			  
			push @fixedExons, $prevExon;
		    }elsif(($prevExon && $prevExon->location->end() < $subFeature->location->start() - 1) || !($prevExon)){			
		
		#	print STDERR "$geneID:$exonID:2ndLoop:".$subFeature->primary_tag.":".$prevExon->location->end().":".$subFeature->location->start()."\n";
		 
#			my $utrType = $subFeature->primary_tag();
			$subFeature->add_tag_value('type','utr');
			$subFeature->primary_tag('exon');
			push @fixedExons , $subFeature;
			$prevExon = $subFeature;
		    }elsif($prevExon && ($prevExon->location->end() < $subFeature->location->end()) && ($subFeature->location->start() < $prevExon->location->end)){
			#print STDERR "$geneID:$exonID:3rdLoop:".$subFeature->primary_tag."\n";

			if($type eq 'utr'){
			    pop @fixedExons;

			    $prevExon = $fixedExons[$#fixedExons];
			}else{

			     
			    $prevExon->location->end((($codingStart > $codingEnd)?$codingStart:$codingEnd));

			}

			#print STDERR "$geneID:$exonID:$type:Outside:".$subFeature->primary_tag.":PrevExonStart:".$prevExon->location->start().":PrevExonEnd:".$prevExon->location->end().":SubFeatureStart".$subFeature->location->start().":SubFeatureEnd".$subFeature->location->end()."\n";
			if($prevExon && $prevExon->location->end() == $subFeature->location->start() - 1){
			 #   print STDERR "$geneID:1stLoop:".$subFeature->primary_tag.":$exonID\n";
			    pop @fixedExons;
			    $prevExon->location->end($subFeature->location->end);
			  
			    push @fixedExons, $prevExon;
			}elsif(($prevExon && $prevExon->location->end() < $subFeature->location->start() - 1) || !($prevExon)){			
			  
				#print STDERR "$geneID:$exonID:2ndLoop:".$subFeature->primary_tag.":".$prevExon->location->end().":".$subFeature->location->start()."\n";

			    $subFeature->add_tag_value('type','utr');
			    $subFeature->primary_tag('exon');
			    push @fixedExons , $subFeature;
			    $prevExon = $subFeature;
			}

		    }
		    $exonType = 'UTR';

		}
		if($subFeature->primary_tag eq 'pseudogenic_exon'){
		    $subFeature->primary_tag('exon');
		}
		if($subFeature->primary_tag eq 'exon' && $exonType ne 'UTR'){
		    #print STDERR "In loop: 1: $exonType\n";
		    $exonType = 'exon';
		    my $prevType = '';
		    if($prevExon){
			($prevType) = $prevExon->get_tag_values('type') if $prevExon->has_tag('type');
		    }
		    if($prevExon && $prevExon->location->end() == $subFeature->location->start() - 1 && $prevType eq 'utr'){

			    #print STDERR "In loop:$exonType\n";
			    pop @fixedExons;
			    if($type eq 'coding'){
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
				$subFeature->add_tag_value('type','coding_exon');
			    }
			    $subFeature->location->start($prevExon->location->start);
			    $prevExon = $subFeature;
			    push @fixedExons , $subFeature;

			}else{

			    if($type eq 'coding'){
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
				$subFeature->add_tag_value('type','coding_exon');
			    }else{
				$subFeature->add_tag_value('type','non_coding_exon');
				
			    }
			    $prevExon = $subFeature;
			    push @fixedExons , $subFeature;
			}

		}
		
	    }

	    foreach my $exon (@fixedExons){

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


	}
    }
    return ($gene,\@UTRs);
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
