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

my ($inputDir, $outputDir, $analysisConfig); 

&GetOptions("inputDir=s"       => \$inputDir,
                     "outputDir=s"      => \$outputDir,
                     "analysisConfig=s" => \$analysisConfig
                    );

my $usage =<<endOfUsage;
Usage:
  copyNormalizedBedGraphToWebServiceDir.pl --inputDir input_diretory --outputDir output_directory --datasetXml eupath_datset_xml

    intpuDir:top level directory, e.g. /eupath/data/EuPathDB/workflows/PlasmoDB/CURRENT/data/pfal3D7/organismSpecificTopLevel/Su_strand_specific
    outputDir: webservice directory, e.g. /eupath/data/apiSiteFilesStaging/PlasmoDB/18/real/webServices/PlasmoDB/release-CURRENT/Pfalciparum3D7/bigwig/pfal3D7_Su_strand_specific_rnaSeq_RSRC

    analysisConfig: use to track sample order and display name. Here is a sample analysis config file - 
        /eupath/data/EuPathDB/manualDelivery/PlasmoDB/pfal3D7/rnaSeq/Su_strand_specific/2011-11-16/final/analysisConfig.xml ?

    ## datasetXml: dataset xml in order to keep the order of samples e.g. EuPathDatasets/Datasets/lib/xml/datasets/PlasmoDB/pfal3D7/Su_strand_specific.xml. In this case, samples are in the order of lateTroph, schizont, gametocyteII, gametocyteV
endOfUsage

die $usage unless -e $inputDir;
die $usage unless -e $outputDir;

opendir(DIR, $inputDir);
my @ds = readdir(DIR);

my %subOrder = ( 'RUM_Unique_plus.bw'  => 1,
                 'RUM_NU_plus.bw'      => 2, 
                 'RUM_Unique_minus.bw' => 3, 
                 'RUM_NU_minus.bw'     => 4,
                 'RUM_Unique.bw'       => 1,
                 'RUM_NU.bw'           => 2,
                 'RUM_Unique_plus_unlogged.bw'  => 1,
                 'RUM_NU_plus_unlogged.bw'      => 2,
                 'RUM_Unique_minus_unlogged.bw' => 3,
                 'RUM_NU_minus_unlogged.bw'     => 4, 
                 'RUM_Unique_unlogged.bw'       => 1,
                 'RUM_NU_unlogged.bw'           => 2
                );

my %sampleOrder;
my %sampleDisplayName;
if(-e $analysisConfig) {
  open(F, $analysisConfig);
  my $count = 1;

  while(<F>) {
    chomp;
    next if /^\s+$/;
    #if( $_ =~ /<prop name="sampleName">(.*)<\/prop>/) {
    if(  /<property name="samples">/i .. /<\/property>/i  ) {
        next unless /<value>/i;
        $_ =~ /<value>(.*)<\/value>/ ;
        my($sample_display_name, $sample_internal_name) = split /\|/, $1;
        $sampleOrder{$sample_internal_name} = sprintf("%02d",$count);

        $sampleDisplayName{$sample_internal_name} = $sample_display_name;
        $count++;
    }
  }
}


# sort diretory name by the number in the string, e.g. hour2, hour10, hour20...
foreach my $d (sort @ds) {
#foreach my $d (map  { $_->[0] }
#               sort { $a->[1] <=> $b->[1] }
#               map  { [$_, $_=~/(\d+)/] } @ds) {
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
  open(METAUNLOGGED, ">>$outputDir/metadata_unlogged");
  my $meta = "";
  my $expt = "unique";
  my $strand = "forward";
  my $selected = 1;
  my $count = 0;

  opendir(D, $exp_dir);
  my @fs = readdir(D);
  # sort files in the order of RUM_Unique_plus.bw RUM_NU_plus.bw RUM_Unique_minus.bw RUM_NU_minus.bw
  # redmine refs #15678
  foreach my $f(sort { $subOrder{$a} <=> $subOrder{$b} } @fs) {
    next if $f !~ /\.bw$/;
    $count++;
    $expt = 'non-unique' if $f =~ /NU/;
    $expt = 'unique' if $f =~ /Unique/;
    $selected = 1 if $f =~ /Unique/;
    $selected = 0 if $f =~ /NU/;
    $selected = 0 if $count > 15;
    $strand = 'reverse' if $f =~ /minus/;
    $strand = 'forward' if $f =~ /plus/;

    my $order = $subOrder{$f} % 5;

    my $display_order_sample = "";

    if(-e $analysisConfig) {
      $display_order_sample = "$sampleOrder{$sample}.$order - ".  $sampleDisplayName{$sample};
    } else {
      $display_order_sample = $sample; 
    } 

    if($f =~ /minus/ || $f =~ /plus/) {
      $meta =<<EOL;
[$sample/$f]
:selected    = $selected
display_name = $display_order_sample ($expt $strand)
sample       = $sample
alignment    = $expt
strand       = $strand
type         = Coverage

EOL
   } else {
     $meta =<<EOL;
[$sample/$f]
:selected    = $selected
display_name = $display_order_sample ($expt)
sample       = $sample
alignment    = $expt
type         = Coverage

EOL
   }

   if($f !~ /unlogged/) {
     print META $meta;
   } else {
     print METAUNLOGGED $meta;
   }

  } # end foreach loop

  closedir(D);
  close(META);
  close(METAUNLOGGED);
}
