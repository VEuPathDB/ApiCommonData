package ApiCommonData::Load::GeneAndCdsWithAltSpl2BioperlTree;
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
use ApiCommonData::Load::Unflattener;


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
    my $unflattener = ApiCommonData::Load::Unflattener->new;

    if(!($bioperlSeq->molecule =~ /rna/i)){
	$unflattener->error_threshold(1);   
	$unflattener->report_problems(\*STDERR);  
	$unflattener->unflatten_seq(-seq=>$bioperlSeq,
                                 -use_magic=>1);
	my @topSeqFeatures = $bioperlSeq->get_SeqFeatures;
	$bioperlSeq->remove_SeqFeatures;

	foreach my $bioperlFeatureTree (@topSeqFeatures) {
	    my $type = $bioperlFeatureTree->primary_tag();

	    if($type eq 'repeat_region' || $type eq 'gap' || $type eq 'assembly_gap' ){
		#if($bioperlFeatureTree->has_tag("satellite")){
		#    $bioperlFeatureTree->primary_tag("microsatellite");
		#}
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
		$bioperlSeq->add_SeqFeature($bioperlFeatureTree);
	    }
	    if ($type eq 'gene') {

		$geneFeature = $bioperlFeatureTree; 
		
		## for $geneFeature that only have gene feature, but do not have subFeature, such as mRNA and exon, 
		## and have a note as "nonfunction" and "frameshift", set them as pseudogene,
		## such as gene SLOPH_2171 in ATCN01000028
		if (!$geneFeature->get_SeqFeatures && $geneFeature->has_tag("note") && !$geneFeature->has_tag("pseudo")) {
		  my ($note) = $geneFeature->get_tag_values("note");
		  if ( ($note =~ /nonfunctional/i || $note =~ /non functional/i) &&
		    ($note =~ /frameshift/i || $note =~ /frame shift/i || $note =~ /intron/i ) ) {
		    $geneFeature->add_tag_value("pseudo", "") if (!$geneFeature->has_tag("pseudo") );
		  }
		  ## print for reference
		  #foreach my $tag ($geneFeature->get_all_tags) {
		  #  my ($evalue) = $geneFeature->get_tag_values($tag);
		  #  print STDERR "$evalue\n";
		  #}
		}

#		print STDERR Dumper $geneFeature;   # this can cause huge log files
		if(!($geneFeature->has_tag("locus_tag"))){
		    $geneFeature->add_tag_value("locus_tag",$bioperlSeq->accession());
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
		#my $gene = &traverseSeqFeatures($geneFeature, $bioperlSeq);
		my $geneArrayRef = &traverseSeqFeatures($geneFeature, $bioperlSeq);
        my @genes = @{$geneArrayRef};
      
		#if($gene){
		foreach my $gene (@genes){

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
		    # my ($primerpair) .= $source->get_tag_values('PCR_primers');
		    # $primerpair .= ',';
		    # $source->remove_tag('PCR_primers');	      
		}
		else{
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
    
    #my $gene;
    my (@genes, $gene);
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
	    if($type eq 'mRNA'){
		$type = 'coding';
	    }
	    #$gene = &makeBioperlFeature("${type}_gene", $geneFeature->location, $bioperlSeq);
	    $gene = &makeBioperlFeature("${type}_gene", $RNA->location, $bioperlSeq);  ## for gene use transcript location instead of gene location


        my ($geneId) = $geneFeature->get_tag_values('locus_tag');
        $gene->add_tag_value('locus_tag', $geneId);

        if ($transcriptCount > 1) {
          my ($rnaId) = $RNA->get_tag_values('locus_tag');
          if ($rnaId eq $geneId) {
            $geneId = $geneId."\_$ctr";
          } else {
            $geneId = $rnaId;
          }
          $gene->remove_tag('locus_tag');
          $gene->add_tag_value('locus_tag', $geneId);

          $ctr++;
        }

	    $gene = &copyQualifiers($geneFeature, $gene);
            $gene = &copyQualifiers($RNA,$gene);
	    my $transcript = &makeBioperlFeature("transcript", $RNA->location, $bioperlSeq);
	    $transcript = &copyQualifiers($RNA,$transcript);

	    my @containedSubFeatures = $RNA->get_SeqFeatures;
		
			my $CDSLength = 0;
	    foreach my $subFeature (@containedSubFeatures){
		if ($subFeature->primary_tag eq 'CDS'){
		    $gene = &copyQualifiers($subFeature, $gene);
		    $CDSLocation  = $subFeature->location;
		}
		if($subFeature->primary_tag eq 'exon'){
		    my $exon = $subFeature;
		    my $codingStart = $exon->location->start;
		    my $codingEnd = $exon->location->end;

		    if(defined $CDSLocation){
			my $codonStart = 0;

			for my $qualifier ($gene->get_all_tags()) {
			    if($qualifier eq 'codon_start'){
				foreach my $value ($gene->get_tag_values($qualifier)){
				    $codonStart = $value - 1;
				}
			    }
			    if($qualifier eq 'selenocysteine'){
	 		       $gene->remove_tag('selenocysteine');
			       $gene->add_tag_value('selenocysteine','selenocysteine');
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

			$exon->add_tag_value('CodingStart', $codingStart) if (!$exon->has_tag('CodingStart'));
			$exon->add_tag_value('CodingEnd', $codingEnd) if (!$exon->has_tag('CodingEnd'));
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
		    if($gene->primary_tag ne 'coding_gene' && $gene->primary_tag ne 'pseudo_gene' ){
			$exon->add_tag_value('CodingStart', '');
			$exon->add_tag_value('CodingEnd', '');	
		    }

		}
	    }
	    $gene->add_SeqFeature($transcript);
        push (@genes, $gene);

	}
    }
    #return $gene;
    return (\@genes);
}


sub copyQualifiers {
  my ($geneFeature, $bioperlFeatureTree) = @_;
  
  for my $qualifier ($geneFeature->get_all_tags()) {

    if ($bioperlFeatureTree->has_tag($qualifier) && $qualifier ne "locus_tag") {
      # remove tag and recreate with merged non-redundant values
      my %seen;
      my @uniqVals = grep {!$seen{$_}++} 
                       $bioperlFeatureTree->remove_tag($qualifier), 
                       $geneFeature->get_tag_values($qualifier);
                       
      $bioperlFeatureTree->add_tag_value(
                             $qualifier, 
                             @uniqVals
                           );    
    } elsif ($qualifier ne "locus_tag") {
      $bioperlFeatureTree->add_tag_value(
                             $qualifier,
                             $geneFeature->get_tag_values($qualifier)
                           );
    }
     
  }
  return $bioperlFeatureTree;
}

1;
