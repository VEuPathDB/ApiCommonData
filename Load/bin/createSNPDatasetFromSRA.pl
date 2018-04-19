#!/usr/bin/perl

use strict;
use DBI;
use Getopt::Long;

my ($proj, $study, $org, $exp, $version);
my %hash;

&GetOptions( 'project_name=s'    => \$proj,
             'study=s'           => \$study,
             'organism_abbrev=s' => \$org,
             'experiment_name=s' => \$exp,
             'version=s'         => \$version,
           );

unless($study && $proj && $org && $exp && $version) {
  print <<EOL;

This script creates dataset xml and manual delivery files for HTS_SNPs from SRA.
It takes SRA study id, organism abbreviation and dataset name as input. 
For instance,

%>createSNPDatasetFromSRA.pl --project_name FungiDB --study ERP009642 --organism_abbrev afumAf293 --experiment_name Azole-Resistance_Mutations --version 2015-04-24

Output will be dataset xml and empty sample files under manual delivery file dir 
EOL
  exit;

}

open O1, ">$exp.xml";

print O1 "<datasets>\n";

my $dbh = DBI->connect("dbi:SQLite:/home/hwang/projects/R_getSRA/SRAmetadb.sqlite", "", "", { RaiseError => 1 }) or die $DBI::errstr;

my $stmt = qq(select run_accession,sample_alias,sample_attribute from sra where study_accession = '$study' order by run_accession);
my $sth  = $dbh->prepare($stmt);
my $rv   = $sth->execute or die $DBI::errstr;

if($rv < 0) {
   print $DBI::errstr;
}

while(my @row = $sth->fetchrow_array()) {
  my $run_id = $row[0];
  my $sample = $row[1];
  my $attr   = $row[2]; # mixed information, such as strain, isolate etc. can be used as sample name in analysisConfig

  $sample =~ s/\s/_/g;

print O1 <<EOL;
  <dataset class="SNPs_HTS_Sample_QuerySRA">
    <prop name="organismAbbrev">$org</prop>
    <prop name="experimentName">$exp</prop>
    <prop name="snpStrainAbbrev">$sample</prop>
    <prop name="sraQueryString">$run_id</prop>
  </dataset>

  <dataset class="copyNumberVariationSamples">
    <prop name="projectName">$proj</prop>
    <prop name="organismAbbrev">$org</prop>
    <prop name="experimentName">$exp</prop>
    <prop name="experimentVersion">$version</prop>
    <prop name="sampleName">$sample</prop>
  </dataset>

EOL

system("touch ../final/$sample");
system("touch ../final/$sample.paired");
system("touch ../final/$sample.qual");
system("touch ../final/$sample.qual.paired");

}

print O1 "</datasets>\n";


$dbh->disconnect(); 
