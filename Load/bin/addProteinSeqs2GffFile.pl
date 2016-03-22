#!/usr/bin/perl

### usage: perl addProteinSeq3GffFile.pl genome.gff protein.fasta > addProt_genome.gff

use strict;

my ($gffFile, $protFile) = @ARGV;

my (%proteins, $seqId);
open (IN, $protFile) || die "can not open protFile file to read.\n";
while (<IN>) {
  chomp;
  next if ($_ =~ /^\s*$/);

  if ($_ =~ /^\>(\S+)/) {
    $seqId = $1;
  } else {
    $proteins{$seqId} .= $_;
  }
}
close IN;

open (INN, $gffFile) || die "can not open gffFile to read\n";
while (<INN>) {
  chomp;
  my @items = split (/\t/, $_);
  #$items[2] = "gene" if ($items[2] eq "CDS");  ## only need with special case
  #$items[8] =~ s/cds_//;  ## only need with special case
  if ($items[2] eq 'mRNA') {
    if ($items[8] =~ /ID \"(\S+?)\"/) {
      $items[8] .= "translation \"$proteins{$1}\"\;";
    }
  }

  foreach my $i (0..8) {
    ($i == 8) ? print "$items[$i]\n" : print "$items[$i]\t";
  }
}
close INN;



