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
#
# Pseudogenes: a CDS carrying a pseudo (or pseudogene) qualifier is loaded as
#   pseudo_gene -> pseudogenic_transcript -> exons

my $PSEUDO_GENE_TYPE       = "pseudogene";
my $PSEUDO_TRANSCRIPT_TYPE = "pseudogenic_transcript";

my @TRANSLATION_QUALIFIERS = ("translation", "protein_id", "codon_start",
                              "transl_table", "transl_except");

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

      # is this CDS a pseudogene?
      my $isPseudo = 0;
      if ($type eq 'coding' &&
          ($bioperlFeatureTree->has_tag('pseudo') || $bioperlFeatureTree->has_tag('pseudogene'))) {
        $isPseudo = 1;
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

      if ($isPseudo) {
        print "  $geneID is a pseudogene; loading as $PSEUDO_GENE_TYPE / $PSEUDO_TRANSCRIPT_TYPE\n";
        foreach my $q (@TRANSLATION_QUALIFIERS) {
          $bioperlFeatureTree->remove_tag($q) if $bioperlFeatureTree->has_tag($q);
        }
        $bioperlFeatureTree->primary_tag($PSEUDO_GENE_TYPE);
      } else {
        $bioperlFeatureTree->primary_tag("${type}_gene");
      }

      my $gene = $bioperlFeatureTree;
      my $geneLoc = $gene->location();
      $gene->add_tag_value("ID",$geneID) if (!$bioperlFeatureTree->has_tag('ID'));

      my $transType = $type;
      $transType = "mRNA" if ($transType eq "coding");
      $transType = $PSEUDO_TRANSCRIPT_TYPE if ($isPseudo);
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
	if($type eq 'coding' && !$isPseudo){
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
	  $CDSLength += (abs($codingStart - $codingEnd) + 1);
	}else{
	  # RNA genes and pseudogenes: no coding coordinates (loaded as null)
	  $exon->add_tag_value('CodingStart','');
	  $exon->add_tag_value('CodingEnd','');
	  $CDSLength += (abs($codingStart - $codingEnd) + 1) unless $isPseudo;
	}
	push(@exons,$exon);
      }

      # no CDS for a pseudogene, so no CDSLength (and no trailing-NA adjustment)
      $transcript->add_tag_value('CDSLength',$CDSLength) unless $isPseudo;

      my $trailingNAs = $isPseudo ? 0 : $CDSLength%3;
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
