#!/usr/bin/perl
# This script uses samtools and BEDtools

use strict;
use warnings;
use Getopt::Long;

my $bamFile;
my $window;
my $outputFile;
my $samtoolsIndex;

&GetOptions("bamFile|b=s" => \$bamFile,
            "window|w=i" => \$window,
            "outputFile|o=s" => \$outputFile,
            "samtoolsIndex|s=s" => \$samtoolsIndex
            );

if (! -e $bamFile || ! -e $samtoolsIndex){
die <<endOfUsage;
generateBinnedCoverage.pl usage:

    generateBinnedCoverage.pl --bamFile|b <bamFile of mapped reads from which to generate coverage> --window|w <size of bins in which to calculate coverage> --outputFile|o <path to outputFile> --samtoolsIndex|s <path to samtools index of genome>
endOfUsage
} 
 
    # Creates BED file from indexed genome using given window size
    sub createBed {
        my ($index, $winLen) = @_;
        my $bedfile = (split /\./, $index)[0]."_$winLen.bed";
        open (OUT, ">$bedfile") or die "Cannot write to temporary file\n$!\n";
        open (IN, "$index") or die "Cannot open .fai index file for reading\n$!\n";
        while (<IN>) {
            my ($chr, $length, $cumulative, $lineLength, $lineBLength) = split(/\t/,$_);
            die "Chromosome and length are not defined for line $. in $index. [$chr,$length]\n" unless(defined($chr) && defined($length));
            for (my $i=1; $i+$winLen<$length; $i+=$winLen){
                printf OUT "%s\t%d\t%d\t\n", $chr, $i, $i+$winLen-1;
            }
            printf OUT "%s\t%d\t%d\n", $chr, $length-($length % $winLen)+1, $length unless ($length % $winLen ==0);
        }
    close(IN);
    close(OUT);
    return $bedfile
    }

    # gets coverage for each window - uses BAM file of mapped reads and BED file for windows on genome
    sub getCoverage {
        my ($bed, $bam, $out) = @_;
        my @coverageBed = `bedtools coverage -abam $bam -b $bed`;
        my $totalMapped = `samtools view -c -F 4 $bam`;
        open (OUT, ">$out") or die "Cannot write output file\n$!\n";
        foreach (@coverageBed){
            my ($chr, $start, $end, $mapped, $numNonZero, $lenB, $propNonZero) = split(/\t/,$_);
            die "Chromosome, start and end coordinates or number of mapped reads are not defined\n$!\n" unless (defined($chr) && defined($start) && defined($end) && defined($mapped));
            $mapped = $mapped/$totalMapped;
            printf OUT "%s\t%d\t%d\t%g\n", $chr, $start, $end, $mapped;
        }
        close OUT;
    }


    my $bedfile = createBed($samtoolsIndex, $window);
    unless (-e $bedfile){
        die "Bedfile was not successfully created\n";
    }

    my $coverage = getCoverage($bedfile, $bamFile, $outputFile);
        
    system ("rm $bedfile");
exit;
