#!/usr/bin/perl

use strict;
use warnings;
use Getopt::Long;


   
# get parameter values
my $experimentDir;
my $outputDir;
my $chromSizesFile;

&GetOptions("experimentDir|e=s" => \$experimentDir,
            "outputDir|o=s" => \$outputDir,
            "chromSizesFile|c=s" => \$chromSizesFile);

# extract information from a bedFile of binned coverage
sub bedExtract {
    my $bedFile = "@_";
    open (BED, "$bedFile") or die "Cannot open $bedFile\n$!\n";
    my @bedLines;
    while (<BED>) {
        my ($chr, $start, $end, $mapped) = split(/\t/,$_);
        push (@bedLines, [$chr, $start, $end, $mapped]);
    }
    close (BED);
    return \@bedLines 
}

# Extract the name of the sample from the name of the bedfile
sub bedName {
    my $bedFile = "@_";
    my $fileName = (split(/\/([^\/]+)$/, $bedFile))[1];
    my $sampleName = (split(/\./, $fileName))[0];
    return $sampleName
}

# Calculate coverage ratio for each bin for every pair of bedfiles
my @bedFiles = `ls $experimentDir/*.bed`;
for (my $i=0; $i<scalar @bedFiles; $i++){
    my $refCoverage = bedExtract($bedFiles[$i]);
    my $refName = bedName($bedFiles[$i]);
    for (my $j=0; $j<scalar @bedFiles; $j++){
        if ($i != $j) {
            my $compCoverage = bedExtract($bedFiles[$j]);
            my $compName = bedName($bedFiles[$j]);
            my $count = 0;
            my $outputFile = $outputDir."/".$refName."_".$compName.".bed.tmp";
            open (OUT, ">$outputFile") or die "Cannot write output file\n$!\n";
            foreach my $ref (@{$refCoverage}){
                my ($refChr, $refStart, $refEnd, $refMapped) = @{$ref};
                my ($compChr, $compStart, $compEnd, $compMapped) = @{@{$compCoverage}[$count]};
                ++$count;
                if ($refChr eq $compChr && $refStart  == $compStart && $refEnd == $compEnd){
                    my $mapRatio = $compMapped/$refMapped unless ($refMapped == 0 || $compMapped == 0);
                    if (defined ($mapRatio)){
                        printf OUT "%s\t%d\t%d\t%g\n", $refChr, $refStart, $refEnd, $mapRatio;
                    }
                } else {
                    die "Element in reference and comparison arrays are not in the same order\n";
                }    
            }
            close (OUT);
            # sort bedGraph file
            my $sortedOutput = $outputDir."/".$refName."_".$compName.".bed";
            system ("sort -k1,1 -k2,2 $outputFile > $sortedOutput");
            # convert to bigwig
            my $bigWig = $outputDir."/".$refName."_".$compName.".bw";
            system ("bedGraphToBigWig $sortedOutput $chromSizesFile $bigWig");
            # remove unsorted bedGraphs
            system ("rm -f $outputFile");

        }
    }
}


exit;
