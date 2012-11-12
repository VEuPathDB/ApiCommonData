#!/usr/bin/perl

use strict;
use Getopt::Long;
use CBIL::Util::Utils;
use lib "$ENV{GUS_HOME}/lib/perl";

# this script loops through each sample output directory and copy normalized bedgraph files to webService Dir. 

#  ... Su_strand_specific/analyze_lateTroph/master/mainresult/normalized
#  ... Su_strand_specific/analyze_schizont/master/mainresult/normalized
#  ... Su_strand_specific/analyze_gametocyteII/master/mainresult/normalized
#  ... Su_strand_specific/analyze_gametocyteV/master/mainresult/normalized

my ($inputDir, $outputDir); 

&GetOptions("inputDir=s"  => \$inputDir,
            "outputDir=s" => \$outputDir
           );

my $usage =<<endOfUsage;
Usage:
  copyNormalizedBedGraphToWebServiceDir.pl --inputDir input_diretory --outputDir output_directory 

    intpuDir:top level directory, e.g. /eupath/data/EuPathDB/workflows/PlasmoDB/bigwig/data/pfal3D7/organismSpecificTopLevel/Su_strand_specific
    outputDir:e.g. /eupath/data/apiSiteFilesStaging/PlasmoDB/htsSNPTest_2/real/webServices/PlasmoDB/release-htsSNPTest_2/Pfalciparum3D7/bigwig/Su_strand_specific/
endOfUsage

die $usage unless -e $inputDir;
die $usage unless -e $outputDir;

opendir(DIR, $inputDir);
my @ds = readdir(DIR);

foreach my $d (@ds) {
  next unless $d =~ /^analyze_(\S+)/;
  $inputDir =~ s/\/$//;
  my $exp_dir = "$inputDir/$d/master/mainresult/normalized/final";
  $outputDir = $outputDir."/$1"; 
  system ("mkdir $outputDir");
  my $status = $? >>8;
  die "Error.  Failed making $outputDir with status '$status': $!\n\n" if ($status);
  my $cmd = "cp $exp_dir/*.bw $outputDir";
  system ($cmd); 
  $status = $? >>8;
  die "Error.  Failed $cmd with status '$status': $!\n\n" if ($status);

}
