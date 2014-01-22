#!/usr/bin/perl

use strict;
use Getopt::Long;
use lib "$ENV{GUS_HOME}/lib/perl";
use CBIL::Util::Utils;

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

# sort diretory name by the number in the string, e.g. hour2, hour10, hour20...
#foreach my $d (sort @ds) {
foreach my $d (map  { $_->[0] }
               sort { $a->[1] <=> $b->[1] }
               map  { [$_, $_=~/(\d+)/] } @ds) {
  next unless $d =~ /^analyze_(\S+)/;
  $inputDir =~ s/\/$//;
  my $exp_dir = "$inputDir/$d/master/mainresult/normalized/final";
  my $sample = $1;
  my $output = $outputDir."/$sample"; 
  system ("mkdir $output");
  my $status = $? >>8;
  die "Error.  Failed making $outputDir with status '$status': $!\n\n" if ($status);
  my $cmd = "cp $exp_dir/*.bw $output";
  system ($cmd); 
  $status = $? >>8;
  die "Error.  Failed $cmd with status '$status': $!\n\n" if ($status);

  # create a metadata text file for better organizing gbrowse subtracks
  open(META, ">>$outputDir/metadata");
  my $meta = "";
  my $expt = "unique";
  my $strand = "forward";
  my $selected = 1;

  opendir(D, $exp_dir);
  my @fs = readdir(D);
  foreach my $f(sort @fs) {
    next if $f !~ /\.bw$/;
    $expt = 'non-unique' if $f =~ /NU/;
    $expt = 'unique' if $f =~ /Unique/;
    $selected = 1 if $f =~ /Unique/;
    $selected = 0 if $f =~ /NU/;
    $strand = 'reverse' if $f =~ /minus/;
    $strand = 'forward' if $f =~ /plus/;

    if($f =~ /minus/ || $f =~ /plus/) {
      $meta =<<EOL;
[$sample/$f]
:selected    = $selected
display_name = $sample ($expt $strand)
sample       = $sample
alignment    = $expt
strand       = $strand
type         = Coverage

EOL
   } else {
     $meta =<<EOL;
[$sample/$f]
:selected    = $selected
display_name = $sample ($expt)
sample       = $sample
alignment    = $expt
type         = Coverage

EOL
   }
   print META $meta;
  }

  closedir(D);
  close(META);
}
