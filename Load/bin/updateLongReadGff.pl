#!/usr/bin/perl

use strict;
use lib $ENV{GUS_HOME} . "/lib/perl";
use Getopt::Long;
use CBIL::Util::Utils;
use IO::Zlib;
use Bio::Tools::GFF;


my ($help, $count_file, $gff_file, $gffOut); 

&GetOptions('help|h' => \$help,
            'gffFile=s' => \$gff_file,
            'countFile=s' => \$count_file,
            'outputGFF=s' => \$gffOut,
            );

&usage("Count File not specified") unless $count_file;

my %transcript_counts = ();
my $count_file = $count_file;
open(my $count, $count_file) or die "Could not open file '$count_file' $!";
my $line = <$count>;
my @header = split /\s+/,$line;
my $len = scalar @header;
    
    while (my $row = <$count>) {
        chomp $row;
        my @counts_list = split /\s+/,$row;
        next if $. == 1;
        my @counts = @counts_list[11 .. $len-1];
        my $transcript_name = $counts_list[3];
        
        my $sum = 0;
        for my $num(@counts) {

            $sum = $sum + $num;
            
        }
        $transcript_counts{$transcript_name} = $sum;
    }
close($count);


my $gffh;
my $gff_file = $gff_file; 
open($gffh, "gunzip -c $gff_file |") || die "can't open pipe to $gff_file";
my $gffio = Bio::Tools::GFF->new(-fh => $gffh, -gff_version => 3);

open(my $output, ">$gffOut");
my $gffOutput = Bio::Tools::GFF->new(-fh => $output, -gff_version => 3);
while(my $feature = $gffio->next_feature()) {
        my $primary = $feature->primary_tag();
        if ($primary eq "transcript") {
            my ($id) = $feature->get_tag_values("ID");
            $feature->add_tag_value('totalCount', $transcript_counts{$id});
            $gffOutput->write_feature($feature);
            
        }  else {
            $gffOutput->write_feature($feature);
        }   
    }



close($output);

my $newName = "mv $gffOut Temp.gff";
my $sortGff = "sort -k1,1 -k4,4n Temp.gff > $gffOut";  
my $gffZip = "bgzip -f $gffOut";
my $tabix = "tabix -p gff $gffOut.gz";

&runCmd($newName);
&runCmd($sortGff);
&runCmd($gffZip);
&runCmd($tabix);
unlink('$gffOut.gz');

sub usage {
die "updateLongReadGtf.pl --gffFile=FILE --countFile=FILE --outputGFF=FILE\n";
}
1;
