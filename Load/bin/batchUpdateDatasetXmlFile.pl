#!/usr/bin/perl

## usage: batchUpdateDatasetXmlFile.pl fileList 2025-10-30 

use strict;

my ($fileList, $version) = @ARGV;

my @files;

open (IN, $fileList) || die "can not open fileList file to read.\n";
while (<IN>) {
    chomp;
    push @files, $_;
}

foreach my $i (0..$#files) {
  my $cmd = "updateDatasetXmlFile.pl $files[$i] $version";
  `$cmd`;
  print STDERR "done $cmd\n";
}

