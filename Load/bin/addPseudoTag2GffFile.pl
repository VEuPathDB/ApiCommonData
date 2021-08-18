#!/usr/bin/perl

### usage: addPseudoTag2GffFile.pl whole_genome.gff.woPseudo internalStopCodonGeneList.txt > whole_genome.gff

use strict;

my ($gffFile, $pseudoFile) = @ARGV;

my (%isPseudo);
open (IN, $pseudoFile) || die "can not open pseudoFile file to read.\n";
while (<IN>) {
  chomp;
  next if ($_ =~ /^\s*$/);
  $_ =~ s/\*\*\*WARNING\*\*\*\*\*\*\*\*\*\s+transcript\s*//;
  $_ =~ s/\s*contains internal stop codons\.//;
  $isPseudo{$_} = 1;
}
close IN;

open (INN, $gffFile) || die "can not open gffFile to read\n";
while (<INN>) {
  chomp;
  my @items = split (/\t/, $_);
  if ($items[2] eq 'mRNA') {
    if ($items[8] =~ /ID \"(\S+?)\"/) {
      if ($isPseudo{$1}) {
	$items[8] .= "pseudo \"\"\;";
      }
    }
  }

  foreach my $i (0..8) {
    ($i == 8) ? print "$items[$i]\n" : print "$items[$i]\t";
  }
}
close INN;



