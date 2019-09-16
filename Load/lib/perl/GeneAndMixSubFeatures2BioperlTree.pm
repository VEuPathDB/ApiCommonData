package ApiCommonData::Load::GeneAndMixSubFeatures2BioperlTree;


use strict;
use Bio::Location::Simple;
use ApiCommonData::Load::BioperlTreeUtils qw{makeBioperlFeature};
use Data::Dumper;
use Bio::SeqFeature::Tools::Unflattener;
use ApiCommonData::Load::Unflattener;


#input:
#
# gene: required
# mRNA: (optional, not exit when pseudogene)
# CDS:  (exon if pseudogene)
#
#output: standard api tree: gene->transcript->exons


sub preprocess {
    my ($bioperlSeq, $plugin) = @_;
    my ($geneFeature, $source);
    my  $primerPair = '';
    my $unflattener = Bio::SeqFeature::Tools::Unflattener->new;
#    my $unflattener = ApiCommonData::Load::Unflattener->new;

    if(!($bioperlSeq->molecule =~ /rna/i)){
	$unflattener->error_threshold(1);   
	$unflattener->report_problems(\*STDERR);  
	$unflattener->unflatten_seq(-seq=>$bioperlSeq,
                                 -use_magic=>1);
	my @topSeqFeatures = $bioperlSeq->get_SeqFeatures;
	$bioperlSeq->remove_SeqFeatures;

	OUTER: foreach my $bioperlFeatureTree (@topSeqFeatures) {
	    my $type = $bioperlFeatureTree->primary_tag();

            if($type eq 'pseudogene'){
              $bioperlFeatureTree->primary_tag('gene');
              $bioperlFeatureTree->add_tag_value("pseudo","");
              $type = 'gene';
            }

	    if($type eq 'repeat_region' || $type eq 'gap' || $type eq 'assembly_gap' ){
	        if ($type eq 'assembly_gap'){
		  $bioperlFeatureTree->primary_tag("gap");
	        }
		if(!($bioperlFeatureTree->has_tag("gene"))){
		    $bioperlFeatureTree->add_tag_value("gene",$bioperlSeq->accession());
		}
		$bioperlSeq->add_SeqFeature($bioperlFeatureTree);
	    }

	    if($type eq 'STS'){
		if(!($bioperlFeatureTree->has_tag("gene"))){
		    $bioperlFeatureTree->add_tag_value("gene",$bioperlSeq->accession());
		}
		$bioperlSeq->add_SeqFeature($bioperlFeatureTree);
	    }
	    if ($type eq 'gene') {

		$geneFeature = $bioperlFeatureTree; 

                my $gID;
                if(!($geneFeature->has_tag("ID"))){
                  die "Feature $type does not have tag: gene\n";
                } else {
                  ($gID) = $geneFeature->get_tag_values("ID");
		  $geneFeature->remove_tag('ID');
		  $geneFeature->add_tag_value("locus_tag", $gID);
                  print STDERR "processing $gID...\n";
                }

		## for $geneFeature that only have gene feature, but do not have subFeature (such as mRNA and/or exon)
		## and have a note as "nonfunction" and "frameshift", set them as pseudogene,
		## such as gene SLOPH_2171 in ATCN01000028
		if (!$geneFeature->get_SeqFeatures && $geneFeature->has_tag("note") && !$geneFeature->has_tag("pseudo")) {
		  my ($note) = $geneFeature->get_tag_values("note");
		  if ( ($note =~ /nonfunctional/i || $note =~ /non functional/i) &&
		    ($note =~ /frameshift/i || $note =~ /frame shift/i || $note =~ /intron/i ) ) {
		    $geneFeature->add_tag_value("pseudo", "") if (!$geneFeature->has_tag("pseudo") );
		  }

		}

#		print STDERR Dumper $geneFeature;   # this can cause huge log files

		## for pseudogene
		for my $tag ($geneFeature->get_all_tags) {
		    if($tag eq 'pseudo'){
			if ($geneFeature->get_SeqFeatures){
			    next;
			}else{
			    $geneFeature->primary_tag("coding_gene");
			    my $geneLoc = $geneFeature->location();
			    my $transcript = &makeBioperlFeature("mRNA", $geneLoc, $bioperlSeq);
			    $transcript->add_tag_value("gene",($geneFeature->get_tag_values("gene") ) );
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
		    }
		}


		my $gene = &traverseSeqFeatures($geneFeature, $bioperlSeq);
		if($gene){

		    $bioperlSeq->add_SeqFeature($gene);
		}

	    }else{
	      if ($type eq 'source'){
		$source = $bioperlFeatureTree;
		if($source->has_tag('focus')){
		  $source->primary_tag('focus_source');
		}
		if($source->has_tag('PCR_primers')){
		  my $primerpair = '';
		  my (@primerPairs) = $source->get_tag_values('PCR_primers');
		  $primerpair .= join(",",@primerPairs);
		  $source->remove_tag('PCR_primers');
		  $source->add_tag_value('PCR_primers',$primerpair);
		}
		next;
	      }

	      if($type eq 'primer_bind') {

		my ($primerSeq, $primerName);
		if($bioperlFeatureTree->strand() == -1){
		  $primerSeq = 'rev_seq:';
		}else{
		  $primerSeq = 'fwd_seq:';
		}

		if($bioperlFeatureTree->has_tag('note')){
		  ($primerName) = $bioperlFeatureTree->get_tag_values('note');
		  if($primerSeq eq 'rev_seq:'){
		    $primerName = 'rev_name: '.$primerName;

		  }else{
		    $primerName = 'fwd_name: '.$primerName;
		  }

		}


		$bioperlSeq->add_SeqFeature($bioperlFeatureTree);

	      }
	    }

	  }

	if($source){
	  if($source->has_tag('primer_bind')){
	    $source->remove_tag('primer_bind');
	  }else{
	    if($primerPair){
	      my $primerpair = '';
	      if($source->has_tag('PCR_primers')){
	      }else {
		$primerpair .= $primerPair;
		$source->add_tag_value('PCR_primers',$primerpair);
	      }
	    }
	  }
	  $bioperlSeq->add_SeqFeature($source);
	  undef $source;
	}
	undef $primerPair;
      }
  }

sub traverseSeqFeatures {
    my ($geneFeature, $bioperlSeq) = @_;
    
    my $gene;
    my @RNAs = $geneFeature->get_SeqFeatures;


    # This will accept genes of type misc_feature (e.g. cgd4_1050 of GI:46229367)
    # because it will have a geneFeature but not standalone misc_feature 
    # as found in GI:32456060.
    # And will accept transcripts that do not have 'gene' parents (e.g. tRNA
    # in GI:32456060)

    my $transcriptCount = scalar @RNAs;
    my $ctr = 1;

    foreach my $RNA (@RNAs){ 
	my $type = $RNA->primary_tag;
        if (grep {$type eq $_} (
             'mRNA',
             'misc_feature',
             'misc_RNA',
             'rRNA',
             'snRNA',
             'snoRNA',
             'tRNA',
             'ncRNA',
             )
        ) {

	    my $CDSLocation;
	    if($type eq 'ncRNA'){
		if($RNA->has_tag('ncRNA_class')){
                    my $ncRNA_class;
		    ($ncRNA_class) = $RNA->get_tag_values('ncRNA_class');
                    $type = $ncRNA_class if ($ncRNA_class =~ /RNA/i);
		    $RNA->remove_tag('ncRNA_class');

		}
	    }
	    if($type eq 'mRNA' || $type eq 'misc_feature'){
		$type = 'coding';
	    }

	    if (!$gene) { ## only create one gene if there are multiple transcripts
		$gene = &makeBioperlFeature("${type}_gene", $geneFeature->location, $bioperlSeq);
		$gene = &copyQualifiers($geneFeature, $gene);
	    }

	    my $transcriptType = $type;
	    $transcriptType = "mRNA" if ($transcriptType eq "coding");
	    my $transcript = &makeBioperlFeature("$transcriptType", $RNA->location, $bioperlSeq);
	    $transcript = &copyQualifiers($RNA,$transcript);
	    $transcript = &copyQualifiers($geneFeature,$transcript);
	    my ($rnaId) = ($transcript->has_tag('locus_tag')) ? $transcript->get_tag_values('locus_tag') : die "transcript does not have tag gene\n";

	    my @containedSubFeatures = $RNA->get_SeqFeatures;

	    my $CDSLength = 0;
	    foreach my $subFeature (@containedSubFeatures){

		if ($subFeature->primary_tag eq 'CDS'){
		    $transcript = &copyQualifiers($subFeature, $transcript);
		    $CDSLocation  = $subFeature->location;
		}
		if($subFeature->primary_tag eq 'exon'){
		    my $exon = $subFeature;
		    my $codingStart = $exon->location->start;
		    my $codingEnd = $exon->location->end;

		    if(defined $CDSLocation){

			my $codonStart = 0;
			for my $qualifier ($subFeature->get_all_tags()) {
			    if($qualifier eq 'codon_start'){
				foreach my $value ($subFeature->get_tag_values($qualifier)){
				    $codonStart = $value - 1;
				}
			    }
			}

			$codingStart = $CDSLocation->start() if ($codingStart < $CDSLocation->start());
			$codingEnd = $CDSLocation->end() if ($codingEnd > $CDSLocation->end());

			if ($codingStart > $subFeature->location->end() || $codingEnd < $subFeature->location->start()) {
			    $codingStart = ''; # non-coding exon
			    $codingEnd = '';
			    $exon->add_tag_value('type','noncoding_exon');
			}

			if ($exon->location->strand == -1){
			    my $tmp = $codingEnd;
			    $codingEnd = $codingStart;
			    if($tmp == $CDSLocation->end()){
				$codingStart = $tmp - $codonStart;
			    }else{
				$codingStart = $tmp;
			    }
			}else{
			    if($codingStart == $CDSLocation->start()){
				$codingStart += $codonStart;
			    }
			}

			$exon->add_tag_value('CodingStart', $codingStart);
			$exon->add_tag_value('CodingEnd', $codingEnd);
			$CDSLength += (abs($codingEnd - $codingStart) +1) if ($codingStart && $codingEnd);

		    }else{
			$exon->add_tag_value('CodingStart', '');
			$exon->add_tag_value('CodingEnd', '');
		    }
		    $transcript->add_SeqFeature($exon);
		}
	    }

	    $transcript->add_tag_value("CDSLength", $CDSLength);

	    if(!($transcript->get_SeqFeatures())){
		my @exonLocs = $RNA->location->each_Location();
		foreach my $exonLoc (@exonLocs){
		    my $exon = &makeBioperlFeature("exon",$exonLoc,$bioperlSeq);
		    $transcript->add_SeqFeature($exon);
		    if($gene->primary_tag eq 'coding_gene' || $gene->primary_tag eq 'pseudo_gene' ){
		      if ($exonLoc->strand == -1) {
			$exon->add_tag_value('CodingStart', $exonLoc->end());
			$exon->add_tag_value('CodingEnd', $exonLoc->start());
		      } else {
			$exon->add_tag_value('CodingStart', $exonLoc->start());
			$exon->add_tag_value('CodingEnd', $exonLoc->end());
		      }
		    } else {
			$exon->add_tag_value('CodingStart', '');
			$exon->add_tag_value('CodingEnd', '');
		    }
		}
	    }

	    $gene->add_SeqFeature($transcript);
	}
    }


    ## for the case that has gene->exon only, without mRNA, then load them as coding_gene
    ## for pseudogene, use Bio::SeqFeature::Tools::Unflattener to generate pseudoexon
#    my $subFeat = pop @RNAs;
#    if ($subFeat->primary_tag eq "pseudoexon" || $subFeat->primary_tag eq "exon") {
#      if (!$gene) { ## only create one gene if there are multiple transcripts
#	$gene = &makeBioperlFeature("coding_gene", $geneFeature->location, $bioperlSeq);
#	$gene = &copyQualifiers($geneFeature, $gene);
#      }
#      my $transcript = &makeBioperlFeature("mRNA", $geneFeature->location, $bioperlSeq);
#      $transcript->add_tag_value("gene",($geneFeature->get_tag_values("gene") ) );
#      $transcript = &copyQualifiers($geneFeature,$transcript);
#      $transcript->add_tag_value("pseudo", "") if ($subFeat->primary_tag eq "pseudoexon" && !$transcript->has_tag("pseudo"));

#      my ($rnaId) = ($transcript->has_tag('gene')) ? $transcript->get_tag_values('gene') : die "transcript does not have tag gene\n";
#      print STDERR "processed $rnaId within traverseSeqFeatures....\n";

#      foreach my $eachExon ($geneFeature->get_SeqFeatures){
#	my $exonLoc = $eachExon->location();
#	my $exon = &makeBioperlFeature("exon",$exonLoc,$bioperlSeq);
#	if ($exonLoc->strand == -1){
#	  $exon->add_tag_value('CodingStart', $exonLoc->end());
#	  $exon->add_tag_value('CodingEnd', $exonLoc->start());
#	} else {
#	  $exon->add_tag_value('CodingStart', $exonLoc->start());
#	  $exon->add_tag_value('CodingEnd', $exonLoc->end());
#	}
#	$transcript->add_SeqFeature($exon);
#      }
#      $gene->add_SeqFeature($transcript);
#    }


    return $gene;
}


sub copyQualifiers {
  my ($geneFeature, $bioperlFeatureTree) = @_;

  for my $qualifier ($geneFeature->get_all_tags()) {

    if ($bioperlFeatureTree->has_tag($qualifier)) {
      # remove tag and recreate with merged non-redundant values
      my %seen;
      my @uniqVals = grep {!$seen{$_}++} 
                       $bioperlFeatureTree->remove_tag($qualifier), 
                       $geneFeature->get_tag_values($qualifier);

      $bioperlFeatureTree->add_tag_value(
                             $qualifier, 
                             @uniqVals
                           );
    } else {
      $bioperlFeatureTree->add_tag_value(
                             $qualifier,
                             $geneFeature->get_tag_values($qualifier)
                           );
    }
  }
  return $bioperlFeatureTree;
}

1;
