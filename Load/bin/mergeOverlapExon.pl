#!/usr/bin/perl

use strict;

## a script to merge overlapping and abutting exons as a single exon
## usage1: mergeOverlapExon.pl whole_genome.gff.save gff3 > whole_genome.gff
## usage2: mergeOverlapExon.pl ../final/genome.embl.save embl > ../final/genome.embl


my ($inputFile, $format) = @ARGV;

my ($preLine, @preArray, %cdsSpanStart, %cdsSpanEnd, %preStart, %preEnd, $curTran);

open (IN, $inputFile) || die "can not open input file to read.\n";

while (<IN>) {

  if ($format !~ /gff/i) {
    if ($_ =~ /^FT   CDS   .+\((\d+.+\d+?)\).*/) {

      my @cdsArray = split (/\,/, $1);

      my ($pStart, $pEnd, @newCdsStringArray);

      foreach my $i (0..$#cdsArray) {
	my ($s, $e) = split (/\.\./, $cdsArray[$i]);
	if ($s <= $pEnd+1 && $pEnd) {
	  $pEnd = $e;
	  next;
	} else {
	  push (@newCdsStringArray, "$pStart..$pEnd")if ($pStart && $pEnd);
	  $pStart =$s;
	  $pEnd = $e;
	}
      }
      push (@newCdsStringArray, "$pStart..$pEnd");  ## add the last pair
      my $newCdsString = join (",", @newCdsStringArray);
      $_ =~ s/\((\d+.+\d+?)\)/\($newCdsString\)/;
    }
    print "$_";
  } else {
    chomp;
    my @items = split (/\t/, $_);


    if ($items[2] eq "CDS" || $items[2] eq "pseudogenic_exon") {
      if ($items[8] =~ /Parent \"(\S+?)\"/ ) {
	$curTran = $1;
      }

      ## assume the exons go by order and the 4th column is always smaller than 5th column. 
      ## It is the case for the gff file that need to deal with here
      if ($items[3] <= ($preEnd{$curTran}+1) && $items[3] != 1 ) {
	$preArray[4] = $items[4];

	$preLine = join ("\t", @preArray);
	$preStart{$curTran} = min ($items[3], $preArray[4]);
	$preEnd{$curTran} = max ($items[3], $preArray[4]);
	next;
      }

      $preStart{$curTran} = min ($items[3], $items[4]);
      $preEnd{$curTran} = max ($items[3], $items[4]);
    } else {
      @preArray = ();
    }
    print "$preLine\n" if ($preLine);
    $curTran = "";

    @preArray = @items;
    $preLine = join ("\t", @preArray);
  }

}
close IN;

print "$preLine\n" if ($preLine); ## print the last line

#&printTabColumn (\@preArray);

sub printTabColumn {
  my $array = shift;
  foreach my $i (0..$#{$array}) {
    ($i == $#{$array}) ? print "$array->[$i]\n" : print "$array->[$i]\t";
  }
  return 0;
}

sub max ($$) { $_[$_[0] < $_[1]] }

sub min ($$) { $_[$_[0] > $_[1]] }
