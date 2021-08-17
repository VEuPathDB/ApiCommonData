#!/usr/bin/perl

## usage: perl replaceSequenceIdInGff3WAliases.pl Porcia_deanei_MCOE-BR-91-M13451_TCC258_genome.gff3 sequenceIdMappping.txt > Porcia_deanei_TCC258.gff3

use strict;

my ($inputGFF3, $mappingFile) = @ARGV;

my (%ids);
open (MP, $mappingFile) || die "can not open file $mappingFile to read\n";
while (<MP>) {
  chomp;
  my @items = split (/\t/, $_);
  $ids{$items[1]} = $items[0] if ($items[0] && $items[1]);
}
close MP;

open (IN, $inputGFF3) || die "can not open input file $inputGFF3 to read.\n";
while (<IN>) {
  chomp;
  my @items = split (/\t/, $_);
  $items[0] = $ids{$items[0]} if ($ids{$items[0]});

  foreach my $i (0..$#items) {
    ($i == $#items)? print "$items[$i]\n" : print "$items[$i]\t";
  }
}
close IN;


