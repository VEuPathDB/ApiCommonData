package ApiCommonData::Load::DnaSeqMetrics;

use strict;
use warnings;
use CBIL::Util::Utils;
use Data::Dumper;

sub getCoverage {
    my ($analysisDir, $bamFile) = @_;
    my $genomeFile = &getGenomeFile($bamFile, $analysisDir);
    my @coverage = split(/\n/, &runCmd("bedtools genomecov -ibam $bamFile -g $genomeFile"));
    my $genomeCoverage = 0;
    my $count = 0;
    foreach my $line (@coverage) {
        if ($line =~ /^genome/) {
            my ($identifier, $depth, $freq, $size, $proportion) = split(/\t/, $line);
            $genomeCoverage += ($depth*$freq);
            $count += $freq;
        }
    }
    return ($genomeCoverage/$count);
}

sub getMappedReads {
    my $bamFile = shift;
    my $mappedReads = &runCmd("samtools view -F 0x04 -c $bamFile");
    my $totalReads = &runCmd("samtools view $bamFile | wc -l");
    return ($mappedReads/$totalReads);
}

sub getGenomeFile {
    my ($bamFile, $workingDir) = @_;
    open (G, ">$workingDir/genome.txt") or die "Cannot open genome file $workingDir/genome.txt for writing\n";
    my @header = split(/\n/, &runCmd("samtools view -H $bamFile"));
    foreach my $line (@header) {
        if ($line =~ m/\@SQ\tSN:/) {
            $line =~ s/\@SQ\tSN://;
            $line =~ s/\tLN:/\t/;
            print G "$line\n";
        }
    }
    close G;
    return "$workingDir/genome.txt";
}
    

1;
