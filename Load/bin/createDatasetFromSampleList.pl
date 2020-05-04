#!/usr/bin/perl

use strict;
use Cwd;

my $usage =<<EOL;
MUST run this script under manual delivery workSpace directory! e.g /eupath/data/EuPathDB/manualDelivery/TriTrypDB/tbruTREU927/SNP/Weir_Population_
Genomics/2013-05-21/workSpace

This script creates dataset xml and manual delivery files for HTS_SNPs from SRA.

%>createDatasetFromSampleList.pl file_with_sample_name_run_ids-

Output will be dataset xml and empty sample files under manual delivery file dir (HTS SNPs only)
EOL

my $file = shift or die $usage;
my @dir = split /\//, getcwd;
my $project = $dir[5];
my $org     = $dir[6];
my $dataType = $dir[7];
my $exp     = $dir[8];
my $version = $dir[9];

open O1, ">$exp.xml";
print O1 "<datasets>\n";

if($dataType=~/rnaSeq/){
open O2, ">../final/analysisConfig.xml";
print O2 <<EOL;
<xml>
  <globalReferencable>
    <property name="profileSetName" value="TODO"/>   
    <property name="samples">
EOL
}
open S, $file;

while(<S>) {
  chomp;
  my ($sample, $run_id) = split /\|/, $_;

if($dataType=~/rnaSeq/){
print O1 <<EOL;
  <dataset class="rnaSeqSample_QuerySRA">
    <prop name="organismAbbrev">$org</prop>
    <prop name="experimentName">$exp</prop>
    <prop name="sampleName">$run_id</prop>
    <prop name="sraQueryString">$run_id</prop>
  </dataset>
EOL

print O2 <<EOL;
      <value>$sample|$run_id</value>
EOL
}elsif($dataType=~/SNP/){
print O1 <<EOL;
  <dataset class="SNPs_HTS_Sample_QuerySRA">
    <prop name="organismAbbrev">$org</prop>
    <prop name="experimentName">$exp</prop>
    <prop name="snpStrainAbbrev">$sample</prop>
    <prop name="sraQueryString">$run_id</prop>
  </dataset>

EOL

#unless ($project =~/FungiDB/) {
print O1 <<EOL;
  <dataset class="copyNumberVariationSamples">
    <prop name="projectName">$project</prop>
    <prop name="organismAbbrev">$org</prop>
    <prop name="experimentName">$exp</prop>
    <prop name="experimentVersion">$version</prop>
    <prop name="sampleName">$sample</prop>
  </dataset>

EOL
#}

system("touch ../final/$sample");
system("touch ../final/$sample.paired");
system("touch ../final/$sample.qual");
system("touch ../final/$sample.qual.paired");
}elsif($dataType=~/chipSeq/){
print O1 <<EOL;
  <dataset class="chipSeqSample">
    <prop name="organismAbbrev">$org</prop>
    <prop name="experimentName">$exp</prop>
    <prop name="sampleName">$sample</prop>
    <prop name="inputName">TODO</prop>
    <prop name="fragmentLength"></prop>
  </dataset>
EOL
}
}

print O1 "</datasets>\n";
if($dataType=~/rnaSeq/){
print O2 <<EOL;
</property>
  </globalReferencable>

  <step class="ApiCommonData::Load::RnaSeqAnalysis">
    <property name="profileSetName" isReference="1" value="\$globalReferencable->{profileSetName}" />
    <property name="samples" isReference="1" value="\$globalReferencable->{samples}" />
    <property name="isStrandSpecific" value="TODO"/>
  </step>
</xml>
EOL
}
