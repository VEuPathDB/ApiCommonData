#!/usr/bin/perl
use strict;
use warnings;
use Getopt::Long;

use lib "$ENV{GUS_HOME}/lib/perl";

my $inputFile;
my $outputFile;

&GetOptions("inputFile|i=s" => \$inputFile,
            "outputFile|o=s" => \$outputFile
            );

if (! -e $inputFile ){
die <<endOfUsage;
reformatSmoothedProfiles.pl usage:

    reformatSmoothedProfiles.pl --inputFile|i <Smoothed profiles to be reformatted> --outputFile|o <path to outputFile>
endOfUsage
} 

open (IN, "<$inputFile") or die "Cannot open file $inputFile for reading\n$!\n";
open (OUT, ">$outputFile") or die "Cannot open file $outputFile for writing\n$!\n";

print OUT "chr\tstart\tend\tscore1\n";

while (<IN>) {
    chomp;
    my ($chr, $coords, $value) = split("\t", $_);
    my ($start, $end) = split("-", $coords);
    print OUT "$chr\t$start\t$end\t$value\n";
}
close IN;
close OUT;
 
exit;
