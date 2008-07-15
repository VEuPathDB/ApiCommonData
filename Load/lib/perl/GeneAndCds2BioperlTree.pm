package ApiCommonData::Load::GeneAndCds2BioperlTree;

# Remove existing gene features, promote CDS, tRNA, etc to gene

use strict;
use Bio::Location::Simple;
use ApiCommonData::Load::BioperlTreeUtils qw{makeBioperlFeature};
use Data::Dumper;
use Bio::SeqFeature::Tools::Unflattener;


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


sub preprocess {
    my ($bioperlSeq, $plugin) = @_;
    my ($geneFeature);
    my $unflattener = Bio::SeqFeature::Tools::Unflattener->new;
    $unflattener->unflatten_seq(-seq=>$bioperlSeq,
                                 -use_magic=>1);
    my @topSeqFeatures = $bioperlSeq->get_SeqFeatures;
    $bioperlSeq->remove_SeqFeatures;

    foreach my $bioperlFeatureTree (@topSeqFeatures) {
	my $type = $bioperlFeatureTree->primary_tag();
    


       
	if ($type eq 'gene') {

	    $geneFeature = $bioperlFeatureTree;       
	    for my $tag ($geneFeature->get_all_tags) {    
		if($tag eq 'pseudo'){
		    if ($geneFeature->get_SeqFeatures){
			next;
		    }else{
			$geneFeature->primary_tag('pseudo_gene');
			$geneFeature->add_tag_value('is_pseudo',1);
			$bioperlSeq->add_SeqFeature($geneFeature);
		    }
		 
		}
	    }       
	    my $gene = &traverseSeqFeatures($geneFeature, $bioperlSeq);
	    if($gene){
		$bioperlSeq->add_SeqFeature($gene);
	    }


	    
	}else{
	    $bioperlSeq->add_SeqFeature($bioperlFeatureTree);


	}
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
    foreach my $RNA (@RNAs){ 
	my $type = $RNA->primary_tag;
        if (grep {$type eq $_} (
             'mRNA',
             'misc_RNA',
             'rRNA',
             'snRNA',
             'snoRNA',
             'tRNA',
             )
        ) {

	    my $CDSLocation;
	    if($type eq 'mRNA'){
		$type = 'coding';
	    }
	    $gene = &makeBioperlFeature("${type}_gene", $geneFeature->location, $bioperlSeq);
	    $gene = &copyQualifiers($geneFeature, $gene);
	    my $transcript = &makeBioperlFeature("transcript", $RNA->location, $bioperlSeq);

	    my @containedSubFeatures = $RNA->get_SeqFeatures;

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
			$codingStart = $CDSLocation->start() if ($codingStart < $CDSLocation->start());
			$codingEnd = $CDSLocation->end() if ($codingEnd > $CDSLocation->end());
			if ($codingStart > $subFeature->location->end() || $codingEnd < $subFeature->location->start()) {
			    $codingStart = ''; # non-coding exon
			    $codingEnd = '';
			    $exon->add_tag_value('type','noncoding_exon');
			}

			$exon->add_tag_value('coding_start', $codingStart);
			$exon->add_tag_value('coding_end', $codingEnd);
		    }else{
			$exon->add_tag_value('coding_start', '');
			$exon->add_tag_value('coding_end', '');
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
