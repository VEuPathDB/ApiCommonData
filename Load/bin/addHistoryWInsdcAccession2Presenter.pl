#!/usr/bin/perl

use strict;
use Getopt::Long;
use GUS::Model::SRes::Taxon;
use GUS::Model::SRes::TaxonName;
use GUS::Supported::GusConfig;
use Data::Dumper;
use JSON;


my ($inputPresenterFile, $genomeJsonFile, $genomeJsonDir, $currentBuildNumber, $gusConfigFile, $help);

&GetOptions(
            'inputPresenterFile=s' => \$inputPresenterFile,
            'genomeJsonFile=s' => \$genomeJsonFile,
            'genomeJsonDir=s' => \$genomeJsonDir,
            'currentBuildNumber=s' => \$currentBuildNumber,
            'gusConfigFile=s' => \$gusConfigFile,
            'help|h' => \$help
            );

&usage() if ($help);
&usage("Missing a Required Argument") unless (defined $inputPresenterFile && $genomeJsonFile && $currentBuildNumber);

$gusConfigFile = "$ENV{GUS_HOME}/config/gus.config" unless ($gusConfigFile);

my $verbose;
my $gusconfig = GUS::Supported::GusConfig->new($gusConfigFile);

my (%accessions, @orgAbbrevs);

@orgAbbrevs = qx{ls $genomeJsonDir};
foreach my $abbrev (@orgAbbrevs) {
  $abbrev =~ s/\n//;
  my $jsonFile = $genomeJsonDir . "\/$abbrev\/$abbrev\_genome.json";
#  print STDERR "$jsonFile\n";

  open (JSN, $jsonFile) || die "can not open $jsonFile to read\n";
  my $json = <JSN>;
  my $text = decode_json($json);

  $accessions{$abbrev} = $text->{assembly}->{accession};

  print STDERR "$abbrev, $text->{assembly}->{accession}\n";

}


my $outputPresenterFile = $inputPresenterFile . "\.modified";
my ($abbrev, $ifPrimary, $ifHistory, $buildNumber, $annotSource, $annotVersion);
open (OUT, ">$outputPresenterFile") || die "can not open $outputPresenterFile file to write\n";
open (PF, $inputPresenterFile) || die "can not open $inputPresenterFile file to read\n";
while (<PF>) {

  if ($_ =~ /<datasetPresenter name="(\S+?)_primary_genome_RSRC"/) {
    $abbrev = $1;
    $ifPrimary = 1;
  } elsif ($_ =~ /<history buildNumber="(\d+?)"/) {
    $buildNumber = $1;
    $ifHistory = 1;
  } elsif (($_ =~ /annotationSource="(.+)" annotationVersion="(.+)"\/>/ || $_ =~ /annotationSource="(.+)" annotationVersion="(.+)">.+<\/history>/) && $ifHistory == 1) {
    $annotSource = $1;
    $annotVersion = $2;
    $ifHistory = 0;
  } elsif ($_ =~ /<primaryContactId>/ && $ifPrimary == 1 && $buildNumber < $currentBuildNumber && $accessions{$abbrev}) {
    #print OUT INSDC accession
    print OUT "    <history buildNumber=\"$currentBuildNumber\"\n";
    print OUT "            genomeSource=\"GenBank\" genomeVersion=\"$accessions{$abbrev}\"\n";
    print OUT "            annotationSource=\"$annotSource\" annotationVersion=\"$annotVersion\">rebuild with INSDC accession added<\/history>\n";
  } elsif ($_ =~ /<\/datasetPresenter>/) {
    $ifPrimary = 0;
    $abbrev = "";
  } else {
  }

  print OUT $_;
}

close PF;
close OUT;



############

sub usage {
  die
"
A script to add a block of codes of history, including INSDC accession to the presenter file

Usage: 

where:
  --inputPresenterFile: required, e.g. ToxoDB.xml
  --genomeJsonFile: required, e.g. 
  --currentBuildNumber: required, e.g. 51

";
}
