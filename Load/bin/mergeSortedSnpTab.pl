#!/usr/bin/perl

use strict;
use Getopt::Long;
use ApiCommonData::Load::MergeSortedSeqVariations;


my ($file1, $file2, $outputFile);

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

my $merger = ApiCommonData::Load::MergeSortedSeqVariations->new($file1, $file2, $filters, qr/\t/);

while($merger->hasNext()) {
  print OUT $merger->nextLine() . "\n";
}

close OUT;

