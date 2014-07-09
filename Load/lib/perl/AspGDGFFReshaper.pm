package ApiCommonData::Load::AspGDGFFReshaper;
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
use Bio::SeqFeature::Tools::Unflattener;
use ApiCommonData::Load::BioperlTreeUtils qw{makeBioperlFeature};
use Data::Dumper;


# Input:
# ORF -> gene
#    CDS -> exon
# pseudogene > CDS
# ncRNA > noncoding_exon
# Output: standard api tree: gene->transcript->exons

# 1. Remove all sequence features.
# 2. Create transcripts.
# 3. Create exons.
# 4. Copy attributes from Gene to Transcripts
# 5. Restore non-gene features

sub preprocess {
    my ($bp_seq_obj, $plugin) = @_;
    
    # my $unflattener = Bio::SeqFeature::Tools::Unflattener->new;    
    # $unflattener->unflatten_seq(-seq=>$bp_seq_obj,-use_magic=>1);
    
    # Remove all of the features on this Bio::Seq for now.
    my @seq_features = $bp_seq_obj->remove_SeqFeatures;
    foreach my $feature (@seq_features) {
	
	# Get the primary_tag, in this case the GFF3 'type'
	my $type = $feature->primary_tag();
	
	# Bunch of things to flat out ignore
	if ($type eq 'blocked_reading_frame'
	    || $type eq 'centromere'
	    || $type eq 'intron'
#	    || $type eq 'snRNA'
#	    || $type eq 'rRNA'
	    || $type eq 'ncRNA'
	    || $type eq 'tRNA'
	    ) {
	    next;
	}
	
	# Mongrify long_terminal_repeats
	if ($type eq 'long_terminal_repeat') {
	    $type = 'repeat_region';
	    $feature->primary_tag('repeat_region');
	}

	if ($type eq 'repeat_region') {

	    if ($feature->has_tag('satellite')) {
		$feature->primary_tag('microsatellite');
	    }
	    
	    if (!($feature->has_tag("ID"))) {
		$feature->add_tag_value('ID',$bp_seq_obj->accession());
	    }
	    
	    $bp_seq_obj->add_SeqFeature($feature);
	}
	
	
#    # Retain CDS entries. We need them for GBrowse
#    if ($type eq 'CDS') {
#	print STDERR "---> Dumping CDS feature\n";
#	$bp_seq_obj->add_SeqFeature($feature);
#	next;
#    }
	
	# Promote various small RNAs to genes and process coding genes
	if ($type eq 'snoRNA'
	    || $type eq 'snRNA'
	    || $type eq 'rRNA'
	    || $type eq 'ncRNA'
	    || $type eq 'tRNA'
	    || $type eq 'gene'
	    || $type eq 'pseudogene'
	    || $type eq 'ORF'
	    ) {
	    
	    # SGD genes already have IDs so this isn't really necessary.
	    uniquify_and_add_id($feature,$bp_seq_obj);	

		if ($feature->has_tag("ID")){
			my ($cID) = $feature->get_tag_values("ID");
			print STDERR "processing $cID...\n";
		}
	    
#	my ($gene,$utrs) = gene2centraldogma($feature, $bp_seq_obj);
	    my $gene = gene2centraldogma($feature, $bp_seq_obj);
	    $bp_seq_obj->add_SeqFeature($gene) if $gene;
	    
#	foreach my $utr (@$utrs){
#	    #    print STDERR Dumper $utr;
#	    $bp_seq_obj->add_SeqFeature($utr);
#	}
	    
	    
	    # Restore a bunch of features that do not require processing.
	} elsif ($type eq 'gap'
		 || $type eq 'direct_repeat'
		 || $type eq 'three_prime_utr'
		 || $type eq 'five_prime_utr'
		 || $type eq 'splice_acceptor_site') {
	    $bp_seq_obj->add_SeqFeature($feature);
	} else { }
    }
}


sub uniquify_and_add_id {
    my ($feature,$bp_seq_obj) = @_;
    unless ($feature->has_tag('ID')) {
	$feature->add_tag_value('ID',$bp_seq_obj->accession());
    }
}



sub traverseSeqFeatures {
    my ($gene_feature, $bp_seq_obj) = @_;
    
    my @utrs;
    
    # Create a new bioperl object. We may have already done this if there are multiple transcript subfeatures
    my $gene = makeBioperlFeature("coding_gene", $gene_feature->location, $bp_seq_obj);
    
    # Copy the name of the feature to our new gene object
    my ($geneID) = $gene_feature->get_tag_values('Name');
    $gene->add_tag_value("Name",$geneID);
    
    # Copy attributes from our original gene to the new gene
    $gene = copy_attributes($gene_feature, $gene);
    
    # Create a new transcript that matches the gene_feature.
    # We'll add the transcript below.
    my $transcript = makeBioperlFeature("transcript", $gene_feature->location, $bp_seq_obj);
    $transcript    = copy_attributes($gene_feature,$transcript);
    
    my @subfeatures = $gene_feature->get_SeqFeatures;
    
#	# Create exons and add them to the transcripts
#	my @exon_locations = $location->each_Location();
#	foreach my $exon_location (@exon_locations){
#	    my $exon   = makeBioperlFeature('exon',$exon_location,$bp_seq_obj);
#	    $transcript->add_SeqFeature($exon);
#	}
#	
#	# Add the transcript to the gene.
#	$gene_feature->add_SeqFeature($transcript);
#
#	# And add the gene back to the seq_obj
#	$bp_seq_obj->add_SeqFeature($gene_feature);
    
    # This will accept genes of type misc_feature (e.g. cgd4_1050 of GI:46229367)
    # because it will have a geneFeature but not standalone misc_feature 
    # as found in GI:32456060.
    # And will accept transcripts that do not have 'gene' parents (e.g. tRNA
    # in GI:32456060)
    foreach my $subfeature (@subfeatures) { 
	
	# Let's only consider RNA subfeatures
	my $type = $subfeature->primary_tag;
#        if (grep {$type eq $_} (
#				'mRNA',
#				'misc_RNA',
#				'rRNA',
#				'snRNA',
#				'snoRNA',
#				'tRNA',
#				'ncRNA',
#				'pseudogenic_transcript',	
#				'scRNA',				
#				)
#	    ) {
	
	# print STDERR "-----------------$type----------------------\n";
	
	if ($type eq 'ncRNA'){
	    if($subfeature->has_tag('ncRNA_class')){
		($type) = $subfeature->get_tag_values('ncRNA_class');
		$subfeature->remove_tag('ncRNA_class');
	    }
	}
	
	if ($type eq 'mRNA') {
	    $type = 'coding';
	}
	
#	# Create a new bioperl object. We may have already done this if there are multiple transcript subfeatures
#	$gene = makeBioperlFeature("${type}_gene", $gene_feature->location, $bp_seq_obj);
#	
#	# Copy the name of the feature to our new gene object
#	my ($geneID) = $gene_feature->get_tag_values('Name');
#	$gene->add_tag_value("Name",$geneID);
#	
#	# Copy attributes from our original gene to the new gene
#	$gene = copy_attributes($gene_feature, $gene);
	
	# Promote subfeature attributes to the gene
	$gene = copy_attributes($subfeature,$gene);
	
	# Handled above.
#	    # Create a new transcript. This should essentially match the subfeature
#	    my $transcript = makeBioperlFeature("transcript", $gene_feature->location, $bp_seq_obj);
#  	    #$transcript   = copy_attributes($subfeature,$transcript);
	
	# Use CDS entries to create exons for these genes.
	if ($type eq 'CDS') {
	    my $codonStart = 0;
	    
	    ($codonStart) = $gene->get_tag_values('codon_start') if $gene->has_tag('codon_start');
	    if ($gene->has_tag('selenocysteine')){
		$gene->remove_tag('selenocysteine');
		$gene->add_tag_value('selenocysteine','selenocysteine');
	    }
	    
	    $codonStart -= 1 if $codonStart > 0;
	    
	    my (@exons, @codingStart, @codingEnd, $codingStart, $codingEnd);
	    my $CDSctr = 0;
	    my $prevPhase = 0; 
	    
	    # Process the 3rd tier (exons and UTRs) if they exist
	    my @containedSubFeatures = $subfeature->get_SeqFeatures;
	    foreach my $subsubFeature (sort {$a->location->start <=> $b->location->start} @containedSubFeatures) {
		
		print STDERR "Processing 3rd tier features...$subsubFeature: $subfeature\n";
		
		if ($subsubFeature->primary_tag eq 'exon') {   
		    my $exon = makeBioperlFeature($subsubFeature->primary_tag,
						  $subsubFeature->location,$bp_seq_obj);
		    push(@exons,$exon);
		}
		
		if ($subsubFeature->primary_tag eq 'CDS'){
		    if ($subsubFeature->location->strand == -1){
			$codingStart = $subsubFeature->location->end;			    
			$codingEnd = $subsubFeature->location->start;
		    } else {
			$codingStart = $subsubFeature->location->start;
			$codingEnd = $subsubFeature->location->end;
		    }
		    
		    push(@codingStart,$codingStart);
		    push(@codingEnd,$codingEnd);
		    $CDSctr++;
		}
		
		
		# There are SOME UTRs from SGD. Capture and create.
		if ($subsubFeature->primary_tag eq 'five_prime_utr' 
		    || $subsubFeature->primary_tag eq 'three_prime_utr' 
		    || $subsubFeature->primary_tag eq 'splice_acceptor_site') {
		    
		    my $utr = makeBioperlFeature($subsubFeature->primary_tag,
						 $subsubFeature->location,
						 $bp_seq_obj);
		    
		    $utr = copy_atttibutes($subsubFeature,$utr);		    
		    push(@utrs,$utr);		    
		}
		
		
		print STDERR "coding start is : " . $#codingStart . "\n";
		$codingStart[$#codingStart] = $codingStart;
		
		$codingStart = shift (@codingStart);
		$codingEnd = shift (@codingEnd);
		foreach my $exon (@exons){		
		    if ($codingStart <= $exon->location->end && $codingStart >= $exon->location->start) {
			$exon->add_tag_value('CodingStart',$codingStart);
			$exon->add_tag_value('CodingEnd',$codingEnd);
			
			$codingStart = shift(@codingStart);
			$codingEnd = shift(@codingEnd);
		    }
		    $transcript->add_SeqFeature($exon);
		}
	    }   
	    
	    # If we don't yet have exons they weren't originally present.
	    # Create them and add them to the transcript.
	    if (!($transcript->get_SeqFeatures())) {
		print STDERR "Creating exons ...\n";
		my @exonLocs = $subfeature->location->each_Location();
		
		foreach my $exonLoc (@exonLocs){
		    my $exon = makeBioperlFeature("exon",$exonLoc,$bp_seq_obj);
		    $transcript->add_SeqFeature($exon);
		    if ($gene->primary_tag ne 'coding_gene' && $gene->primary_tag ne 'pseudo_gene') {
			$exon->add_tag_value('CodingStart', '');
			$exon->add_tag_value('CodingEnd', '');	
		    }
		}
	    }
	    
	    if ($gene->location->start > $transcript->location->start){
		print STDERR "The transcript for gene $geneID is not within parent boundaries.\n";
		$gene->location->start($transcript->location->start);
	    }
	    
	    if ($gene->location->end < $transcript->location->end){
		print STDERR "The transcript for gene $geneID is not within parent boundaries.\n";
		$gene->location->end($transcript->location->end);
	    }
	}
	$gene->add_SeqFeature($transcript);
    }
    
    # Why keep the UTRs distinct?
    return ($gene,\@utrs);
}





sub gene2centraldogma {
    my ($feature,$bp_seq_obj) = @_;
    
    # Fetch/create an appropriate type for a new feature
    my $type;
    my $tag = $feature->primary_tag;
    if ($tag eq 'gene') {
	$type = 'coding_gene';
    } elsif ($tag eq 'ORF') {
	$type = 'coding_gene';
    } elsif ($tag eq 'pseudogene') {
	$type = 'pseudo_gene';
    } else {
	$type = $feature->primary_tag . '_gene';
    }
    print STDERR "Feature type: " . $feature->primary_tag . " $type\n";
    
    my $gene = makeBioperlFeature($type, $feature->location, $bp_seq_obj);
    
    if ($type eq 'pseudo_gene') {
	$gene->add_tag_value("pseudo",""); 
	$gene->primary_tag('pseudo_gene');
    }
    
    # Copy the name of the feature to our new gene object
    my ($name) = $feature->get_tag_values('Name');
    print STDERR "Processing $type ($name)...\n";
    
    $gene->add_tag_value("Name",$name);
    
    # Copy attributes from our original gene to the new gene
    $gene = copy_attributes($feature, $gene);
    
    # Create a new transcript that matches the original feature.    
    # (Will need to iterate when there are multiple transcripts/gene)
    my $transcript = makeBioperlFeature("transcript", $feature->location, $bp_seq_obj);
    
    # Unnecessary.
#    $transcript    = copy_attributes($feature,$transcript);
    
    # Create transcripts and exons and copy UTRs for coding genes,
    # Create transcripts and exons for pseudogenes and small RNAs
    if ($type eq 'coding_gene' 
	|| $type =~ /.*\_gene/) {
	
	# Two-tiered hierachy at SGD
	# Would need to be modified to include alternative transcripts.
	# Subfeatures of coding and pseudo genes at SGD are CDS, intron, UTR
	# Subfeatures of ncRNAs: noncoding_exon
	
	my (@exons,@codingStart,@codingEnd);
        # noncoding_exon or CDS
	foreach my $subfeature (sort {$a->location->start <=> $b->location->start} ($feature->get_SeqFeatures)) { 
	    
	    # Promote subfeature attributes to the gene. Probably unnecessary for SGD.
	    # $gene = copy_attributes($subfeature,$gene);
	    
	    if ($subfeature->primary_tag eq 'noncoding_exon'
		||
		$subfeature->primary_tag eq 'CDS'
		) {
		my $codonStart = 0;
		
		($codonStart) = $gene->get_tag_values('codon_start') if $gene->has_tag('codon_start');
		if ($gene->has_tag('selenocysteine')){
		    $gene->remove_tag('selenocysteine');
		    $gene->add_tag_value('selenocysteine','selenocysteine');
		}
		
		$codonStart -= 1 if $codonStart > 0;
		
		my ($codingStart, $codingEnd);
		my $cds_counter = 0;
		my $prevPhase   = 0; 
		
		if ($subfeature->location->strand == -1){
		    $codingStart = $subfeature->location->end;			    
		    $codingEnd   = $subfeature->location->start;
		} else {
		    $codingStart = $subfeature->location->start;
		    $codingEnd = $subfeature->location->end;
		}
		
		push(@codingStart,$codingStart);
		push(@codingEnd,$codingEnd);
		$cds_counter++;
		
                # my $exon_type = $subfeature->primary_tag eq 'CDS' ? 'exon' : 'noncoding_exon';
		# ncRNAs also required exon type of "exon" 
		my $exon_type = $subfeature->primary_tag eq 'CDS' ? 'exon' : 'exon';
		
		my $exon = makeBioperlFeature($exon_type,
					      $subfeature->location,$bp_seq_obj);
		push(@exons,$exon);	    
		$codingStart[$#codingStart] = $codingStart;
	    }
	    
	    
	    # There are SOME UTRs from SGD. Capture and create.
#		    if ($subsubFeature->primary_tag eq 'five_prime_utr' 
#			|| $subsubFeature->primary_tag eq 'three_prime_utr' 
#			|| $subsubFeature->primary_tag eq 'splice_acceptor_site') {
#			
#			my $utr = makeBioperlFeature($subsubFeature->primary_tag,
#						     $subsubFeature->location,
#						     $bp_seq_obj);
#			
#			$utr = copy_atttibutes($subsubFeature,$utr);		    
#			push (@utrs,$utr);    
#		    }
#		    
	}
	
	# Add all the exons to the current (and sole) transcript.
	my $codingStart = shift (@codingStart);
	my $codingEnd = shift (@codingEnd);
	foreach my $exon (@exons) {
	    
#	    if ($exon->primary_tag eq 'exon') {
	    if ($codingStart <= $exon->location->end && $codingStart >= $exon->location->start) {
		
		# ncRNAs shouldn't have start/stop values
		if ($gene->primary_tag ne 'coding_gene' && $gene->primary_tag ne 'pseudo_gene') {
		    $exon->add_tag_value('CodingStart', '');
		    $exon->add_tag_value('CodingEnd', '');		    
		} else {
		    $exon->add_tag_value('CodingStart',$codingStart);
		    $exon->add_tag_value('CodingEnd',$codingEnd);
		}
		
		$codingStart = shift(@codingStart);
		$codingEnd = shift(@codingEnd);
	    }
#	    }
	    $transcript->add_SeqFeature($exon);
	}
	
#	# If we don't yet have exons they weren't originally present.
#	# Create them and add them to the transcript.
#	if ( ! $transcript->get_SeqFeatures()) {
#	    $transcript = create_exons($transcript,$subfeature,$bp_seq_obj);
#	}
	
    }
    
    # (In)sanity checks
    if ($gene->location->start > $transcript->location->start){
	print STDERR "The transcript for gene $name is not within parent boundaries.\n";
	$gene->location->start($transcript->location->start);
    }
    
    if ($gene->location->end < $transcript->location->end){
	print STDERR "The transcript for gene $name is not within parent boundaries.\n";
	$gene->location->end($transcript->location->end);
    }
    
    $gene->add_SeqFeature($transcript);
    
    return $gene;
    # Why keep the UTRs distinct?
    # return ($gene,\@utrs);
}



sub create_exons {
    my ($transcript,$model_feature,$bp_seq_obj) = @_;
    print STDERR "Creating exons...\n";
    my @exonLocs = $model_feature->location->each_Location();
    
    # One CDS = one exon in SGD world.
    foreach my $exonLoc (@exonLocs){
	my $exon = makeBioperlFeature("exon",$exonLoc,$bp_seq_obj);
	$transcript->add_SeqFeature($exon);
    }
    return $transcript;
}


# Copy qualifiers from a parent feature to children.
sub copy_attributes {
    my ($source_feature,$target_feature) = @_;
    
    for my $qualifier ($source_feature->get_all_tags()) {
	
	if ($target_feature->has_tag($qualifier) 
	    && $qualifier ne "Name" 
	    && $qualifier ne "Parent" 
	    && $qualifier ne "Derives_from") {
	    
	    # remove tag and recreate with merged non-redundant values
	    my %seen;
	    my @uniqVals = grep {!$seen{$_}++} 
	    $target_feature->remove_tag($qualifier), 
	    $source_feature->get_tag_values($qualifier);
	    
	    $target_feature->add_tag_value(
					   $qualifier, 
					   @uniqVals
					   );    
	} elsif ($qualifier ne "Name" 
		 && $qualifier ne "Parent"
		 && $qualifier ne "Derives_from") {
	    $target_feature->add_tag_value(
					   $qualifier,
					   $source_feature->get_tag_values($qualifier)
					   );
	}
	
    }
    return $target_feature;
}

1;




#package Reshaper;
#
#use strict;
#
#sub new {
#    my $class = shift;
#    my $feature = shift;
#    my $this = bless {},$class;
#    $this->{feature} = $feature;
#    return $this;    
#}
#
#sub feature { shift->{feature}; }
#
#1;
