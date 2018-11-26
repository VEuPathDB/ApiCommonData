#!/usr/bin/perl

use strict;
use Getopt::Long;
use Cwd;

my ($file, $profile, $strand);

&GetOptions( 'sample_file=s'        => \$file, 
             'profileset_name=s'    => \$profile,
             'is_strand_specific=s' => \$strand );

unless($file, $profile) {
  print <<EOL;

This script creates dataset xml and analsysiConfig.xml for rnaSeq from sample list, for instance,

%>createRNASeqDatasetFromTabFile.pl --sample_file sample_file --profileset_name "M mulatta infected with P cynomolgi over 100 days" --is_strand_specific yes|no

Sample file has the following format

Human blood 69|ERR2619094
Human blood 71|ERR2619095

EOL
}

my @dir = split /\//, getcwd;
my $project = $dir[5];
my $org     = $dir[6];
my $exp     = $dir[8];
my $version = $dir[9];

if ($strand =~ /yes/i) {
  $strand = 1;
} else {
  $strand = 0;
} 

open O1, ">$exp.xml";
open O2, ">analysisConfig.xml";

print O1 "<datasets>\n";
print O2 <<EOL;
<xml>
  <globalReferencable>
    <property name="profileSetName" value="$profile"/>   
    <property name="samples">
EOL

open F, $file;
while(<F>) {
  chomp;
  next if /^#/;
  my ($samples, $run) = split /\|/, $_;
  my @runs = split /,/, $run;

print O1 <<EOL;
  <dataset class="rnaSeqSample_QuerySRA">
    <prop name="organismAbbrev">$org</prop>
    <prop name="experimentName">$exp</prop>
    <prop name="sampleName">$runs[0]</prop>
    <prop name="sraQueryString">$run</prop>
  </dataset>

EOL

print O2 <<EOL;
      <value>$samples|$runs[0]</value>
EOL
}


print O1 "</datasets>\n";
print O2 <<EOL;
    </property>
  </globalReferencable>

  <step class="ApiCommonData::Load::RnaSeqAnalysis">
    <property name="profileSetName" isReference="1" value="\$globalReferencable->{profileSetName}" />
    <property name="samples" isReference="1" value="\$globalReferencable->{samples}" />
    <property name="isStrandSpecific" value="$strand"/>
  </step>
</xml>

EOL
