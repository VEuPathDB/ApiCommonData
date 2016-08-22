#!/usr/bin/perl

## usage: perl replaceGenbankGffIDWithLocusTag.pl whole_genome.gff > replaced_whole_genome.gff

use strict;

my $gffFile = $ARGV[0];

my (%cLocusId, %cRnaId, $rnaType, %count);

open (GFF, $gffFile) || die "can not open file gffFile to read\n";
while (<GFF>) {
  chomp;

  next if ($_ =~ /^#/);
  my @items = split (/\t/, $_);

  if ($items[2] eq "gene") {
    if ($items[8] =~ /ID=(\S+?)\;.+\;locus_tag=(\S+?)(\;|;$|$)/) {
      my $cGene = $1;
      $cLocusId{$cGene} = $2;
      $count{$cGene} = 1;

      if (!$cGene && !$cLocusId{$cGene}) {
	print STDERR "geneID $cGene or Locus_tag $cLocusId{$cGene} does not exist\n";
      }

      $items[8] =~ s/ID=(\S+?)\;/ID=$cLocusId{$cGene}\;/;
    }
  } elsif ($items[2] eq "mRNA" || $items[2] eq "tRNA"
#	   || $items[2] eq "rRNA" || $items[2] eq "ncRNA"
	   || $items[2] eq "rRNA" || $items[2] eq "ncRNA" ) {
    if ($items[2] eq "mRNA" ) {
      $rnaType = "mRNA";
    } elsif ($items[2] eq "tRNA") {
      $rnaType = "tRNA";
    } elsif ($items[2] eq "rRNA") {
      $rnaType = "rRNA";
    } elsif ($items[2] eq "ncRNA") {
      $rnaType = "ncRNA";
    } else {
      print STDERR "RNA type has not been assigned yet\n";
    }

    if ($items[8] =~ /ID=(\S+?)\;Parent=(\S+?)\;/) {
      my $cRna = $1;
      my $cGene = $2;
      print STDERR "no rna count for $cRna and $cGene\n" if (!$count{$cGene});

#      $cRnaId{$cRna} = $cLocusId{$cGene}."\.$rnaType\.".$count{$cGene};
      $cRnaId{$cRna} = $cLocusId{$cGene}."-t26_".$count{$cGene};  ## only for first time generate, use rnaType is more reasonable

      $items[8] =~ s/ID=$cRna/ID=$cRnaId{$cRna}/;
      $items[8] =~ s/Parent=$cGene/Parent=$cLocusId{$cGene}/;

      $count{$cGene}++;
    }
  } elsif ($items[2] eq "exon" || $items[2] eq "CDS") {
    $items[8] =~ s/\;Parent=(\S+?)\;/\;Parent=$cRnaId{$1}\;/;
  } else {

  }

  &printGff3Column (\@items);
}
close GFF;


sub printGff3Column {
  my $array = shift;
  foreach my $i (0..$#{$array}) {
    ($i == 8) ? print "$array->[$i]\n" : print "$array->[$i]\t";
  }
  return 0;
}

