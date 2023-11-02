package ApiCommonData::Load::GenemRNACdsUtr2BioperlTree;
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
#^^^^^^^^^^^^^^^^^^^^^^^^^ End GUS4_STATUS ^^^^^^^^^^^^^^^^^^^^

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
# UTRs
#
#output: standard api tree: gene->transcript->exons

# (0) remove all seq features, add back the non-genes
# (1) copy old gene qualifiers to cds/rna feature
# (2) retype CDS into Gene
# (3) remember its join locations
# (4) create transcript
# (5) add to gene
# (6) create exons from sublocations
# (7) add to transcript


sub preprocess {
    my ($bioperlSeq, $plugin) = @_;

    my ($geneFeature, $source);

    my @topSeqFeatures = $bioperlSeq->remove_SeqFeatures;

    OUTER: foreach my $bioperlFeatureTree (@topSeqFeatures) {
        my $type = $bioperlFeatureTree->primary_tag();
        
        if($type eq 'pseudogene'){
	  $bioperlFeatureTree->primary_tag('gene');
	  $bioperlFeatureTree->add_tag_value("pseudo","");
	  $type = 'gene';
        }

        if($type eq 'tRNA'){
            $bioperlFeatureTree->primary_tag('tRNA_gene');
            if ( !($bioperlFeatureTree->get_SeqFeatures )) {
                my $geneLoc = $bioperlFeatureTree->location();
                my $transcript = &makeBioperlFeature("transcript", $geneLoc, $bioperlSeq);
                my @exonLocs = $geneLoc->each_Location();
                foreach my $exonLoc (@exonLocs) {
                    my $exon = &makeBioperlFeature("exon",$exonLoc,$bioperlSeq);
                    $transcript->add_SeqFeature($exon);
                }
                $bioperlFeatureTree->add_SeqFeature($transcript);
            }
            $bioperlSeq->add_SeqFeature($bioperlFeatureTree);
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
	      die "Feature $type does not have tag: ID\n";
            } else {
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
			next OUTER;
                    }
                }
            }       

            my ($geneArrayRef,$UTRArrayRef) = &traverseSeqFeatures($geneFeature, $bioperlSeq);

            my @genes = @{$geneArrayRef};
            foreach my $gene (@genes) {
                $bioperlSeq->add_SeqFeature($gene);
            }
            
            my @UTRs = @{$UTRArrayRef};
            foreach my $UTR (@UTRs){
                #print STDERR Dumper $UTR;
                $bioperlSeq->add_SeqFeature($UTR);
            }
        
        }else{

            if($type eq 'gap' || $type eq 'direct_repeat' || $type eq 'three_prime_utr' 
                            || $type eq 'five_prime_utr' || $type eq 'splice_acceptor_site' || $type eq 'UTR'){
                $bioperlSeq->add_SeqFeature($bioperlFeatureTree);
            }
        }

    }
}

sub traverseSeqFeatures {
    my ($geneFeature, $bioperlSeq) = @_;
    
    my (@genes, $gene, @UTRs);

    my @RNAs = $geneFeature->get_SeqFeatures;

    my $transcriptCount = scalar @RNAs;
    my $ctr = 1;

    foreach my $RNA ( sort {$a->location->start <=> $b->location->start || $a->location->end <=> $b->location->end} @RNAs){ 

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


        if($type eq 'ncRNA'){
            if($RNA->has_tag('ncRNA_class')){
                ($type) = $RNA->get_tag_values('ncRNA_class');
		$type = ($type =~ /other/i) ? "ncRNA" : $type;
                $RNA->remove_tag('ncRNA_class');
            }
        }

	if ($type eq 'mRNA' || $type eq 'pseudogenic_transcript') {
	  $type = 'coding';
	  if ($type eq 'pseudogenic_transcript') {
	    $RNA->add_tag_value("pseudo","");
	  }
	}

	my($geneID) = $geneFeature->get_tag_values('ID');
	if (!$gene) {    ## only create one gene for multiple transcript
	  $gene = &makeBioperlFeature("${type}_gene", $geneFeature->location, $bioperlSeq);
	  $gene->add_tag_value("ID",$geneID);
	  $gene = &copyQualifiers($geneFeature, $gene);
	}

#	my $transcript = &makeBioperlFeature("transcript", $RNA->location, $bioperlSeq);
	my $transType = $type;
	$transType = "mRNA" if ($transType eq "coding");
	my $transcript = &makeBioperlFeature("$transType", $RNA->location, $bioperlSeq);

	my ($rnaID) = ($RNA->get_tag_values('ID')) ? $RNA->get_tag_values('ID') : die "ERROR: missing rna gene id for $geneID\n";
	$transcript->add_tag_value("ID", $rnaID);
	$transcript = &copyQualifiers($RNA, $transcript);
	$transcript->add_tag_value("pseudo", "") if ($geneFeature->has_tag("pseudo") && !$RNA->has_tag("pseudo"));


        my @containedSubFeatures = $RNA->get_SeqFeatures;

        if($gene->has_tag('selenocysteine')){
            $gene->remove_tag('selenocysteine');
            $gene->add_tag_value('selenocysteine','selenocysteine');
        }

        my (@exons, @codingStartAndEndPairs);

        my $CDSctr =0;

        foreach my $subFeature (sort {$a->location->start <=> $b->location->start} @containedSubFeatures){

            #if($subFeature->primary_tag eq 'exon'){

	  #    my $exon = &makeBioperlFeature($subFeature->primary_tag,$subFeature->location,$bioperlSeq);
            #    push(@exons,$exon);
            #}

            if($subFeature->primary_tag eq 'CDS'  || $subFeature->primary_tag eq 'pseudogenic_exon' ){

                my $exon = &makeBioperlFeature("exon",$subFeature->location,$bioperlSeq);
                $exon = &copyQualifiers($subFeature, $exon);
		$exon->add_tag_value('exonType', "coding");
		push (@exons, $exon);

		my $cdsStrand = $subFeature->location->strand;
		my $cdsFrame = $subFeature->frame();

                if($subFeature->location->strand == -1){
		  my $cdsCodingStart = $subFeature->location->end;
		  my $cdsCodingEnd = $subFeature->location->start;
		  push (@codingStartAndEndPairs, "$cdsCodingStart\t$cdsCodingEnd\t$cdsStrand\t$cdsFrame");
                }else{
                  my $cdsCodingStart = $subFeature->location->start;
                  my $cdsCodingEnd = $subFeature->location->end;
		  push (@codingStartAndEndPairs, "$cdsCodingStart\t$cdsCodingEnd\t$cdsStrand\t$cdsFrame");
                }

                $CDSctr++;
            }

            if ($subFeature->primary_tag =~ /five_prime_utr/i || $subFeature->primary_tag =~ /three_prime_utr/i
                    || $subFeature->primary_tag eq 'UTR'){
                
                my $UTR = &makeBioperlFeature($subFeature->primary_tag,$subFeature->location,$bioperlSeq);

                $UTR = &copyQualifiers($subFeature,$UTR);

                my($utrID) = $subFeature->get_tag_values('ID') if $subFeature->has_tag('ID');
                my($utrParent) = $subFeature->get_tag_values('Parent') if $subFeature->has_tag('Parent');
                $UTR->add_tag_value('ID',$utrID) if $utrID;
                $UTR->add_tag_value('Parent',$utrParent) if $utrParent;

                push(@UTRs,$UTR);

		# if UTR is not in exon, it needs to add to exon
		my $exon = &makeBioperlFeature("exon",$subFeature->location,$bioperlSeq);
		$exon->add_tag_value('exonType', "nonCoding");
		push (@exons, $exon);
            }
        }

	## combine the UTR with CDS if they are adjacent
	my @fixedExons;
	my @sortExons = sort {$a->location->start <=> $b->location->start} @exons;
	foreach my $i (0..$#sortExons) {
	  if ($sortExons[$i+1]) {
	    my ($exonType) = $sortExons[$i]->get_tag_values('exonType');
	    my ($nextExonType) = $sortExons[$i+1]->get_tag_values('exonType');
	    if (  ( $sortExons[$i+1]->location->start <= $sortExons[$i]->location->end +1 )
	       && ($exonType ne $nextExonType ) ) {
	      $sortExons[$i+1]->location->start($sortExons[$i]->location->start);
	      $sortExons[$i+1]->remove_tag('exonType');
	      $sortExons[$i+1]->add_tag_value('exonType', "coding");
	    } else {
	      push (@fixedExons, $sortExons[$i]);
	    }
	  } else {
	    push (@fixedExons, $sortExons[$i]);
	  }
	}

	## deal with codonStart, use the frame of the 1st CDS to assign codonStart
	foreach my $j (0..$#codingStartAndEndPairs) {
	  my ($start, $end, $strand, $frame) = split (/\t/, $codingStartAndEndPairs[$j]);
	  if ($j == 0 && $strand ==1 && $frame > 0) {
	    $start += $frame;
	    $codingStartAndEndPairs[$j] = "$start\t$end\t$strand\t$frame";
	  } elsif ($j == $#codingStartAndEndPairs && $strand == -1 && $frame > 0) {
	    $start -= $frame;
	    $codingStartAndEndPairs[$j] = "$start\t$end\t$strand\t$frame";
	  } 
	}

	## add codingStart and codingEnd
	my ($codingStart, $codingEnd) = split(/\t/, shift(@codingStartAndEndPairs) );
	foreach my $exon (@fixedExons){

	  if($codingStart <= $exon->location->end && $codingStart >= $exon->location->start){
	    $exon->add_tag_value('CodingStart',$codingStart);
	    $exon->add_tag_value('CodingEnd',$codingEnd);
	    ($codingStart, $codingEnd) = split(/\t/, shift(@codingStartAndEndPairs) );
	  } else {
	    $exon->add_tag_value('CodingStart',"");
	    $exon->add_tag_value('CodingEnd',"");
	  }

	  $transcript->add_SeqFeature($exon);
	}

	## for RNA that does not have subFeature
        if(!($transcript->get_SeqFeatures())){
            my @exonLocs = $RNA->location->each_Location();
            foreach my $exonLoc (@exonLocs){
                my $exon = &makeBioperlFeature("exon",$exonLoc,$bioperlSeq);
                if($gene->primary_tag ne 'coding_gene' && $gene->primary_tag ne 'pseudo_gene' ){
                    $exon->add_tag_value('CodingStart', '');
                    $exon->add_tag_value('CodingEnd', '');  
                } else {
		  if($exonLoc->location->strand == -1){
		    $exon->add_tag_value('CodingStart', $exonLoc->location->end);
		    $exon->add_tag_value('CodingEnd', $exonLoc->location->start);
		  }else{
		    $exon->add_tag_value('CodingStart', $exonLoc->location->start);
		    $exon->add_tag_value('CodingEnd', $exonLoc->location->end);
		  }
		}
                $transcript->add_SeqFeature($exon);
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
    push(@genes, $gene);
    return (\@genes ,\@UTRs);
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
