package ApiCommonData::Load::GeneAndCdsWithRNAswoParent2BioperlTree;

use strict;
use Bio::Location::Simple;
use ApiCommonData::Load::BioperlTreeUtils qw{makeBioperlFeature};
use Data::Dumper;
use Bio::SeqFeature::Tools::Unflattener;
use ApiCommonData::Load::Unflattener;


#input:
#
# gene
# CDS
# tRNA/rRNA without parent gene
#
#output: standard api tree: gene->transcript->exons


sub preprocess {
    my ($bioperlSeq, $plugin) = @_;
    my ($geneFeature, $source);
    my  $primerPair = '';
#    my $unflattener = Bio::SeqFeature::Tools::Unflattener->new;
    my $unflattener = ApiCommonData::Load::Unflattener->new;

    if(!($bioperlSeq->molecule =~ /rna/i)){
	$unflattener->error_threshold(1);
	$unflattener->report_problems(\*STDERR);
	$unflattener->unflatten_seq(-seq=>$bioperlSeq,
                                 -use_magic=>1);
	my @topSeqFeatures = $bioperlSeq->get_SeqFeatures;
	$bioperlSeq->remove_SeqFeatures;

	OUTER: foreach my $bioperlFeatureTree (@topSeqFeatures) {
	    my $type = $bioperlFeatureTree->primary_tag();

	    if($type eq 'repeat_region' || $type eq 'gap' || $type eq 'assembly_gap'){
	      if ($type eq 'assembly_gap'){
		$bioperlFeatureTree->primary_tag("gap");
	      }
	      if(!($bioperlFeatureTree->has_tag("locus_tag"))){
		$bioperlFeatureTree->add_tag_value("locus_tag",$bioperlSeq->accession());
	      }
	      $bioperlSeq->add_SeqFeature($bioperlFeatureTree);
	    }

	    if($type eq 'STS'){
	      if(!($bioperlFeatureTree->has_tag("locus_tag"))){
		$bioperlFeatureTree->add_tag_value("locus_tag",$bioperlSeq->accession());
	      }
	    }

	    if ($type eq 'gene' ) {
	      $geneFeature = $bioperlFeatureTree; 

	      if(!($geneFeature->has_tag("locus_tag"))){
		$geneFeature->add_tag_value("locus_tag",$bioperlSeq->accession());
	      }

	      if (($geneFeature->has_tag("locus_tag"))){
		my ($cID) = $geneFeature->get_tag_values("locus_tag");
		print STDERR "processing $cID...\n";
	      }

	      for my $tag ($geneFeature->get_all_tags) {

		if($tag eq 'pseudo'){
		  if ($geneFeature->get_SeqFeatures){
		    next;
		  }else{
		    $geneFeature->primary_tag("coding_gene");
		    my $geneLoc = $geneFeature->location();
		    my $transcript = &makeBioperlFeature("mRNA", $geneLoc, $bioperlSeq);
		    $transcript->add_tag_value("locus_tag",($geneFeature->get_tag_values("locus_tag") ) );
		    $transcript = &copyQualifiers($geneFeature,$transcript);

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

	      $bioperlSeq->add_SeqFeature($gene) if ($gene);

	      ## deal with tRNA that does not have 'gene' parents (e.g. tRNA in GI:32456060)
	    } elsif ($type eq 'tRNA' || $type eq 'rRNA') {
	      $geneFeature = $bioperlFeatureTree;

	      if(!($geneFeature->has_tag("locus_tag"))){
		$geneFeature->add_tag_value("locus_tag",$bioperlSeq->accession());
	      }

	      if (($geneFeature->has_tag("locus_tag"))){
		my ($cID) = $geneFeature->get_tag_values("locus_tag");
		print STDERR "processing $cID...\n";
	      }

	      my $geneLoc = $geneFeature->location();

	      my $gene = &makeBioperlFeature("${type}_gene", $geneLoc, $bioperlSeq);
	      $gene = &copyQualifiers($geneFeature, $gene);

	      my $transcript = &makeBioperlFeature("$type", $geneLoc, $bioperlSeq);

	      my @exonLocs = $geneLoc->each_Location();
	      foreach my $exonLoc (@exonLocs){
		my $exon = &makeBioperlFeature("exon",$exonLoc,$bioperlSeq);
		$exon->add_tag_value('CodingStart', '');
		$exon->add_tag_value('CodingEnd', '');
		$transcript->add_SeqFeature($exon);
	      }
	      $gene->add_SeqFeature($transcript);
	      $bioperlSeq->add_SeqFeature($gene);
	      ## end for type eq tRNA

	    } else {
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
	      }else{
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

  my $transcriptCount = scalar @RNAs;
  my $ctr = 1;

  foreach my $RNA (@RNAs){ 
    my $type = $RNA->primary_tag;
    if (grep {$type eq $_} (
             'mRNA',
             'misc_RNA',
             'rRNA',
             'snRNA',
             'snoRNA',
             'tRNA',
             'tmRNA',
             'scRNA',
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

      $type = 'coding' if ($type eq 'mRNA');

      if (!$gene) { ## only create one gene if there are multiple transcripts
	$gene = &makeBioperlFeature("${type}_gene", $geneFeature->location, $bioperlSeq);
	$gene = &copyQualifiers($geneFeature, $gene);
      }

      my $transType = $type;
      $transType = "mRNA" if ($transType eq "coding");
      my $transcript = &makeBioperlFeature("$transType", $RNA->location, $bioperlSeq);

      $transcript = &copyQualifiers($RNA,$transcript);
      $transcript = &copyQualifiers($geneFeature,$transcript);
      my ($rnaId) = ($transcript->has_tag('locus_tag')) ? $transcript->get_tag_values('locus_tag') : die "transcript does not have tag locus_tag\n";

      if ($transcriptCount > 1) {
	$rnaId .= "\.$ctr";
	$ctr++;
	$transcript->remove_tag('locus_tag');
	$transcript->add_tag_value('locus_tag',$rnaId);
      }

      my @containedSubFeatures = $RNA->get_SeqFeatures;

      my $CDSLength = 0;
      foreach my $subFeature (@containedSubFeatures){
	if ($subFeature->primary_tag eq 'intron'){
	  next;
	}
	if ($subFeature->primary_tag eq 'CDS'){
	  $transcript = &copyQualifiers($subFeature, $transcript);
	  $CDSLocation  = $subFeature->location;
	}
	if($subFeature->primary_tag eq 'exon'){
	  my $exon;
	  if ($subFeature->has_tag("CodingStart") && $subFeature->has_tag("CodingEnd") ) {
	    ## create a new exon if an exon has already been assigned by previous transcript
	    $exon = &makeBioperlFeature("exon", $subFeature->location, $bioperlSeq);
	    my ($eId) = $subFeature->get_tag_values('locus_tag') if ($subFeature->has_tag('locus_tag'));
	    $exon->add_tag_value('locus_tag', $eId);
	  }else {
	    $exon = $subFeature;
	  }

	  my $codingStart = $exon->location->start;
	  my $codingEnd = $exon->location->end;

	  if(defined $CDSLocation){
	    my $codonStart = 0;

	    for my $qualifier ($transcript->get_all_tags()) {  ## using transcript since codon_start is not in exon anymore
	      if($qualifier eq 'codon_start'){
		#foreach my $value ($subFeature->get_tag_values($qualifier)){
		foreach my $value ($transcript->get_tag_values($qualifier)){  ## using transcript instead of subFeature here
		  $codonStart = $value - 1;
		}
	      }
	      if($qualifier eq 'selenocysteine'){
		$transcript->remove_tag('selenocysteine');
		$transcript->add_tag_value('selenocysteine','selenocysteine');
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
	  $transcript->add_SeqFeature($exon);
	}
      }

      $gene->add_SeqFeature($transcript);
    }
  }
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
