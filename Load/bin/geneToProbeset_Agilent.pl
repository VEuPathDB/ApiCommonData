use strict;
use warnings;
use Data::Dumper;
use lib "$ENV{GUS_HOME}/lib/perl";


my %geneProbeHash;

open(IN, "<", "/eupath/data/EuPathDB/workflows/VectorBase/49/data/agamPEST/gsnap/arrayStudies/A-GEOD-13157-Agilent/geneProbeMapping.tab") or die $!;
open(OUT, ">", "/home/linxu123/VectorBase_A-GEOD-13157-Agilent.txt") or die $!;

while (my $line = <IN>) {
    chomp($line);
    $line =~ s/\r//g;
    my ($gene, $probes) = split(/\t/, $line, 2);
    $probes =~ s/,/\t/g;
    
    my @all = split/\t/,$probes;
    
    my %count;
    for my $i (0..$#all){
        $count{$all[$i]}++;
    }

    my @uniq_times = keys %count;
    for my $i (0..$#uniq_times){
        print OUT "$gene\t$uniq_times[$i]\n";
    }

}



close IN;
close OUT;
