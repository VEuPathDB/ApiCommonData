#!/usr/bin/perl

use strict;
use Getopt::Long;

use ApiCommonData::Load::MergeSortedFiles;

my ($file1, $file2, $outputFile);

my $sequenceIndex = 0;
my $locationIndex = 1;

&GetOptions("file_1=s"=> \$file1,
            "file_2=s" => \$file2,
            "output_file=s" => \$outputFile,
    );

unless(-e $file1 && -e $file2) {
  print STDERR "usage: perl --file1 <FILE> --file2 <FILE>\n";
  exit;
}

open(OUT, "> $outputFile") or die "Cannot open output file $outputFile for writing: $!";

my $filters = [];

my $merger = ApiCommonData::Load::MergeSortedFiles::SeqVarCache->new($file1, $file2, $filters);

while($merger->hasNext()) {
  print OUT $merger->nextLine() . "\n";
}

close OUT;

