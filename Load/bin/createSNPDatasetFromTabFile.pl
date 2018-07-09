#!/usr/bin/perl

use strict;
use DBI;
use Getopt::Long;

my ($proj, $study, $org, $exp, $version);
my $cnv = 0;
my %hash;

&GetOptions( 'project_name=s'    => \$proj,
             'study=s'           => \$study,
             'organism_abbrev=s' => \$org,
             'experiment_name=s' => \$exp,
             'version=s'         => \$version,
             'hasCNV!'           => \$cnv
           );

unless($study && $proj && $org && $exp && $version) {
  print <<EOL;

This script creates dataset xml and manual delivery files for HTS_SNPs from SRA.
It takes SRA study id, organism abbreviation and dataset name as input. 
For instance,

%>createSNPDatasetFromTabFile.pl --project_name FungiDB --study SRP145096 --organism_abbrev caurB8441 --experiment_name Experiment_Name --version Version --hasCNV

Output will be dataset xml and empty sample files under manual delivery file dir 
EOL
  exit;

}

open O1, ">$exp.xml";
print O1 "<datasets>\n";


open S, "$study.samples.txt";

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
    <prop name="projectName">$proj</prop>
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
