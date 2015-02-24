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

if (! -e $inputFile || ! -e $outputFile){
die <<endOfUsage;
reformatPeaks.pl usage:

    reformatPeaks.pl --inputFile|i <Smoothed profiles to be reformatted> --outputFile|o <path to outputFile>
endOfUsage
} 

open (IN, "<$inputFile") or die "Cannot open file $inputFile for reading\n$!\n";
open (OUT, ">$outputFile") or die "Cannot open file $outputFile for writing\n$!\n";

print OUT "chr\tstart\tend\tscore2\tscore1\n";

while (<IN>) {
    chomp;
    unless (/^#/) {
        print OUT "$_\n";
    }
}
close IN;
close OUT;
 
exit;
