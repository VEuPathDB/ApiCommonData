#!/usr/bin/perl

use strict;
use Getopt::Long;
use GUS::Model::SRes::Taxon;
use GUS::Model::SRes::TaxonName;
use GUS::Supported::GusConfig;


my ($gusConfigFile, $organismListFile, $projectName, $datasetXmlFile, $ebiVersion, $ebiFtpSiteFileList, $help);

&GetOptions(
            'organismListFile=s' => \$organismListFile,
            'gusConfigFile=s' => \$gusConfigFile,
            'projectName=s' => \$projectName,
            'datasetXmlFile=s' => \$datasetXmlFile,
            'ebiVersion=s' => \$ebiVersion,
            'ebiFtpSiteFileList=s' => \$ebiFtpSiteFileList,
            'help|h' => \$help
            );

&usage() if ($help);
&usage("Missing a Required Argument") unless (defined $datasetXmlFile && $ebiVersion && $ebiFtpSiteFileList && $projectName);

$gusConfigFile = "$ENV{GUS_HOME}/config/gus.config" unless ($gusConfigFile);

my $verbose;
my $gusconfig = GUS::Supported::GusConfig->new($gusConfigFile);

my (%orgInfo, $org, @orgList);

open (IN, $ebiFtpSiteFileList) || die "can not open ebiFtpSiteFileList to read\n";
while (<IN>) {
  chomp;
  my @items = split (/\s+/, $_);
  $items[8] =~ s/\.sql\.gz$//;
  push (@orgList, $items[8]);
  print STDERR "$items[8]\n";
}
close IN;

open (XML, $datasetXmlFile) || die "can not open datasetXmlFile file to read\n";
while (<XML>) {
  if ($_ =~ /organismAbbrev\">(\S+?)</) {
    $org = $1;
  } elsif ($_ =~ /orthomclAbbrev\">(\S+?)</) {
    $orgInfo{$org}{'orthomclAbbrev'} = $1;
  } elsif ($_ =~ /ncbiTaxonId\">(\S+?)</) {
    $orgInfo{$org}{'ncbiTaxonId'} = $1;
  } elsif ($_ =~ /speciesNcbiTaxonId\">(\S+?)</) {
    $orgInfo{$org}{'speciesNcbiTaxonId'} = $1;
  } elsif ($_ =~ /organismFullName\">(.*?)</) {
    $orgInfo{$org}{'organismFullName'} = $1;
  }

}

close XML;


#foreach my $k (sort keys %orgInfo) {
foreach my $k (@orgList) {
  next if ($k eq "tgonRH" || $k eq "tgonTgCkUg2" || $k eq "tgonRH88"); ## for ToxoDB
  next if ($k eq "bdiv1802A" || $k eq "cfelWinnie");                   ## for AmoebaDB
  next if ($k eq "ehisDS4" || $k eq "ehisHM1CA" || $k eq "ehisKU48" || $k eq "ehisKU50" || $k eq "ehisMS96" || $k eq "ehisRahman"); ## for PiroplasmaDB

  print "\n";
  print "<dataset class=\"orthomclPeripheralFromEbi\">\n";
  print "  <prop name=\"projectName\">$projectName</prop>\n";
  print "  <prop name=\"ebiOrganismName\">$k</prop>\n";
  print "  <prop name=\"ebiVersion\">$ebiVersion</prop>\n";
  print "  <prop name=\"orthomclAbbrev\">$orgInfo{$k}{'orthomclAbbrev'}</prop>\n";

  ## print ncbiTaxonId
  if (length($orgInfo{$k}{'ncbiTaxonId'}) < 9) {
    print "  <prop name=\"ncbiTaxonId\">$orgInfo{$k}{'ncbiTaxonId'}</prop>\n";
  } else {
    print "  <prop name=\"ncbiTaxonId\">$orgInfo{$k}{'speciesNcbiTaxonId'}</prop>\n";
  }

  print "  <prop name=\"orthomclClade\"></prop>\n";
  print "  <prop name=\"oldAbbrevsList\"></prop>\n";
  print "  <prop name=\"organismName\">$orgInfo{$k}{'organismFullName'}</prop>\n";
  print "</dataset>\n";
}

#projectName --DONE
#ebiOrganismName -- DONE
#ebiVersion -- DONE 
#orthomclAbbrev -- DONE
#orthomclClade
#ncbiTaxonId
#oldAbbrevsList
#organismName

############

sub usage {
  die
"
A script to print a xml file for OrthoMCL 

Usage: 

where:
  --organismList: optional, comma delimited list, e.g. tgonME49, ccayNF1_C8
  --projectName: required, e.g. ToxoDB
  --ebiVersion: required, e.g. build_49
  --datasetXmlFile: required, e.g. project_home/ApiCommonDatasets/Datasets/lib/xml/datasets/ToxoDB.xml
  --ebiFtpSiteFileList: required, the file list available on EBI ftp site for the build

";
}
