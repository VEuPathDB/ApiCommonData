#!/usr/bin/perl

use strict;
use Tie::IxHash;
use Getopt::Long;

my ($study, $org, $dsname, $profile);
my $strand = 0;
tie my %hash, "Tie::IxHash";

&GetOptions( 'study=s'             => \$study,
             'organism_abbrev=s'   => \$org,
             'dataset_name=s'      => \$dsname,
             'profileset_name=s'   => \$profile,
             'is_strand_specific!' => \$strand );

unless($study && $org && $dsname && $profile) {
  print <<EOL;

This script creates dataset xml and analsysiConfig.xml for rnaSeq and HTS_SNPs from SRA.
It takes SRA study id, organism abbreviation and dataset name as input.  For instance,

%>createRNASeqDatasetFromSRA.pl --study SRP106638 --organism_abbrev mmul17573 --dataset_name Galinski_Mmulatta_Infected_with_Pcynomolgi --profileset_name "M mulatta infected with P cynomolgi over 100 days" --is_strand_specific 

Output will be Galinski_Mmulatta_Infected_with_Pcynomolgi.xml and analsysiConfig.xml
EOL
  exit;
}

$strand = 1 if($strand); 

open O1, ">$dsname.xml";
open O2, ">analysisConfig.xml";

print O1 "<datasets>\n";
print O2 <<EOL;
<xml>
  <globalReferencable>
    <property name="profileSetName" value="$profile"/>   
    <property name="samples">
EOL

my $cmd = "wget -O $study.runInfo.csv 'http://trace.ncbi.nlm.nih.gov/Traces/sra/sra.cgi?save=efetch&db=sra&rettype=runinfo&term=$study'";
print "$cmd\n";

system($cmd);

open INFO, "$study.runInfo.csv";

while(<INFO>) {
  my $header = $_ and next if /^Run/;
  next if /^\s+$/;
  my @arr = split /,/, $_;
  my $run_id = $arr[0];
  my $sample = $arr[29];
  push @{$hash{$sample}}, $run_id; 
}

while(my ($k, $v) = each %hash) {
  my $runs = join ',', @$v;

print O1 <<EOL;
  <dataset class="rnaSeqSample_QuerySRA">
    <prop name="organismAbbrev">$org</prop>
    <prop name="experimentName">$dsname</prop>
    <prop name="sampleName">$k</prop>
    <prop name="sraQueryString">$runs</prop>
  </dataset>

EOL

print O2 <<EOL;
      <value>$k display text|$k</value>
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
