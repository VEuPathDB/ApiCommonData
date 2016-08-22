#!/usr/bin/perl

use strict;

use lib "$ENV{GUS_HOME}/lib/perl";
use Getopt::Long;
use ApiCommonData::Load::SnpUtils  qw(variationFileColumnNames);
use Data::Dumper;

my ($inputFile, $outputFile, $strainSuffix, $referenceStrain, $doNotOutputReference);

&GetOptions("inputFile=s"=> \$inputFile,
            "outputFile=s" => \$outputFile,
            "suffix=s" => \$strainSuffix,
	    "referenceStrain=s" => \$referenceStrain,
	    "doNotOutputReference" => \$doNotOutputReference,

    );

unless(-e $inputFile && $outputFile && $strainSuffix) {
  print STDERR "usage: perl snpAddStrianSuffixToVariations.pl --inputFile <IN> --outputFile <OUT> --suffix=s\n";
  exit;
}

my @variationFileColumnNames = variationFileColumnNames();

open(FILE, $inputFile) or die "Cannot open file $inputFile for reading: $!";
open(OUT, "> $outputFile") or die "Cannot open file $outputFile for writing: $!";

while(<FILE>) {
  chomp;

  my @values = split(/\t/, $_);
  my %hash; @hash{@variationFileColumnNames} = @values;

  $hash{strain} = $hash{strain} . $strainSuffix unless($hash{strain} eq $referenceStrain);
  
  my @out = map { $hash{$_} } @variationFileColumnNames;
  print OUT join("\t", @out) . "\n" unless($hash{strain} eq $referenceStrain && $doNotOutputReference);
}

close FILE;
close OUT;

