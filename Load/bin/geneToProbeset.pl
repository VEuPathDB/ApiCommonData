use strict;
use warnings;
use Data::Dumper;
use lib "$ENV{GUS_HOME}/lib/perl";


my %probeset;
open(IN, "<", "/eupath/data/EuPathDB/manualDelivery/VectorBase/agamPEST/microarrayPlatform/GPL1321_Affy-plasmodiumanopheles/1.0/fromProvider/Plasmodium_Anopheles_probe_tab") or die $!;
while (my $line = <IN>) {
    if ($. == 1){
	my $header = $line;
    }else{
        chomp($line);
        $line =~ s/\r//g;
        my @all = split/\t/,$line;
        $probeset{$all[1]."-".$all[2]} = $all[0];
    }
}
close IN;

#$probeset{""} = '';


my %geneProbeHash;

open(IN, "<", "/eupath/data/EuPathDB/workflows/VectorBase/49/data/agamPEST/gsnap/arrayStudies/GPL1321_Affy-plasmodiumanopheles/geneProbeMapping.tab") or die $!;
open(OUT, ">", "/home/linxu123/outnew.txt") or die $!;

while (my $line = <IN>) {
    chomp($line);
    $line =~ s/\r//g;
    $line =~ s/,/-/g; 
    my @all = split/\t/,$line;
    
    for my $i (1..$#all){
	$geneProbeHash{$all[0]} -> {$probeset{$all[$i]}}++    

    }    

}

foreach my $gene (sort keys %geneProbeHash){
    foreach my $prob (sort keys %{$geneProbeHash{$gene}}){
        print OUT "$gene\t $prob\n"
    }
}

close IN;
close OUT;

