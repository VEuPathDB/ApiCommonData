use strict;
use warnings;
use Data::Dumper;
use lib "$ENV{GUS_HOME}/lib/perl";


my %geneProbeHash;

open(IN, "<", "/eupath/data/EuPathDB/workflows/VectorBase/49/data/aaegLVP_AGWG/gsnap/arrayStudies/A-MEXP-1878-Agilent/geneProbeMapping.tab") or die $!;
open(OUT, ">", "/eupath/data/EuPathDB/manualDelivery/VectorBase/agamPEST/dbxref/A-MEXP-1878-Agilent_geneMapping/2021-04-08/final/mapping.txt") or die $!;

while (my $line = <IN>) {
    chomp($line);
    $line =~ s/\r//g;
    my ($gene, $probes) = split(/\t/, $line, 2); 
    #$probes =~ s/,/\t/g;
    
    my @all = $probes =~ m/("[^"]+"|[^,]+)(?:,\s*)?/g;
    
    my %count;
    for my $i (0..$#all){
        $count{$all[$i]}++;
    }

    my @uniq_times = keys %count;
    for my $i (0..$#uniq_times){
        $uniq_times[$i] =~ s/"//g;
        print OUT "$gene\t$uniq_times[$i]\n";
    }

}


close IN;
close OUT;
