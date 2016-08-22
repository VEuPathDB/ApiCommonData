#!/usr/bin/perl

use strict;

## usage: replaceSeqIdInGff.pl whole_genome.gff.prev pag1_scaffold_ PaphDAOMBR444_ > whole_genome.gff.seqId


my ($inputFile, $orig, $repd, $c) = @ARGV;

open (IN, $inputFile) || die "can not open input file to read.\n";
while (<IN>) {
  chomp;
  my @items = split (/\t/, $_);

  if ($_ =~ /^$orig(\d+)/) {
    my $cId = $1;

    my $patten = "%0".$c."d";
    my $replaced = $repd."SC".sprintf("$patten", $cId);

    $_ =~ s/^$orig(\d+)/$replaced/;
  }
  print "$_\n";
}
close IN;

