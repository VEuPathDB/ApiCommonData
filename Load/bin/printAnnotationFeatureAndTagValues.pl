#!/usr/bin/perl

## usage: if genbank or embl use $seq_in = Bio::SeqIO->new
##        if gff3, use $gffio = Bio::Tools::GFF->new (not test yet)


use strict;
use Bio::SeqIO;
use Bio::Seq::SeqBuilder;
use Bio::Species;
use Bio::Annotation::SimpleValue;
use Bio::SeqFeature::Tools::Unflattener;
use Bio::Tools::GFF;
use Bio::SeqFeature::Tools::Unflattener;
use ApiCommonData::Load::Unflattener;

my $seq_in = Bio::SeqIO->new ('-file' => "$ARGV[0]", '-format' => "genbank");
#my $gffFile = $ARGV[0];
#my $gffio = Bio::Tools::GFF->new(-file => $gffFile, -gff_version => 3);

#while (my $bioperlSeq = $gffio->next_feature() ) {
while (my $bioperlSeq = $seq_in->next_seq() ) {

  my $unflattener = Bio::SeqFeature::Tools::Unflattener->new;
#  my $unflattener = ApiCommonData::Load::Unflattener->new;

  if(!($bioperlSeq->molecule =~ /rna/i)){

    $unflattener->error_threshold(1);
    $unflattener->report_problems(\*STDERR);
    $unflattener->unflatten_seq(-seq=>$bioperlSeq,
				-use_magic=>1);

    my @topSeqFeatures = $bioperlSeq->get_SeqFeatures;

    $bioperlSeq->remove_SeqFeatures;

    foreach my $bioperlFeatureTree (@topSeqFeatures) {
      my $type = $bioperlFeatureTree->primary_tag();
      if (($bioperlFeatureTree->has_tag("locus_tag"))){
	my ($cID) = $bioperlFeatureTree->get_tag_values("locus_tag");
	print STDERR "\nprocessing $cID...\n";
      } elsif (($bioperlFeatureTree->has_tag("ID"))){
	my ($cID) = $bioperlFeatureTree->get_tag_values("ID");
	print STDERR "\nprocessing $cID..\n";
      }

      print "\< $type \>\n";
      &printTagsValues($bioperlFeatureTree, 2);

	foreach my $subFeat ($bioperlFeatureTree->get_SeqFeatures) {
	  my $subType = $subFeat->primary_tag();
	  print "  \< $subType \>\n";
	  &printTagsValues($subFeat, 4);

	  foreach my $subSubFeat ($subFeat->get_SeqFeatures) {
	    my $subSubType = $subSubFeat->primary_tag();
	    print "      \< $subSubType \>\n";
#	    if ($subSubType eq "CDS" || $subSubType eq "exon" ) {
	      my @CDSLocs = $subSubFeat->location;
	      foreach my $CDSLoc (@CDSLocs) {
		my $subSubStart = $CDSLoc->start();
		my $subSubEnd = $CDSLoc->end();
		print "            location: $subSubStart .... $subSubEnd\n";
	      }
#	    }
	  }
	}
    }
  }
}

############
sub printTagsValues {
  my ($feature, $index) = @_;
  foreach my $tag ($feature->get_all_tags) {
    my ($tag_value) = $feature->get_tag_values($tag);
    foreach my $i (0..$index-1) {
      print " ";
    }
    print "$tag: $tag_value\n";
  }
}



