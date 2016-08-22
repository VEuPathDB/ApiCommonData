#!/usr/bin/perl

## see example at /eupath/data/EuPathDB/manualDelivery/TriTrypDB/tgraANR4/alias/PreviousGeneIDs/2014-06-17/workSpace

use strict;
use Bio::SeqIO;
use Bio::SeqFeature::Tools::Unflattener;
use Getopt::Long;

my ($sequenceAliasFile, $previousGenbankFile, $currentGenbankFile, $help);
&GetOptions('sequenceAliasFile=s' => \$sequenceAliasFile,
            'previousGenbankFile=s' => \$previousGenbankFile,
            'currentGenbankFile=s' => \$currentGenbankFile,
            'help|h' => \$help,
           );

&usage() if($help);
&usage("Missing a Required Argument") unless(defined $sequenceAliasFile && $previousGenbankFile && $currentGenbankFile );


my (%sAliases, %preGeneLocs, %curGeneLocs);
open (SA, "$sequenceAliasFile") || die "can not open sequenceAliasFile file to read\n";
while (<SA>) {
  chomp;
  my @items = split (/\t/, $_);
  $sAliases{$items[1]} = $items[0] if ($items[0] && $items[1]);
}
close SA;

#foreach my $k (sort keys %sAliases) {
#  print "$k; $sAliases{$k}\n";
#}

my $seq_in = Bio::SeqIO->new ('-file' => "<$previousGenbankFile", '-format' => 'Genbank');
my $unflattener = Bio::SeqFeature::Tools::Unflattener->new;

while (my $bioperlSeq = $seq_in->next_seq() ) {
  if(!($bioperlSeq->molecule =~ /rna/i)){

    $unflattener->error_threshold(1);
    $unflattener->report_problems(\*STDERR);
    $unflattener->unflatten_seq(-seq=>$bioperlSeq,
                                 -use_magic=>1);

    my $seqId = $bioperlSeq->id();

    my @topSeqFeatures = $bioperlSeq->get_SeqFeatures;
    $bioperlSeq->remove_SeqFeatures;

    foreach my $bioperlFeatureTree (@topSeqFeatures) {
      my $type = $bioperlFeatureTree->primary_tag();
      if ($type =~ /gene/) {
	my $cID;
	if (($bioperlFeatureTree->has_tag("locus_tag"))){
	  ($cID) = $bioperlFeatureTree->get_tag_values("locus_tag");
	  print STDERR "\nprocessing $cID... in $seqId...aliase is \n";
	}

	my $cStart = $bioperlFeatureTree->location->start();
	my $cEnd = $bioperlFeatureTree->location->end();
#	print STDERR "\$cStart = $cStart, \$cEnd = $cEnd\n";

	$preGeneLocs{$sAliases{$seqId}}{$cStart}{$cEnd} = $cID;
      }
    }
  }
}

my $seq_in = Bio::SeqIO->new ('-file' => "<$currentGenbankFile", '-format' => 'Genbank');
my $unflattener = Bio::SeqFeature::Tools::Unflattener->new;

while (my $bioperlSeq = $seq_in->next_seq() ) {
  if(!($bioperlSeq->molecule =~ /rna/i)){

    $unflattener->error_threshold(1);
    $unflattener->report_problems(\*STDERR);
    $unflattener->unflatten_seq(-seq=>$bioperlSeq,
                                 -use_magic=>1);

    my $seqId = $bioperlSeq->id();

    my @topSeqFeatures = $bioperlSeq->get_SeqFeatures;
    $bioperlSeq->remove_SeqFeatures;

    foreach my $bioperlFeatureTree (@topSeqFeatures) {
      my $type = $bioperlFeatureTree->primary_tag();
      if ($type =~ /gene/) {
	my $cID;
	if (($bioperlFeatureTree->has_tag("locus_tag"))){
	  ($cID) = $bioperlFeatureTree->get_tag_values("locus_tag");
	  print STDERR "\nprocessing $cID... in $seqId...aliase is \n";
	}

	my $cStart = $bioperlFeatureTree->location->start();
	my $cEnd = $bioperlFeatureTree->location->end();
#	print STDERR "\$cStart = $cStart, \$cEnd = $cEnd\n";

	print "$cID\t$preGeneLocs{$seqId}{$cStart}{$cEnd}\n" if ($preGeneLocs{$seqId}{$cStart}{$cEnd});
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
      print STDERR " ";
    }
    print STDERR "$tag: $tag_value\n";
  }
}

sub usage {
  die
"
generate gene aliases based on gene location in genbank format 

Usage: perl createAliasByLocationGenbank.pl --sequenceAliasFile sequenceAliases.txt --previousGenbankFile previousGenome.gbf 
                                              --currentGenbankFile currentGenome.gbf > ../final/aliases.txt 


";
}

