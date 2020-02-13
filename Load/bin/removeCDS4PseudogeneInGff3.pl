#!/usr/bin/perl

use strict;

my $input = $ARGV[0];

open (IN, $input) || die "can not open input file to read.\n";
while (<IN>) {
  chomp;
  my @items=split (/\t/, $_);

  next if ($items[2] eq "CDS" && $items[8] =~ /biotype=pseudogenic_exon;/);

  print "$_\n";
}
close IN;
