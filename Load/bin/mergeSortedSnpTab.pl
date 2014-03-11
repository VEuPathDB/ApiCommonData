#!/usr/bin/perl

use strict;
use Getopt::Long;
use ApiCommonData::Load::MergeSortedSeqVariations;

my ($inputFile, $cacheFile, $undoneStrainsFile);

&GetOptions("inputFile=s"=> \$inputFile,
            "cacheFile=s" => \$cacheFile,
            "undoneStrainsFile=s" => \$undoneStrainsFile,
    );

unless(-e $inputFile) {
  print STDERR "usage: perl --inputFile <FILE> --cacheFile <FILE> --undoneStrainsFile <FILE>\n";
  exit(0);
}

unless(-e $cacheFile) {
  open(FILE, "> $cacheFile") or die "Could not open file $cacheFile for writing: $!";
  close FILE;
}

unless(-e $undoneStrainsFile) {
  open(FILE, "> $undoneStrainsFile") or die "Could not open file $undoneStrainsFile for writing: $!";
  close FILE;
}


my $cacheTmp = "$cacheFile.tmp";
rename $cacheFile, $cacheTmp;

open(OUT, "> $cacheFile") or die "Cannot open output file $cacheFile for writing: $!";


open(UNDONE, $undoneStrainsFile) or die "Cannot open file $undoneStrainsFile for reading: $!";
my @filters =  map { chomp; $_ } <UNDONE>;
close UNDONE;


my $reader = ApiCommonData::Load::MergeSortedSeqVariations->new($inputFile, $cacheTmp, \@filters, qr/\t/);

  
while($reader->hasNext()) {
  print OUT $reader->nextLine() . "\n";
}

close OUT;

unlink $cacheTmp;

open(TRUNCATE, ">$inputFile") or die "Cannot open file $inputFile for writing: $!";
close(TRUNCATE);

1;
