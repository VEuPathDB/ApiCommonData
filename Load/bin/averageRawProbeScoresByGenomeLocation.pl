#!/usr/bin/perl

use strict;

use lib "$ENV{GUS_HOME}/lib/perl";

use Getopt::Long;
use Data::Dumper;
use List::Util qw(sum);

my ($outputFile,$inputFile,$verbose);
&GetOptions("inputFile=s" => \$inputFile,
            "verbose!" => \$verbose,
            "outputFile=s" => \$outputFile);


my %scoreHash;


open (TABFILE, "$inputFile") or die "Cannot open file for reading:  $!";;

while (<TABFILE>){
  chomp;
  my @myArray = split(/\t/, $_);
  my $genomeLoc = $myArray[0]."-".$myArray[1];
  push(@{$scoreHash{$genomeLoc}}, $myArray[2]);

}
close(TABFILE);

#print Dumper (\%scoreHash);

open(FILE, "> $outputFile");

foreach my $k (keys %scoreHash) {
my $average = sum(@{$scoreHash{$k}}) / @{$scoreHash{$k}};
my ($genome, $loc) = split (/-/,$k);
   print FILE "$genome\t$loc\t$average\n";
}

close FILE;
