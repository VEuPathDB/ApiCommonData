#!/usr/bin/perl

use strict;
use DBI;
use Getopt::Long;

my ($study, $org, $dsname);

&GetOptions( 'study=s'          => \$study,
             'orgaism_abbrev=s' => \$org,
             'dataset_name=s'   => \$dsname );

unless($study && $org && $dsname) {
  print <<EOL;

This script creates dataset xml and analsysiConfig.xml for rnaSeq and HTS_SNPs from SRA.
It takes SRA study id, organism abbreviation and dataset name as input. 
For instance,

%>createSRADataset.pl --study SRP106638 --orgaism_abbrev mmul17573 --dataset_name Galinski_Mmulatta_Infected_with_Pcynomolgi

Output will be Galinski_Mmulatta_Infected_with_Pcynomolgi.xml and analsysiConfig.xml
EOL
  exit;

}

open O1, ">$dsname.xml";
open O2, ">analysisConfig.xml";

print O1 "<datasets>\n";
print O2 <<EOL;
<xml>
  <globalReferencable>
    <property name="profileSetName" value="Profile name ??? TODO"/>   
    <property name="samples">
EOL

my $dbh = DBI->connect("dbi:SQLite:/home/hwang/projects/R_getSRA/SRAmetadb.sqlite", "", "", { RaiseError => 1 }) or die $DBI::errstr;

my $stmt = qq(select run_accession,sample_alias,sample_attribute from sra where study_accession = '$study');
my $sth  = $dbh->prepare($stmt);
my $rv   = $sth->execute or die $DBI::errstr;

if($rv < 0) {
   print $DBI::errstr;
}

while(my @row = $sth->fetchrow_array()) {
  my $run_id = $row[0];
  my $sample = $row[1];
  my $attr   = $row[2];

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
    <property name="isStrandSpecific" value="0"/>
    <property name="isPairedEnd" value="1"/>
  </step>
</xml>

EOL

$dbh->disconnect(); 
