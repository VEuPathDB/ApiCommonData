#!/usr/bin/perl
#vvvvvvvvvvvvvvvvvvvvvvvvv GUS4_STATUS vvvvvvvvvvvvvvvvvvvvvvvvv
  # GUS4_STATUS | SRes.OntologyTerm              | auto   | absent
  # GUS4_STATUS | SRes.SequenceOntology          | auto   | absent
  # GUS4_STATUS | Study.OntologyEntry            | auto   | absent
  # GUS4_STATUS | SRes.GOTerm                    | auto   | absent
  # GUS4_STATUS | Dots.RNAFeatureExon            | auto   | absent
  # GUS4_STATUS | RAD.SageTag                    | auto   | absent
  # GUS4_STATUS | RAD.Analysis                   | auto   | absent
  # GUS4_STATUS | ApiDB.Profile                  | auto   | absent
  # GUS4_STATUS | Study.Study                    | auto   | absent
  # GUS4_STATUS | Dots.Isolate                   | auto   | absent
  # GUS4_STATUS | DeprecatedTables               | auto   | absent
  # GUS4_STATUS | Pathway                        | auto   | absent
  # GUS4_STATUS | DoTS.SequenceVariation         | auto   | absent
  # GUS4_STATUS | RNASeq Junctions               | auto   | absent
  # GUS4_STATUS | Simple Rename                  | auto   | absent
  # GUS4_STATUS | ApiDB Tuning Gene              | auto   | absent
  # GUS4_STATUS | Rethink                        | auto   | absent
  # GUS4_STATUS | dots.gene                      | manual | unreviewed
die 'This file has broken or unreviewed GUS4_STATUS rules.  Please remove this line when all are fixed or absent';
#^^^^^^^^^^^^^^^^^^^^^^^^^ End GUS4_STATUS ^^^^^^^^^^^^^^^^^^^^

use lib "$ENV{GUS_HOME}/lib/perl";

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

open(TRUNCATE, ">$undoneStrainsFile") or die "Cannot open file $undoneStrainsFile for writing: $!";
close(TRUNCATE);


1;
