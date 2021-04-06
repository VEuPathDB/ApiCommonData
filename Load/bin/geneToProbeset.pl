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


my %gene;
open(IN, "<", "/eupath/data/EuPathDB/workflows/VectorBase/49/data/agamPEST/gsnap/arrayStudies/GPL1321_Affy-plasmodiumanopheles/geneProbeMapping.tab") or die $!;
open(OUT, ">", "/home/linxu123/out.txt") or die $!;

while (my $line = <IN>) {
    chomp($line);
    $line =~ s/\r//g;
    $line =~ s/,/-/g; ## format x,y to x-y
    my @all = split/\t/,$line;
    @all[1..$#all] = @probeset{@all[1..$#all]}; ##  '$#all' means the index of the last element in an array
  
=head   
 ----- for comma delimited csv file

    for my $i (0..$#all){
        unless ($all[$i]){
            $all[$i] = '';
        }
    }
    
=cut


    my %count;
    for my $i (1..$#all){
        $count{$all[$i]}++;
    }
        
    my @uniq_times = keys %count;
       
    for my $i (0..$#uniq_times){ 
        print OUT "$all[0]\t$uniq_times[$i]\n";
    }


}



close IN;
close OUT;
