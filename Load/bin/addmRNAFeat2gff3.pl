#!/usr/bin/perl

use List::Util qw[min max];

use strict;

## a script to generate a transcript ID, add a mRNA line,
## and reassign the parent of exon and/or CDS to transcript ID instead of gene ID
## usage: addmRNAFeat2gff3.pl whole_genome.gff3.womRNA 37 > whole_genome.gff3


my ($input, $bldNum) = @ARGV;
my ($cGene, $preGene, $cTrans, %starts, %ends, @preLine);

open (IN, $input) || die "can not open input file to read.\n";
while (<IN>) {
    chomp;

    ## skip the comment line(s)
    next if ($_ =~ /^\#/); 

    my @items = split (/\t/, $_);

    if ($items[2] eq "gene") {
      if (@preLine) {
	$preLine[2] = "mRNA";
	$preLine[3] = $starts{$cGene};
	$preLine[4] = $ends{$cGene};
	$preLine[7] = ".";
	$preLine[8] =~ s/ID=(\S+?)\;Parent=(\S+?)\;/ID=$cTrans\;Parent=$cGene\;/;
	&printGff3Column (\@preLine);
      }
      if ($items[8] =~ /ID=(\S+?)\;/) {
	$cGene = $1;
	$cTrans = $cGene."-t".$bldNum."_1";  ## only one transcript for each gene in this case
      }
    } elsif ($items[2] eq "CDS" || $items[2] eq "exon") {
      if ($cTrans) {
	$items[8] =~ s/\;Parent=(\S+?)\;/\;Parent=$cTrans\;/;
      }
      $starts{$cGene} = ($starts{$cGene}) ? min($starts{$cGene}, $items[3], $items[4]) : min($items[3], $items[4]);
      $ends{$cGene} = ($ends{$cGene}) ? max($ends{$cGene}, $items[3], $items[4]) : max($items[3], $items[4]);

      if ($cGene eq "CKF44_006957") {
	print STDERR "\$items[3] = $items[3]; \$items[4] = $items[4]; start = $starts{$cGene}; end = $ends{$cGene}\n";
      }
    }

    &printGff3Column (\@items);

    ## reset values before go to next line
    @preLine = @items if ($items[2] eq "CDS" || $items[2] eq "exon");
}

## print the last mRNA line
$preLine[2] = "mRNA";
$preLine[3] = $starts{$cGene};
$preLine[4] = $ends{$cGene};
$preLine[7] = ".";
$preLine[8] =~ s/ID=(\S+?)\;Parent=(\S+?)\;/ID=$cTrans\;Parent=$cGene\;/;

&printGff3Column (\@preLine);

############
sub printGff3Column {
  my $array = shift;
  foreach my $i (0..$#{$array}) {
    ($i == 8) ? print "$array->[$i]\n" : print "$array->[$i]\t";
  }
  return 0;
}

