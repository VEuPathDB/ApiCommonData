#!/usr/bin/perl

## usage: replaceGenbankGffIDWithLocusTag.pl whole_genome.gff3 37 > replaced_whole_genome.gff3

use strict;

my ($gffFile, $bldNum) = @ARGV;

my (%cLocusId, %cRnaId, $rnaType, %count);

open (GFF, $gffFile) || die "can not open file gffFile to read\n";
while (<GFF>) {
  chomp;

  next if ($_ =~ /^#/);
  my @items = split (/\t/, $_);

  if ($items[2] eq "gene" || $items[2] eq "pseudogene") {
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
	   || $items[2] eq "V_gene_segment" || $items[2] eq "C_gene_segment"
	   || $items[2] eq "transcript"
	   || $items[2] eq "telomerase_RNA"
	   || $items[2] eq "antisense_RNA"
	   || $items[2] eq "RNase_MRP_RNA"
	   || $items[2] eq "SRP_RNA" || $items[2] eq "snRNA"
	   || $items[2] eq "miRNA" || $items[2] eq "snoRNA"
	   || $items[2] eq "rRNA" || $items[2] eq "ncRNA" ) {
    if ($items[2] eq "mRNA" ) {
      $rnaType = "mRNA";
    } elsif ($items[2] eq "V_gene_segment" || $items[2] eq "C_gene_segment"
	     || $items[2] eq "telomerase_RNA" || $items[2] eq "antisense_RNA"
	     || $items[2] eq "transcript") {
      $rnaType = "mRNA";
      $items[8] .= ";Loading_note=$items[2]";
      $items[2] = "mRNA";
    } elsif ($items[2] eq "tRNA") {
      $rnaType = "tRNA";
    } elsif ($items[2] eq "rRNA") {
      $rnaType = "rRNA";
    } elsif ($items[2] eq "ncRNA") {
      $rnaType = "ncRNA";
    } elsif ($items[2] eq "miRNA") {
      $rnaType = "miRNA";
    } elsif ($items[2] eq "snoRNA") {
      $rnaType = "snoRNA";
    } elsif ($items[2] eq "snRNA") {
      $rnaType = "snRNA";
    } elsif ($items[2] eq "SRP_RNA") {
      $rnaType = "SRP_RNA";
    } elsif ($items[2] eq "RNase_MRP_RNA") {
      $rnaType = "RNase_MRP_RNA";
    } else {
      print STDERR "RNA type has not been assigned yet\n";
    }

    if ($items[8] =~ /ID=(\S+?)\;Parent=(\S+?)\;/) {
      my $cRna = $1;
      my $cGene = $2;
      print STDERR "no rna count for $cRna and $cGene\n" if (!$count{$cGene});

#      $cRnaId{$cRna} = $cLocusId{$cGene}."\.$rnaType\.".$count{$cGene};
      $cRnaId{$cRna} = $cLocusId{$cGene}."-t".$bldNum."_".$count{$cGene};  ## only for first time generate, use rnaType and count is more reasonable

      ## for the gff3 file downloaded from VectorBase, there are orig_transcript_id in the RNA feature, use these as transcript ID instead
      if ($items[8] =~ /orig_transcript_id=gnl\|WGS:AAAB\|(\S+?)\;/) {
        $cRnaId{$cRna} = $1;
      }

      $items[8] =~ s/ID=$cRna/ID=$cRnaId{$cRna}/;
      $items[8] =~ s/Parent=$cGene/Parent=$cLocusId{$cGene}/;

      $count{$cGene}++;
    }
  } elsif ($items[2] eq "exon" || $items[2] eq "CDS") {
    if ($items[8] =~ /\;Parent=(\S+?)\;/) {
      my $cParent = $1;
      if ($cRnaId{$cParent}) { # if the parent is rna
	$items[8] =~ s/\;Parent=(\S+?)\;/\;Parent=$cRnaId{$1}\;/;
      } elsif ($cLocusId{$cParent}) { # if the parent is gene
	$items[8] =~ s/\;Parent=(\S+?)\;/\;Parent=$cLocusId{$1}\;/;
      }
    } else {
      print STDERR "no parent found for $items[8]\n";
    }
  } elsif ($items[2] eq "region" || $items[2] eq "sequence_feature" ) {
    ## for those that do not need anything
  } else {
    print STDERR "type: $items[2] has not been assigned yet\n";
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

