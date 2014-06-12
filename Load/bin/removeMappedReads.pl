#!/usr/bin/perl
#Writes unmapped reads from a bamfile to a fastq file
###########################################################
use strict;
use warnings;

use Getopt::Long;


my $bamFileName;
my $outFileName;

&GetOptions(
            "bamFileName|n=s" => \$bamFileName,
            "outFileName|o=s" => \$outFileName
            );


if (! -e $bamFileName){
    die <<endOfUsage;
        removeMappedReads.pl usage:
        removeMappedReads.pl --bamFileName|-n <path to BAM file from which to extract unmapped reads> --outFileName|-o <path to fastq output file>
endOfUsage
}

open(IDS, "samtools view -f 4 $bamFileName | cut -f 1,10,11|") or die "Cannot run samtools command on $bamFileName: $!";

open(OUT, ">$outFileName") or die "Cannot open output file $outFileName for writing\n$!\n";

while (<IDS>) {
  chomp;
  my ($id, $seq, $qual) = split(/\t/, $_);
  print OUT "\@$id\n$seq\n+\n$qual\n";
}
close IDS;
close OUT;
