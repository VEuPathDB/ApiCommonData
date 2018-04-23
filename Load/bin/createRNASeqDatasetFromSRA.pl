#!/usr/bin/perl

use strict;
use DBI;
use Getopt::Long;

my ($study, $org, $dsname, $profile);
my $strand = 0;
my %hash;

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

print O1 <<EOL;
  <dataset class="rnaSeqSample_QuerySRA">
    <prop name="organismAbbrev">$org</prop>
    <prop name="experimentName">$dsname</prop>
    <prop name="sampleName">$run_id</prop>
    <prop name="sraQueryString">$run_id</prop>
  </dataset>
EOL

print O2 <<EOL;
      <value>$sample|$run_id</value>
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

$dbh->disconnect(); 
