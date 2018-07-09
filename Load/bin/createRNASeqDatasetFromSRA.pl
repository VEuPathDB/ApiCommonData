#!/usr/bin/perl

use strict;
use Tie::IxHash;
use Getopt::Long;

my ($study, $org, $dsname, $profile);
my $strand = 0;
my %library;
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
  my $lib    = $arr[11];
  my $sample = $arr[24];
  $library{$sample} = $lib;
  push @{$hash{$sample}}, $run_id; 
}

while(my ($k, $v) = each %hash) {
  my $runs = join ',', @$v;
  my $sampleName = $v->[0];

print O1 <<EOL;
  <dataset class="rnaSeqSample_QuerySRA">
    <prop name="organismAbbrev">$org</prop>
    <prop name="experimentName">$dsname</prop>
    <prop name="sampleName">$sampleName</prop>
    <prop name="sraQueryString">$runs</prop>
  </dataset>

EOL

  my $display = &getSampleInfo($k);

print O2 <<EOL;
      <value>$display|$sampleName</value>
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

sub getSampleInfo {
  my $sample_id = shift;

  my $cmd = "wget -O $sample_id.tmp 'https://www.ncbi.nlm.nih.gov/biosample/$sample_id?report=full&format=text'";
  system($cmd);
  
   $sample_id .= " $library{$sample_id}";

  open S, "$sample_id.tmp";
  while(<S>) {
    chomp;
    next unless /^\s+\//;
    my ($attr, $val) = split /=/, $_;
    $val =~ s/"//g;
    if($attr =~ /strain/ || $attr =~ /host/ || $attr =~ /individual/) {
      $sample_id .= " $val";
    }
  }
  return $sample_id;
}
