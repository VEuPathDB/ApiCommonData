#!/usr/bin/perl

use lib "$ENV{GUS_HOME}/lib/perl";
use Getopt::Long;
use Data::Dumper;
use strict;

my $debug = 0;
my ($shortSeqsFile, $originalShortSeqsFile, $inputFile, $outputFile);

&GetOptions("shortSeqsFile=s" => \$shortSeqsFile,
	    "originalShortSeqsFile=s" => \$originalShortSeqsFile,
	    "inputFile=s" => \$inputFile,
	    "outputFile=s" => \$outputFile,
	    "debug!" => \$debug,
            );

unless (-e $originalShortSeqsFile && -e $inputFile){ die "You must provide valid input and shortSeqsFile files. Usage: RevertProbeSeqId --shortSeqsFile <FILE> --originalShortSeqsFile <FILE> --inputFile <FILE> --outputFile <FILE> [--debug]";}

my (%originalSeqIds, %seqIds, $idNum);

open(ORI, "$originalShortSeqsFile");

while(<ORI>){
  chomp;
  if(/\>(\S+)/){
      $idNum++;
      my $newSeqId="seq.".$idNum."a";
      $originalSeqIds{$newSeqId} = $1;
  }
}
close(ORI);


open(IN, "$inputFile");
open(OUT, ">$outputFile");

while(<IN>){
  chomp;
  my @list = split(/\t/, $_);
  $_ =~ s|$list[0]|$originalSeqIds{$list[0]}|;
  print OUT "$_\n";
}
close(IN);
close(OUT);

