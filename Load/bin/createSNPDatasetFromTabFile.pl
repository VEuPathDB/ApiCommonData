#!/usr/bin/perl

use strict;
use Cwd;

my $cnv = 1;

my $usage =<<EOL;
MUST run this script under manual delivery workSpace directory! e.g /eupath/data/EuPathDB/manualDelivery/TriTrypDB/tbruTREU927/SNP/Weir_Population_Genomics/2013-05-21/workSpace

This script creates dataset xml and manual delivery files for HTS_SNPs from SRA.

%>createSNPDatasetFromTabFile.pl file_with_sample_name_run_ids-

Output will be dataset xml and empty sample files under manual delivery file dir 
EOL

my $file = shift or die $usage;
my @dir = split /\//, getcwd;
my $project = $dir[5];
my $org     = $dir[6];
my $exp     = $dir[8];
my $version = $dir[9];

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

if($cnv) {
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
