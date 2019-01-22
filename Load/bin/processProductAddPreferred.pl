#!/usr/bin/perl

use lib "$ENV{GUS_HOME}/lib/perl";
use strict;
use Getopt::Long;

my ($inputFile, $outputFile, $help);

&GetOptions(
            'help|h' => \$help,
            'inputFile=s' => \$inputFile,
            'outputFile=s' => \$outputFile,
           );

&usage() if($help);
&usage("Missing a Required Argument") unless(defined $inputFile && $outputFile);

my (%products, %isPreferred, %isPreferredProd, %assignedProduct);

open (IN, $inputFile) || die "can not open inputFile to read\n";
open(OUT,">$outputFile") || die "can not open outputFile to write\n";

while (<IN>) {
  chomp;
  my @items= split (/\t/, $_);

  ## check if the product name has been assigned to this gene
  $items[1] =~ s/\;/\,/g;
  my $pkey = "$items[1];$items[3];$items[4];$items[5]";

  if (!$assignedProduct{$items[0]}{$pkey}) {
    push @{$products{$items[0]}}, $pkey;
    $assignedProduct{$items[0]}{$pkey} = 1;
  }

  if ($items[2] == 1 || $items[2] =~ /true/) {
    $isPreferred{$items[0]} = 1;
    $isPreferredProd{$items[0]}{$pkey} = 1;
  }
}

my $is_preferred;
foreach my $k (sort keys %products) {
#  print STDERR "$k, $#{$products{$k}}\n";
  foreach my $i (0..$#{$products{$k}}) {
    if ($#{$products{$k}} == 0 ) {
      $is_preferred = 1;
    } else {
      if ($isPreferred{$k}) {
	if ($isPreferredProd{$k}{$products{$k}[$i]}) {
	  $is_preferred = 1;
	} else {
	  $is_preferred = 0;
	}
      } else {
	$is_preferred = ($i == 0) ? 1 : 0;
      }
    }
#    print OUT "$k\t$products{$k}[$i]\t$is_preferred\n";
    my @pValue = split (/;/, $products{$k}[$i]);
    print OUT "$k\t$pValue[0]\t$is_preferred\t$pValue[1]\t$pValue[2]\t$pValue[3]\n";
  }
}
close IN;
close OUT;


sub usage {
  die
"
Process product name file. If there is only one product per gene, the 3nd column add value 1.
If there is more than one product name per gene, the 3nd column add value 1 if there is is_preferred = true or 1,
otherwise the 3nd column add value 0.

Usage:  perl processProductAddPreferred.pl --inputFile product.txt --outputFile isPreferredProduct.txt

where
  --inputFile:   the input file, two or three column 
  --outputFile: the output file with the 3nd column always has value
";
}





