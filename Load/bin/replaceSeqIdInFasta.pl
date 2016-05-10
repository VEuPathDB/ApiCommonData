#!/usr/bin/perl

use strict;

## a script to replace fasta head line with different name
## usage: replaceSeqIdInFasta.pl Phchr2_AssemblyScaffolds.fasta scaffold_ PchrRP-78_ 3 > whole_genome.fasta

my ($inputFile, $orig, $repd, $c) = @ARGV;

open (IN, $inputFile) || die "can not open input file to read.\n";
while (<IN>) {
  chomp;
  my @items = split (/\t/, $_);

  if ($_ =~ /^>$orig(\d+)/) {
    my $sc = $1;
    my $patten = "%0".$c."d";
    my $replaced = $repd."SC".sprintf("$patten", $sc);

    $_ = ">$replaced";
  }
  print "$_\n";

}
close IN;

