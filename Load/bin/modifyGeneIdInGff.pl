#!/usr/bin/perl

## usage: perl modifyGeneIdInGff.pl whole_genome.gff.seqIdReplaced NfTY_ > whole_genome.gff

use strict;

my ($inputGFF3, $prefix) = @ARGV;


open (IN, $inputGFF3) || die "can not open input file $inputGFF3 to read.\n";
my $num;
while (<IN>) {
  chomp;
  if ($_ =~ /ID=g(\d+)/) {
    $num = $1;
    $num = sprintf("%05d", $num);
    $num .= "0";
    $num = $prefix . $num;
    $_ =~ s/ID=g(\d+)/ID=$num/;
  }

  if ($_ =~ /Parent=g(\d+)/) {
    $num = $1;
    $num = sprintf("%05d", $num);
    $num .= "0";
    $num = $prefix . $num;
    $_ =~ s/Parent=g(\d+)/Parent=$num/;
  }

  print "$_\n";
}
close IN;


