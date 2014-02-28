#!/usr/bin/perl

use strict;
use Getopt::Long;
use ApiCommonData::Load::MergeSortedSeqVariations;

use ApiCommonData::Load::SNPSampleTabFilter;

my ($inputFile, $cacheFile, $removeStrain);

&GetOptions("inputFile=s"=> \$inputFile,
            "cacheFile=s" => \$cacheFile,
            "removeStrain=s" => \$removeStrain,
    );

unless(-e $inputFile) {
  print STDERR "usage: perl --inputFile <FILE> --cacheFile <FILE> [removeStrain]\n";
  exit(0);
}

unless(-e $cacheFile) {
  die "Trying to remove strain $removeStrain strain BUT the cache does not exist" if($removeStrain);
  open(FILE, "> $cacheFile") or die "Could not open file $cacheFile for writing: $!";
  close FILE;
}

my $cacheTmp = "$cacheFile.tmp";
rename $cacheFile, $cacheTmp;

open(OUT, "> $cacheFile") or die "Cannot open output file $cacheFile for writing: $!";

my $filters = [];
my $reader;

if($removeStrain) {
  $filters = ["$removeStrain"];
  $reader = ApiCommonData::Load::SNPSampleTabFilter->new($cacheTmp, $filters, qr/\t/);
}
else {
  $reader = ApiCommonData::Load::MergeSortedSeqVariations->new($inputFile, $cacheTmp, $filters, qr/\t/);
}

while($reader->hasNext()) {
  print OUT $reader->nextLine() . "\n";
}

close OUT;

unlink $cacheTmp;

