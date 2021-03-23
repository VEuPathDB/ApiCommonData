#!/usr/bin/perl

use strict;
use Cwd;
use Getopt::Long;

my ($file, $cnv, $paired);

&GetOptions( 'sample_file=s'    => \$file, 
             'has_paired_ends!' => \$paired,
             'has_cnv!'         => \$cnv );

my $usage =<<EOL;
run this script under the manual delivery workSpace directory! e.g /eupath/data/EuPathDB/manualDelivery/TriTrypDB/tbruTREU927/SNP/Weir_Population_Genomics/2013-05-21/workSpace

This script creates dataset xml and manual delivery files for HTS_SNPs from SRA.

%>createSNPDatasetFromTabFile.pl --sample_file sampleList.txt --has_paired_end --has_cnv

EOL

unless ($file) {print $usage}; 

my @dir = split /\//, getcwd;
my ($project, $org, $type, $exp, $version, $ws) = @dir[ $#dir - 5.. $#dir -1];

$paired = $paired ? 'true' : 'false'; 
$cnv = $cnv ? 'true' : 'false'; 

open O1, ">$exp.xml";
print O1 "<datasets>\n";

open S, $file;

while(<S>) {
  chomp;
  my ($sample, $run_id) = split /\|/, $_;

print O1 <<EOL;
  <dataset class="SNPs_HTS_Sample_QuerySRA">
    <prop name="organismAbbrev">$org</prop>
    <prop name="experimentName">$exp</prop>
    <prop name="snpStrainAbbrev">$sample</prop>
    <prop name="sraQueryString">$run_id</prop>
  </dataset>

EOL

if($cnv eq 'true') {
print O1 <<EOL;
  <dataset class="copyNumberVariationSamples">
    <prop name="projectName">$project</prop>
    <prop name="organismAbbrev">$org</prop>
    <prop name="experimentName">$exp</prop>
    <prop name="experimentVersion">$version</prop>
    <prop name="sampleName">$sample</prop>
  </dataset>

EOL
}

system("touch ../final/$sample");
system("touch ../final/$sample.paired");
system("touch ../final/$sample.qual");
system("touch ../final/$sample.qual.paired");

}

print O1 "</datasets>\n";


open O2, ">dataset.xml";

print O2 <<EOL;
  <dataset class="SNPs_HTS_Experiment">
    <prop name="projectName">\$\$projectName\$\$</prop>
    <prop name="organismAbbrev">\$\$organismAbbrev\$\$</prop>
    <prop name="name">$exp</prop>
    <prop name="version">$version</prop>
    <prop name="hasPairedEnds">$paired</prop>
    <prop name="isColorspace">false</prop>
    <prop name="snpPercentCutoff">20</prop>
  </dataset>

EOL

if($cnv eq 'true') {
print O2 <<EOL;
  <dataset class="copyNumberVariationExperiment">
    <prop name="projectName">\$\$projectName\$\$</prop>
    <prop name="organismAbbrev">\$\$organismAbbrev\$\$</prop>
    <prop name="experimentName">$exp</prop>
    <prop name="experimentVersion">$version</prop>
    <prop name="ploidy">2</prop>
  </dataset>
EOL

}
