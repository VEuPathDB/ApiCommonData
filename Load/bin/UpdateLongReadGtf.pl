#!/usr/bin/perl

use strict;
use lib $ENV{GUS_HOME} . "/lib/perl";
use Getopt::Long;
use ApiCommonData::Load::EBIUtils;
use CBIL::Util::Utils;
use IO::Zlib;
use File::Temp qw/ tempfile /;
use File::Copy;
use Bio::Tools::GFF;


my ($help, $count_file, $gff_file, $gtfOut); 

&GetOptions('help|h' => \$help,
            'GFF3File=s' => \$gff_file,
            'CountFile=s' => \$count_file,
            'UpdatedGffName=s' => \$gtfOut,
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


my $gffhh;
my $gff_file = $gff_file; 
open($gffhh, "gunzip -c $gff_file |") || die "can't open pipe to $gff_file";
my $gffio = Bio::Tools::GFF->new(-fh => $gffhh, -gff_version => 3);

open(my $output, ">$gtfOut");
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

my $newName = "mv $gtfOut Temp.gff";
my $sortGff = "sort -k1,1 -k4,4n Temp.gff > $gtfOut";  
my $GffZip = "bgzip -f $gtfOut";
my $tabix = "tabix -p gff $gtfOut.gz";
my $cleanUp = "rm Temp.gff";

&runCmd($newName);
&runCmd($sortGff);
&runCmd($GffZip);
&runCmd($tabix);
&runCmd($cleanUp);

sub usage {
die "UpdateLongReadGtf.pl --GFF3File=FILE --CountFile=FILE --UpdatedGffName=FILE\n";
}
1;
