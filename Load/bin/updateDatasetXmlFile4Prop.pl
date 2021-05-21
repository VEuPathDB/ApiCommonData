#!/usr/bin/perl

use strict;
use Getopt::Long;
use GUS::Model::SRes::Taxon;
use GUS::Model::SRes::TaxonName;
use GUS::Supported::GusConfig;
use Data::Dumper;
use JSON;


my ($inputDatasetXmlFile, $className, $propName, $replaceValue, $help);

&GetOptions(
            'inputDatasetXmlFile=s' => \$inputDatasetXmlFile,
            'className=s' => \$className,
            'propName=s' => \$propName,
            'replaceValue=s' => \$replaceValue,
            'help|h' => \$help
            );

&usage() if ($help);
&usage("Missing a Required Argument") unless (defined $inputDatasetXmlFile && $propName);

my $outFile = $inputDatasetXmlFile . ".updated";
open (OUT, ">$outFile") || die "can not open $outFile to write\n";

my $inClass = 0;
open (IN, "$inputDatasetXmlFile") || die "can not open $inputDatasetXmlFile to read\n";
while (<IN>) {
  chomp;

  if ($_ =~ /<dataset class=\"$className\">/) {
    $inClass = 1;
  } elsif ($_ =~ /<\/dataset>/) {
    $inClass = 0;
  }

  if ($_ =~ /<prop name=\"$propName\">/ && $inClass == 1) {
    $_ =~ s/>(\S+?)</>$replaceValue</;
  }

  print OUT "$_\n";
}
close IN;
close OUT;

print STDERR "done replacement of $inputDatasetXmlFile\n";

my $cmd = "mv $outFile $inputDatasetXmlFile";
`$cmd`;




############

sub usage {
  die
"
A script to update a specific prop in dataset xml file

Usage: perl updateDatasetXmlFile4Prop.pl --inputDatasetXmlFile tcruG.xml --className ebi_primary_genome --propName ebi2gusTag --replaceValue 102

where:
  --inputDatasetXmlFile: required, the dataset xml file that want to update, e.g. tgonME49.xml
  --className: optional, e.g. productNames
  --propName: required, the name of prop that want to update, e.g. genomeVersion
  --replaceValue: the new value that want to put in dataset xml file, e.g. 2021-02-01

";
}
