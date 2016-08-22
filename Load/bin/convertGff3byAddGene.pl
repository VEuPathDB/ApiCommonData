#!/usr/bin/perl

use strict;

## a script to make standard gff3 file with gene->mRNA->CDS(|exon)
## original file has mRNA and CDS
## usage: 


my $input = $ARGV[0];

print "##gff-version 3\n";

my ($gId);
open (IN, $input) || die "can not open input file to read.\n";
while (<IN>) {
  chomp;

  ## skip the comment line(s)
  next if ($_ =~ /^\#/); 

  my @items = split (/\t/,$_);
  if ($items[2] eq "mRNA") {
    if ($items[8] =~ /ID=(\S+?);/) {
      $gId = $1;
      $gId =~ s/mRNA://;
    }
    $items[8] = $items[8]. "Parent=" .$gId.";";

    &printGff3Column (\@items);

    ## add gene line
    $items[2] = "gene";
    $items[8] = "ID=".$gId.";";

    &printGff3Column (\@items);

  } else {

    &printGff3Column (\@items);
  }

}
close IN;


sub printGff3Column {
  my $array = shift;
  foreach my $i (0..$#{$array}) {
    ($i == 8) ? print "$array->[$i]\n" : print "$array->[$i]\t";
  }
  return 0;
}
