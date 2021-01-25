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
&usage("Missing a Required Argument") unless (defined $inputPresenterFile && $currentBuildNumber);

$gusConfigFile = "$ENV{GUS_HOME}/config/gus.config" unless ($gusConfigFile);

my $verbose;
my $gusconfig = GUS::Supported::GusConfig->new($gusConfigFile);

my (%accessions);

if ($genomeJsonDir) {
  my @orgAbbrevs = qx{ls $genomeJsonDir};
  foreach my $abbrev (@orgAbbrevs) {
    $abbrev =~ s/\n//;
    my $jsonFile = $genomeJsonDir . "\/$abbrev\/$abbrev\_genome.json";

    open (JSN, $jsonFile) || die "can not open $jsonFile to read\n";
    my $json = <JSN>;
    my $text = decode_json($json);

    $accessions{$abbrev} = $text->{assembly}->{accession};
    print STDERR "$abbrev, $text->{assembly}->{accession}\n";
    close JSN;
  }
} elsif ($genomeJsonFile) {
  my $abbrev = $genomeJsonFile;
  $abbrev =~ s/.*\/(\S+?)_genome.json$/$1/;
  print STDERR "\$abbrev = $abbrev\n";
  open (JSN, $genomeJsonFile) || die "can not open $genomeJsonFile to read\n";
  my $json = <JSN>;
  my $text = decode_json($json);
  $accessions{$abbrev} = $text->{assembly}->{accession};
  close JSN;
} else {
  print STDERR "ERROR: Either --genomeJsonDir or --genomeJsonFile are required!\n";
}


my $outputPresenterFile = $inputPresenterFile . "\.modified";
my ($abbrev, $ifPrimary, $ifHistory, $buildNumber, $annotSource, $annotVersion, $functAnnotSource, $functAnnotVersion);
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

  } elsif ($_ =~ /annotationSource="(.+?)" annotationVersion="(.+?)"/ && $ifHistory == 1) {
    $annotSource = $1;
    $annotVersion = $2;
    ## not assign ifhistory=0;
  } elsif (($_ =~ /functionalAnnotationSource="(.+)" functionalAnnotationVersion="(.+)">.+<\/history>/)) {
    $functAnnotSource = $1;
    $functAnnotVersion = $2;
    $ifHistory = 0;
  } elsif ($_ =~ /<primaryContactId>/ && $ifPrimary == 1 && $buildNumber < $currentBuildNumber && $accessions{$abbrev}) {
    #print OUT INSDC accession
    print OUT "    <history buildNumber=\"$currentBuildNumber\"\n";
    print OUT "            genomeSource=\"GenBank\" genomeVersion=\"$accessions{$abbrev}\"\n";
    if ($functAnnotSource && $functAnnotVersion) {
      print OUT "            annotationSource=\"$annotSource\" annotationVersion=\"$annotVersion\"\n";
      print OUT "            functionalAnnotationSource=\"$functAnnotSource\" functionalAnnotationVersion=\"$functAnnotVersion\">rebuild with INSDC accession added<\/history>\n";
    } else {
      print OUT "            annotationSource=\"$annotSource\" annotationVersion=\"$annotVersion\">rebuild with INSDC accession added<\/history>\n";
    }
    $annotSource = "";
    $annotVersion = "";
    $functAnnotSource = "";
    $functAnnotVersion = "";

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

Usage: addHistoryWInsdcAccession2Presenter.pl --inputPresenterFile GiardiaDB.xml --currentBuildNumber 52 --genomeJsonDir \$genomeJsonFileDir/GiardiaDB_2020-09-22

where:
  --inputPresenterFile: required, e.g. ToxoDB.xml
  --currentBuildNumber: required, e.g. 51
  --genomeJsonFile: either genomeJsonFile or genomeJsonDir are required, e.g. \$genomeJsonFileDir/GiardiaDB_2020-09-22/gassAWB/gassAWB_genome.json
  --genomeJsonDir:  either genomeJsonFile or genomeJsonDir are required, e.g. \$genomeJsonFileDir/GiardiaDB_2020-09-22/

";
}
