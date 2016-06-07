package ApiCommonData::Load::gencodeGFF2BioperlTree;
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
    my  $primerPair = '';

    my @topSeqFeatures = $bioperlSeq->remove_SeqFeatures;

    foreach my $bioperlFeatureTree (@topSeqFeatures) {
        my $type = $bioperlFeatureTree->primary_tag();

        if($type eq 'pseudogene'){
	  $bioperlFeatureTree->primary_tag('gene');
	  $bioperlFeatureTree->add_tag_value("pseudo","");
	  $type = "gene";
        }

	## for tRNA that do not have gene as parent
        if($type eq 'tRNA'){
	  $geneFeature = $bioperlFeatureTree;

	  my $geneLoc = $geneFeature->location();
	  my $gene = &makeBioperlFeature("${type}_gene", $geneLoc, $bioperlSeq);
	  my($geneID) = $geneFeature->get_tag_values('ID');
	  $gene->add_tag_value("ID",$geneID);
	  $gene = &copyQualifiers($geneFeature, $gene);

	  my $transcript = &makeBioperlFeature("transcript", $geneLoc, $bioperlSeq);
	  my $transcriptID = $geneID.".$type";
	  $transcript->add_tag_value("ID", $transcriptID);
	  $transcript->add_tag_value("Parent", $geneID);

	  my @exonLocs = $geneLoc->each_Location();
	  foreach my $exonLoc (@exonLocs){
	    my $exon = &makeBioperlFeature("exon",$exonLoc,$bioperlSeq);
	    $exon->add_tag_value('CodingStart', '');
	    $exon->add_tag_value('CodingEnd', '');
	    $transcript->add_SeqFeature($exon);
	  }
	  $gene->add_SeqFeature($transcript);
	  $bioperlSeq->add_SeqFeature($gene);
        } ## end of $type eq tRNA

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

	    my $gID;
	    if (!($geneFeature->has_tag("ID"))){
	      die "Feature $type does not have tag: ID\n";
	    } else {
	      ($gID) = $geneFeature->get_tag_values("ID");
	      print STDERR "processing $gID...\n";
	    }

            if($geneFeature->has_tag("gene_type")){
                my($geneType) = $geneFeature->get_tag_values("gene_type");

                if($geneType =~ /pseudogene/i){
                    $geneFeature->add_tag_value("pseudo","");
                }
            }

            for my $tag ($geneFeature->get_all_tags) {    
                if($tag eq 'pseudo'){
                    if ($geneFeature->get_SeqFeatures){
                        next;
                    }else{
                        $geneFeature->primary_tag("coding_gene");
                        my $geneLoc = $geneFeature->location();
                        my $transcript = &makeBioperlFeature("transcript", $geneLoc, $bioperlSeq);
			$transcript->add_tag_value("ID", $gID.".mRNA");
			$transcript->add_tag_value("pseudo","");

                        my @exonLocs = $geneLoc->each_Location();
                        foreach my $exonLoc (@exonLocs){
                            my $exon = &makeBioperlFeature("exon",$exonLoc,$bioperlSeq);
			    if ($exonLoc->strand == -1){
			      $exon->add_tag_value('CodingStart', $exonLoc->end());
			      $exon->add_tag_value('CodingEnd', $exonLoc->start());
			    } else {
			      $exon->add_tag_value('CodingStart', $exonLoc->start());
			      $exon->add_tag_value('CodingEnd', $exonLoc->end());
			    }

                            $transcript->add_SeqFeature($exon);
                        }
                        $geneFeature->add_SeqFeature($transcript);
                        $bioperlSeq->add_SeqFeature($geneFeature);
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

    foreach my $RNA ( sort {$a->location->start <=> $b->location->start || $a->location->end <=> $b->location->end} @RNAs){ 

      my $type = $RNA->primary_tag;

        if (grep {$type eq $_} (
             'transcript',
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

	  my ($geneType, $transType);

	  if($type eq 'transcript' || $type eq 'mRNA'){
            ($geneType) = $geneFeature->get_tag_values("gene_type") if ($geneFeature->has_tag("gene_type"));
            ($transType) = $RNA->get_tag_values("transcript_type") if ($RNA->has_tag("transcript_type"));
            $geneType = &getTypeOfGene($geneType) if ($geneType);
            $transType = &getTypeOfTranscript($transType) if ($transType);
	  }

	  $type = $geneType;

	  if($type eq 'ncRNA'){
            if($RNA->has_tag('ncRNA_class')){
                ($type) = $RNA->get_tag_values('ncRNA_class');
                $RNA->remove_tag('ncRNA_class');
            }
	  }

	  my ($geneID) = $geneFeature->get_tag_values('ID');
	  if (!$gene) { ## only create one gene for multiple transcript
	    $gene = &makeBioperlFeature("${type}_gene", $geneFeature->location, $bioperlSeq) if (!$gene);
	    $gene->add_tag_value("ID", $geneID);
	    $gene = &copyQualifiers($geneFeature, $gene);
	  }

	  my $transcript = &makeBioperlFeature("transcript", $RNA->location, $bioperlSeq);
	  my ($rnaID) = ($RNA->has_tag('ID')) ? $RNA->get_tag_values('ID') : die "ERROR: missing RNA id for gene: $geneID\n";

	  $transcript->add_tag_value("ID", $rnaID);

	  $transcript = &copyQualifiers($RNA, $transcript);

	  ## add pseudo tag for all kind of pseudogene
	  if ($transType =~ /pseudo/i) {
	    $transcript->add_tag_value('pseudo', '') if (!$transcript->has_tag('Pseudo') && !$transcript->has_tag('pseudo'));
	  }

	  if ($gene->has_tag('Partial') || $gene->has_tag('partial')) {
	    $transcript->add_tag_value('partial', '') if (!$transcript->has_tag('Partial') && !$transcript->has_tag('partial'));
	  }


	  my @containedSubFeatures = $RNA->get_SeqFeatures;
	  my $codonStart = 0;

	  my (@exons, @codingStartAndEndPairs);

	  my $CDSctr = 0;
	  my $prevPhase =0;

	  foreach my $subFeature (sort {$a->location->start <=> $b->location->start} @containedSubFeatures){

            if($subFeature->primary_tag eq 'exon'){
                my $exon = &makeBioperlFeature($subFeature->primary_tag,$subFeature->location,$bioperlSeq);
                push(@exons,$exon);
            }

            if($subFeature->primary_tag eq 'CDS'){

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

            if ($subFeature->primary_tag eq 'five_prime_utr' || $subFeature->primary_tag eq 'three_prime_utr' 
                    || $subFeature->primary_tag eq 'splice_acceptor_site' || $subFeature->primary_tag eq 'UTR'){

                my $UTR = &makeBioperlFeature($subFeature->primary_tag,$subFeature->location,$bioperlSeq);

                $UTR = &copyQualifiers($subFeature,$UTR);

                my($utrID) = $subFeature->get_tag_values('ID') if $subFeature->has_tag('ID');
                my($utrParent) = $subFeature->get_tag_values('Parent') if $subFeature->has_tag('Parent');
                $UTR->add_tag_value('ID',$utrID) if $utrID;
                $UTR->add_tag_value('Parent',$utrParent) if $utrParent;

                push(@UTRs,$UTR);
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
	  foreach my $exon (@exons){
            if($codingStart <= $exon->location->end && $codingStart >= $exon->location->start){
	      $exon->add_tag_value('CodingStart',$codingStart);
	      $exon->add_tag_value('CodingEnd',$codingEnd);
	      ($codingStart, $codingEnd) = split(/\t/, shift(@codingStartAndEndPairs) );
	    } elsif  (($codingStart <= $exon->location->start && $codingEnd <= $exon->location->start)
		      || ($codingStart >= $exon->location->end && $codingEnd >= $exon->location->end) ) {
	      $exon->add_tag_value('CodingStart',"");
	      $exon->add_tag_value('CodingEnd',"");
	    } else {
	      die "need to check, testing right now\n";
	    }

            $transcript->add_SeqFeature($exon);
	  }

	  if ($#codingStartAndEndPairs > 0) {
	    my ($errorGene) = $gene->get_tag_values('ID');
	    my ($start, $end) = split (/\t/, shift(@codingStartAndEndPairs) );
	    die "double check the number of CDS for $errorGene has $start..$end ...... it is not consistant with the exon number\n";
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


sub getTypeOfGene {
#    my ($geneType, $transType) = @_;
    my ($geneType) = @_;

    my $returnType = 'just testing';

    my %geneTypes = (
        protein_coding => 'coding',
        IG_C_gene => 'coding',
        IG_D_gene => 'coding',
        IG_J_gene => 'coding',
        IG_V_gene => 'coding',
        TR_C_gene => 'coding',
        TR_D_gene => 'coding',
        TR_J_gene => 'coding',
        TR_V_gene => 'coding',
        IG_C_pseudogene => 'coding',
        IG_J_pseudogene => 'coding',
        IG_V_pseudogene => 'coding',
        TR_J_pseudogene => 'coding',
        TR_V_pseudogene => 'coding',
        TEC => 'coding',
        Mt_rRNA => 'rRNA',
        rRNA => 'rRNA',
        Mt_tRNA => 'tRNA',
        tRNA => 'tRNA',
        tRNAscan => 'tRNA',
        snRNA => 'snRNA',
        snoRNA => 'snoRNA',
        miRNA => 'miRNA',
        lincRNA => 'ncRNA',
#        3prime_overlapping_ncrna => 'ncRNA',  ## comment out since it causes syntax error, code it in if statement
        bidirectional_promoter_lncrna => 'ncRNA',
        non_coding => 'ncRNA',
        macro_lncRNA => 'ncRNA',
        ribozyme => 'ncRNA',
        sRNA => 'ncRNA',
        vaultRNA => 'ncRNA',
        misc_RNA => 'misc_RNA',
        antisense => 'misc_RNA',
        processed_transcript => 'misc_RNA',
        scaRNA => 'misc_RNA',
        sense_intronic => 'misc_RNA',
        sense_overlapping => 'misc_RNA',
    );

    if ($geneTypes{$geneType} ) {
        $returnType = $geneTypes{$geneType};
    } else {
        if ($geneType =~ /pseudogene/ ) {
	  $returnType = "coding";
	} elsif ($geneType =~ /3prime_overlapping_ncrna/) {
	  $returnType = "ncRNA";
        } else {
	  die "geneType '$geneType' has not be coded yet\n";
        }
    }

    return $returnType;
}


sub getTypeOfTranscript {
    my ($geneType, $transType) = @_;

    my $returnType = 'misc_RNA';

    my %transTypes = (
        protein_coding => 'coding',
        IG_C_gene => 'coding',
        IG_D_gene => 'coding',
        IG_J_gene => 'coding',
        IG_V_gene => 'coding',
        TR_C_gene => 'coding',
        TR_D_gene => 'coding',
        TR_J_gene => 'coding',
        TR_V_gene => 'coding',
        IG_C_pseudogene => 'pseudo',
        IG_J_pseudogene => 'pseudo',
        IG_V_pseudogene => 'pseudo',
        TR_J_pseudogene => 'pseudo',
        TR_V_pseudogene => 'pseudo',
        TEC => 'coding',
        nonsense_mediated_decay => 'coding',
        non_stop_decay => 'coding',
        pseudogene => 'coding',
        retrotransposed => 'coding',
        Mt_rRNA => 'rRNA',
        rRNA => 'rRNA',
        Mt_tRNA => 'tRNA',
        tRNA => 'tRNA',
        tRNAscan => 'tRNA',
        snRNA => 'snRNA',
        snoRNA => 'snoRNA',
        miRNA => 'miRNA',
        misc_RNA => 'misc_RNA',
        lincRNA => 'ncRNA',
#        3prime_overlapping_ncrna => 'ncRNA', ## comment out since it causes syntax error, code it in if statement
        bidirectional_promoter_lncrna => 'ncRNA',
        macro_lncRNA => 'ncRNA',
        ribozyme => 'ncRNA',
        sRNA => 'ncRNA',
        non_coding => 'ncRNA',
        ambiguous_orf => 'ncRNA',
        retained_intron => 'ncRNA',
        antisense => 'ncRNA',
        vaultRNA => 'ncRNA',
        sense_intronic => 'misc_RNA',
        sense_overlapping => 'misc_RNA',
        processed_transcript => 'misc_RNA',
        scaRNA => 'misc_RNA',
    );

    if ($transTypes{$transType} ) {
        $returnType = $transTypes{$transType};
    } else {
      if ($transType =~ /pseudogene/ ) {
	$returnType = "coding";
      } elsif ($transType =~ /3prime_overlapping_ncrna/ ) {
	$returnType = "ncRNA";
      } else {
	$returnType = "misc_RNA";
      }
    }
    return $returnType;
}


1;
