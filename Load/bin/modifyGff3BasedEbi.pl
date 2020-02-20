#!/usr/bin/perl

## this script contain all special requirements that EBI wants for gff3

use strict;

my $input = $ARGV[0];

open (IN, $input) || die "can not open input file to read.\n";
while (<IN>) {
  chomp;
  my @items=split (/\t/, $_);

  next if ($items[2] eq "CDS" && $items[8] =~ /biotype=pseudogenic_exon;/);
  next if (($items[2] eq "three_prime_UTR" || $items[2] eq "five_prime_UTR") && $items[8] =~ /biotype=pseudogenic_exon;/);

  if ($items[2] eq "CDS" ) {
    $_ =~ s/ID=(\S+?)-CDS\d+;/ID=$1;/i;
  }

  print "$_\n";

}
close IN;
