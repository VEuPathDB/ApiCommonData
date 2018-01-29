package ApiCommonData::Load::CdsAndRnas2BioperlTree;

use strict;
use Bio::SeqFeature::Generic;
use Bio::Location::Simple;
use ApiCommonData::Load::BioperlTreeUtils qw{makeBioperlFeature};
use Data::Dumper;

#input: CDS with join location (if multiple exons)
#
#output: standard api tree: gene->transcript->exons
#                                           ->CDS
#
# (1) retype CDS into Gene
# (2) remember its join locations
# (4) create transcript, give it a copy of the gene's location
# (5) add to gene
# (6) create exons from gene location
# (7) add to transcript


sub preprocess {
  my ($bioperlSeq, $plugin) = @_;

  foreach my $bioperlFeatureTree ($bioperlSeq->get_SeqFeatures()) {
    my $type = $bioperlFeatureTree->primary_tag();
    if (grep {$type eq $_} ("CDS", "tRNA", "rRNA", "snRNA", "misc_RNA", "snoRNA","scRNA","ncRNA")) {
      $type = "coding" if $type eq "CDS";

      if($type eq 'ncRNA'){
	  if($bioperlFeatureTree->has_tag('ncRNA_class')){
	    my $ncRNA_class;
	    ($ncRNA_class) = $bioperlFeatureTree->get_tag_values('ncRNA_class');
	    $type = $ncRNA_class if ($ncRNA_class =~ /RNA/i);
	    $bioperlFeatureTree->remove_tag('ncRNA_class');
	  }
      }

      my ($geneID) = $bioperlFeatureTree->get_tag_values('ID') if ($bioperlFeatureTree->has_tag('ID'));

      if($bioperlFeatureTree->has_tag('systematic_id')){
	  ($geneID) = $bioperlFeatureTree->get_tag_values('systematic_id');
	  $bioperlFeatureTree->remove_tag('systematic_id');
      }elsif($bioperlFeatureTree->has_tag('locus_tag')){
	  ($geneID) = $bioperlFeatureTree->get_tag_values('locus_tag');
	  $bioperlFeatureTree->remove_tag('locus_tag');
      }
      print "processing gene $geneID ...\n";

      $bioperlFeatureTree->primary_tag("${type}_gene");

      my $gene = $bioperlFeatureTree;
      my $geneLoc = $gene->location();
      $gene->add_tag_value("ID",$geneID) if (!$bioperlFeatureTree->has_tag('ID'));

#      my $transcript = &makeBioperlFeature("transcript", $geneLoc, $bioperlSeq);
      my $transType = $type;
      $transType = "mRNA" if ($transType eq "coding");
      my $transcript = &makeBioperlFeature("$transType", $geneLoc, $bioperlSeq);

      $transcript = &copyQualifiers($bioperlFeatureTree, $transcript);
      $gene->add_SeqFeature($transcript);

      my @exonLocations = $geneLoc->each_Location();
      my $codonStart = 0;

      ($codonStart) = $bioperlFeatureTree->get_tag_values("codon_start") if $bioperlFeatureTree->has_tag("codon_start");
      my $CDSLength = 0;
      my $CDSLocation = $geneLoc;

      my (@exons,@sortedExons);

      foreach my $exonLoc (@exonLocations) {
	my $exon = &makeBioperlFeature("exon", $exonLoc, $bioperlSeq);

	my($codingStart,$codingEnd);
	if($type eq 'coding'){
	  if($exon->location->strand == -1){

	    $codingStart = $exon->location->end;
	    $codingEnd = $exon->location->start;

	    if($codingStart eq $CDSLocation->end && $codonStart > 0){
	      $codingStart -= $codonStart-1;
	    }
	    $exon->add_tag_value('CodingStart',$codingStart);
	    $exon->add_tag_value('CodingEnd',$codingEnd);

	  }else{

	    $codingStart = $exon->location->start;
	    $codingEnd = $exon->location->end;

	    if($codingStart eq $CDSLocation->start && $codonStart > 0){
	      $codingStart += $codonStart-1;
	    }
	    $exon->add_tag_value('CodingStart',$codingStart);
	    $exon->add_tag_value('CodingEnd',$codingEnd);
	  }
	  $exon->add_tag_value('type','coding');
	}else{
	  $exon->add_tag_value('CodingStart','');
	  $exon->add_tag_value('CodingEnd',''); 
	}
	$CDSLength += (abs($codingStart - $codingEnd) + 1);
	push(@exons,$exon);
      }

      $transcript->add_tag_value('CDSLength',$CDSLength);

      my $trailingNAs = $CDSLength%3;
      my $exonCtr = 0;

      foreach my $exon (sort {$a->location->start() <=> $b->location->start()} @exons){
	if($exon->location->strand() == -1){
	  if($exonCtr == 0 && $trailingNAs > 0 && $exon->has_tag("CodingEnd")){
	    my($codingEnd) = $exon->get_tag_values("CodingEnd");
	    if($codingEnd ne ''){
	      $exon->remove_tag("CodingEnd");
	      $exon->add_tag_value("CodingEnd",$codingEnd+$trailingNAs);
	    }
	  }
	}else{
	  if($exonCtr == $#exons && $trailingNAs > 0 && $exon->has_tag("CodingEnd")){
	    my($codingEnd) = $exon->get_tag_values("CodingEnd");
	    if($codingEnd ne ''){
	      $exon->remove_tag("CodingEnd");
	      $exon->add_tag_value("CodingEnd",$codingEnd-$trailingNAs);
	    }
	  }
	}
	$exonCtr++;
	$transcript->add_SeqFeature($exon);
      }
    }
  }
}

############
sub defaultPrintFeatureTree {
  my ($bioperlFeatureTree, $indent) = @_;

  print("\n") unless $indent;
  my $type = $bioperlFeatureTree->primary_tag();
  print("$indent< $type >\n");
  my @locations = $bioperlFeatureTree->location()->each_Location();
  foreach my $location (@locations) {
    my $seqId =  $location->seq_id();
    my $start = $location->start();
    my $end = $location->end();
    my $strand = $location->strand();
    print("$indent$seqId $start-$end strand:$strand\n");
  }
  my @tags = $bioperlFeatureTree->get_all_tags();
  foreach my $tag (@tags) {
    my @annotations = $bioperlFeatureTree->get_tag_values($tag);
    foreach my $annotation (@annotations) {
      if (length($annotation) > 50) {
	$annotation = substr($annotation, 0, 50) . "...";
      }
      print("$indent$tag: $annotation\n");
    }
  }

  foreach my $bioperlChildFeature ($bioperlFeatureTree->get_SeqFeatures()) {
    &defaultPrintFeatureTree($bioperlChildFeature, "  $indent");
  }
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
