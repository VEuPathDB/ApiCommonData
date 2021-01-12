package ApiCommonData::Load::genemRNACDSPeptideWGeneOnly2BioperlTree;

use strict;
use Bio::Location::Simple;
use ApiCommonData::Load::BioperlTreeUtils qw{makeBioperlFeature};
use Data::Dumper;
use Bio::SeqFeature::Tools::Unflattener;
use Data::Dumper;

## This is specially for annotation that some genes only have gene feature only,
## in addition to the standard gene model as below, eg. tbruLister427_2018 at 2018-12-17

#input:
#
# gene
# mRNA
# CDS
# polypeptide (optional)
#

#output: standard api tree: gene->transcript->exons
#
# (0) remove all seq features, add back the non-genes
# (1) copy old gene qualifiers to cds/rna feature
# (2) retype CDS into Gene
# (3) remember its join locations
# (4) create transcript
# (5) add to gene
# (6) create exons from sublocations
# (7) add to transcript

## this reshaper copied from genemRNAExonCDS2BioperlTree.pm
## comment out if($subFeature->primary_tag eq 'exon') roop
## add polypeptide info, do not need for CDSLocation, but do need if there are product info in polypeptide

sub preprocess {
    my ($bioperlSeq, $plugin) = @_;

    my ($geneFeature, $source);

    my @topSeqFeatures = $bioperlSeq->remove_SeqFeatures;

    ## check if gene, rna, exon or CDS are on the same strand
    &checkGeneStructure (\@topSeqFeatures);

    my %polypeptide;

    foreach my $bioperlFeatureTree (@topSeqFeatures) {
      my $type = $bioperlFeatureTree->primary_tag();

      if ($type eq 'polypeptide') {
	my $id;
	my ($sourceId) = $bioperlFeatureTree->get_tag_values("ID") if $bioperlFeatureTree->has_tag("ID");

	## check if polypeptide has parent
	if ($bioperlFeatureTree->has_tag("Derives_from")){
	  ($id) = $bioperlFeatureTree->get_tag_values("Derives_from");
	}else{
	  print STDERR "Error: $sourceId polypeptide feature has no associated parent\n";
	}

	## check if multiple polypeptides for each mRNA 
	if ($polypeptide{$id}){
	  print STDERR "Error: Multiple polypeptides for $id\n";
	}

	$polypeptide{$id} = $bioperlFeatureTree if($id);
      }
    }

    OUTER: foreach my $bioperlFeatureTree (@topSeqFeatures) {
	    my $type = $bioperlFeatureTree->primary_tag();
	    # print STDERR "Feature type is: $type\n";

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

	    ## for tRNA, rRNA, snRNA and snoRNA that do not have gene as parent
	    if($type eq 'tRNA' || $type eq 'rRNA' || $type eq 'snRNA' || $type eq 'snoRNA') {
	      $geneFeature = $bioperlFeatureTree;

	      my $geneLoc = $geneFeature->location();
	      my $gene = &makeBioperlFeature("${type}_gene", $geneLoc, $bioperlSeq);
	      my($geneID) = $geneFeature->get_tag_values('ID');
	      $gene->add_tag_value("ID",$geneID);
	      $gene = &copyQualifiers($geneFeature, $gene);

              my $transcript = &makeBioperlFeature("transcript", $geneLoc, $bioperlSeq);
	      my $transcriptID = $geneID.".$type";
	      $transcript->add_tag_value("ID", $transcriptID);

	      my @exonLocs = $geneLoc->each_Location();
	      foreach my $exonLoc (@exonLocs){
		my $exon = &makeBioperlFeature("exon",$exonLoc,$bioperlSeq);
		$exon->add_tag_value('CodingStart', '');
		$exon->add_tag_value('CodingEnd', '');
		$transcript->add_SeqFeature($exon);
	      }
	      $gene->add_SeqFeature($transcript);
	      $bioperlSeq->add_SeqFeature($gene); 
	    }  ## end of $type eq tRNA or rRNA

	    if ($type eq 'gene') {

		$geneFeature = $bioperlFeatureTree; 
		if(!($geneFeature->has_tag("ID"))){
		    $geneFeature->add_tag_value("ID",$bioperlSeq->accession());
		}

		if (($geneFeature->has_tag("ID"))){
			my ($cID) = $geneFeature->get_tag_values("ID");
			print STDERR "processing $cID...\n";
		}

		if($geneFeature->has_tag("Note")){
		    my($note) = $geneFeature->get_tag_values("Note");

		    if($note =~ /pseudogene/i){
			$geneFeature->add_tag_value("pseudo","");
		    }
		}

		## this is only OK for tbruLister427_2018 that have gene and standard gene model mixed
		if (!$geneFeature->get_SeqFeatures){
		  my ($cID) = $geneFeature->get_tag_values("ID") if ($geneFeature->has_tag("ID"));
		  print "  generate subFeature for $cID\n";

		  $geneFeature->primary_tag("coding_gene");
		  my $geneLoc = $geneFeature->location();
		  my $transcript = &makeBioperlFeature("mRNA", $geneLoc, $bioperlSeq);
		  $transcript->add_tag_value("pseudo","");   ## add a pseudo tag to the generated gene model

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
		  next OUTER;
		}

		my ($geneArrayRef, $UTRArrayRef, $polypeptideRef) = &traverseSeqFeatures($geneFeature, $bioperlSeq, \%polypeptide);

		my @genes = @{$geneArrayRef};
		my @UTRs = @{$UTRArrayRef};
		%polypeptide = %{$polypeptideRef};

		foreach my $gene (@genes) {
		    $bioperlSeq->add_SeqFeature($gene);
		}

		foreach my $UTR (@UTRs){
		    $bioperlSeq->add_SeqFeature($UTR);
		}

	    }else{
		if($type eq 'gap' || $type eq 'direct_repeat' || $type eq 'three_prime_utr'
		   || $type eq 'transposable_element'
		   || $type eq 'five_prime_utr' || $type eq 'splice_acceptor_site'){
		    $bioperlSeq->add_SeqFeature($bioperlFeatureTree);
		}
	    }

	}

    ## check if polypeptide has parent 
    foreach my $rnaId (keys %polypeptide){
      if(!($polypeptide{$rnaId}->{flag})){
	print STDERR "Error: No genes/mRNAs for this polypeptide : $rnaId\n";
      }
    }
}

sub traverseSeqFeatures {
    my ($geneFeature, $bioperlSeq, $polypeptideHashRef) = @_;
    my (@genes, $gene, @UTRs);

    my %polypeptide = %{$polypeptideHashRef};
    my @RNAs = $geneFeature->get_SeqFeatures;

    my $transcriptCount = scalar @RNAs;
    my $ctr = 1;

    # This will accept genes of type misc_feature (e.g. cgd4_1050 of GI:46229367)
    # because it will have a geneFeature but not standalone misc_feature 
    # as found in GI:32456060.
    # And will accept transcripts that do not have 'gene' parents (e.g. tRNA
    # in GI:32456060)
    foreach my $RNA ( sort {$a->location->start <=> $b->location->start 
			      || $a->location->end <=> $b->location->end} @RNAs){
	my $type = $RNA->primary_tag;
        if (grep {$type eq $_} (
             'mRNA',
             'misc_RNA',
             'rRNA',
             'snRNA',
             'snoRNA',
             'tRNA',
             'ncRNA',
             'miRNA',
	     'pseudogenic_transcript',
             'scRNA',
             'srpRNA',
             'SRP.RNA',
             )
        ) {


        if ($type eq 'srpRNA' || $type eq 'SRP.RNA') {
          $type = "SRP_RNA";
        }

        if($type eq 'mRNA' || $type eq 'pseudogenic_transcript'){
            $type = 'coding';
	    my ($rnaId) = $RNA->get_tag_values('ID');
	    if ($polypeptide{$rnaId}){
	      $RNA = &copyQualifiers($polypeptide{$rnaId},$RNA);
	      $polypeptide{$rnaId}->{flag} =1;
	    }else {
	      print STDERR "Missing polypeptide for : $rnaId\n";
	    }

	    if ($type eq 'pseudogenic_transcript') {
	      $RNA->add_tag_value("pseudo","");
	    }
        }

	my($geneID) = $geneFeature->get_tag_values('ID');
	if (!$gene) {    ## only create one gene for multiple transcript
	  $gene = &makeBioperlFeature("${type}_gene", $geneFeature->location, $bioperlSeq) if (!$gene);
	  $gene->add_tag_value("ID",$geneID);
	  $gene = &copyQualifiers($geneFeature, $gene);
	}

#	my $transcript = &makeBioperlFeature("transcript", $RNA->location, $bioperlSeq);
	my $transType = $type;
	$transType = "mRNA" if ($transType eq "coding");
	my $transcript = &makeBioperlFeature("$transType", $RNA->location, $bioperlSeq);

	my ($rnaID) = ($RNA->has_tag('ID')) ? $RNA->get_tag_values('ID') : die "ERROR: missing RNA id for gene: $geneID\n";

	$transcript->add_tag_value("ID", $rnaID);
	$transcript = &copyQualifiers($RNA, $transcript);

	## add is_pseudo and is_partial to transcript
	if ($gene->has_tag('Pseudo') || $gene->has_tag('pseudo')) {
	  $transcript->add_tag_value('pseudo', '') if (!$transcript->has_tag('Pseudo') && !$transcript->has_tag('pseudo'));
	}

	if ($gene->has_tag('Partial') || $gene->has_tag('partial')) {
	  $transcript->add_tag_value('partial', '') if (!$transcript->has_tag('Partial') && !$transcript->has_tag('partial'));
	}


	my @containedSubFeatures = $RNA->get_SeqFeatures;

	my $codonStart = 0;

	    if($gene->has_tag('selenocysteine')){
		$gene->remove_tag('selenocysteine');
		$gene->add_tag_value('selenocysteine','selenocysteine');
	    }

	    my (@exons, @codingStartAndEndPairs);

	    my $CDSctr =0;
	    my $prevPhase =0;


	    my $CDSLocation;
	    foreach my $subFeature (sort {$a->location->start <=> $b->location->start} @containedSubFeatures){

#	      $codonStart = $subFeature->frame();
#		if($subFeature->primary_tag eq 'exon'){
#		    my $exon = &makeBioperlFeature($subFeature->primary_tag,$subFeature->location,$bioperlSeq);
#		    push(@exons,$exon);
#		}

		if($subFeature->primary_tag eq 'CDS' || $subFeature->primary_tag eq 'pseudogenic_exon'){
		  my $exon = &makeBioperlFeature("exon",$subFeature->location,$bioperlSeq);
		  $exon = &copyQualifiers($subFeature, $exon);
		  $exon->add_tag_value('exonType', "coding");
		  push (@exons, $exon);

		  $CDSLocation = $subFeature->location;
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

		if (lc($subFeature->primary_tag) eq 'five_prime_utr' || lc($subFeature->primary_tag) eq 'three_prime_utr' 
		    || lc($subFeature->primary_tag) eq 'splice_acceptor_site'){
		    my $UTR = &makeBioperlFeature(lc($subFeature->primary_tag),$subFeature->location,$bioperlSeq);
		    $UTR = &copyQualifiers($subFeature,$UTR);
		    push(@UTRs,$UTR);
		}
	    }

	    ## deal with codonStart, use the frame of the 1st CDS
	    foreach my $j (0..$#codingStartAndEndPairs) {
	      my ($Start, $End, $strand, $frame) = split(/\t/, $codingStartAndEndPairs[$j]);

	      if ($j == 0 && $strand == 1 && $frame > 0) {
		$Start += $frame;
		$codingStartAndEndPairs[$j] = "$Start\t$End\t$strand\t$frame";
	      } elsif ($j == $#codingStartAndEndPairs && $strand == -1 && $frame > 0) {
		$Start -= $frame;
		$codingStartAndEndPairs[$j] = "$Start\t$End\t$strand\t$frame";
	      }

	    }

	    my ($codingStart, $codingEnd) = split(/\t/, shift(@codingStartAndEndPairs) );

	    foreach my $exon (@exons){

		if($codingStart <= $exon->location->end && $codingStart >= $exon->location->start){
		    $exon->add_tag_value('CodingStart',$codingStart);
		    $exon->add_tag_value('CodingEnd',$codingEnd);

		    ($codingStart, $codingEnd) = split(/\t/, shift(@codingStartAndEndPairs) );

		} elsif (($codingStart <= $exon->location->start && $codingEnd <= $exon->location->start) 
			 || ($codingStart >= $exon->location->end && $codingEnd >= $exon->location->end) ) {
		  $exon->add_tag_value('CodingStart',"");
		  $exon->add_tag_value('CodingEnd',"");
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
		    if($gene->primary_tag ne 'coding_gene' && $gene->primary_tag ne 'pseudo_gene' ){
			$exon->add_tag_value('CodingStart', '');
			$exon->add_tag_value('CodingEnd', '');	
		    }else {
		      my ($cdsCodingStart, $cdsCodingEnd);
		      if ($RNA->location->strand == -1) {
			$cdsCodingStart = $exonLoc->end;
			$cdsCodingEnd = $exonLoc->start;
		      } else {
			$cdsCodingStart = $exonLoc->start;
			$cdsCodingStart = $exonLoc->end;
		      }
		      $exon->add_tag_value('CodingStart', $cdsCodingStart);
		      $exon->add_tag_value('CodingEnd', $cdsCodingEnd);
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
    return (\@genes, \@UTRs, \%polypeptide);
}

## check if gene, rna, exon or CDS are on the same strand
sub checkGeneStructure {
  my $geneFeature = shift;
  foreach my $gene (@{$geneFeature} ) {
    my $type = $gene->primary_tag();
    if ($type eq 'gene' || $type eq 'pseudogene') {
      my @RNAs = $gene->get_SeqFeatures;
      foreach my $RNA (sort {$a->location->start <=> $b->location->start
			       || $a->location->end <=> $b->location->end} @RNAs){
	my ($rID) = $RNA->get_tag_values('ID');
	die "gene and rna are not on the same strand: $rID \n" if ($gene->location->strand != $RNA->location->strand);
	my @exons= $RNA->get_SeqFeatures;
	foreach my $exon(sort {$a->location->start <=> $b->location->start} @exons){
	  if ( ($gene->location->strand != $exon->location->strand)
	       || ($RNA->location->strand != $exon->location->strand ) ) {
	    die "gene, rna, and exon are not on the same strand: $rID\n";
	  }
	}
      }
    }
  }
  return 1;
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
