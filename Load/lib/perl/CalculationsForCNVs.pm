package ApiCommonData::Load::CalculationsForCNVs;

use strict;
use warnings;
use Statistics::Descriptive;

# Common subroutines used by CNV scripts

sub getChrFPKMVals {
    my $fpkmFile = $_;
    my $chrValues = {};
    open (FPKM, $fpkmFile) or die "Cannot read fileof FPKM values $fpkmFile\n$!\n";
    while (<FPKM>) {
        my $line = $_;
        chomp($line);
        next if ($line=~/^tracking_id\t/);
        my @data = split(/\t/, $line);
        die "Bad line count [$fpkmFile line $. ".scalar(@data)."]\n" unless (scalar(@data)) >11;
        my ($chr, $fpkmVal) = ($data[6], $data[9]);
        $chr=~s/\:\d+\-\d+$//;
        die "Cannot extract chromosome and FPKM values from $fpkmFile line $.\n" unless (defined($chr) && defined($fpkmVal));
        # Remove empty SL RNAs that bias chromosomes to 0
        next if ($fpkmVal == 0);
        push @{$chrValues->{$chr}},$fpkmVal;
    }
    return $chrValues;
}

sub getChrMedians {
    my $chrValues = $_;
    my $chrMedians = {};
    my $stat = Statistics::Descriptive::Full->new();
    foreach my $chr (keys %{$chrValues}){
        $stat->clear;
        $stat->add_data(@{$chrValues->{$chr}});
        $chrMedians->{$chr} = $stat->medians();
    }
    return $chrMedians;
}

sub getMedianAcrossChrs {
    my $chrValues = $_;
    my @medians;
    my $stat = Statistics::Descriptive::Full->new();
    foreach my $chr (keys %{$chrValues}){
        $stat->clear();
        $stat->add_data(@{$chrValues->{$chr}});
        push @medians, $stat->median();
    }
    $stat->clear();
    $stat->add_data(@medians);
    my $allChrMedian = $stat->median();
    return $allChrMedian;
}

sub getChrPloidies {
    my ($chrMedians, $allChrMedian, $ploidy) = @_;
    my $chrPloidies = {};
    foreach my $chr (keys %{$chrMedians}){
        if ($allChrMedian == 0){
            print STDERR "Error:Division by 0 - no overall median from chromosom $chr\n";
            $chrPloidies->{$chr} = 0;
            next;
        }
        $chrPloidies->{$chr} = int(($chrMedians->{$chr}/($allChrMedian/$ploidy))+0.5);
        if ($chrPloidies->{$chr} eq 0){
            print STDERR "Error: Chromosome $chr has a predicted ploidy of 0\n";
        }
    }
    return $chrPloidies;
}
1;
