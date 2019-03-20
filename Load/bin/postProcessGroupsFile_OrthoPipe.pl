#! /usr/bin/perl

use strict;
use lib "$ENV{GUS_HOME}/lib/perl";
use Getopt::Long;


my ($inFile, $outFile, $abbrevs);

&GetOptions("inFile=s" => \$inFile,
            "outFile=s" => \$outFile,
            "abbrevs=s" => \$abbrevs);

die "--inFile --outFile --abbrevs (comma delimted with no spaces)" if (!$inFile || !$outFile || !$abbrevs);

open (IN, $inFile);

open (OUT, ">$outFile");

$abbrevs =~ s/\s//g;

$abbrevs =~ s/\,/\|/g;


  while(<IN>){
    chomp;
    my $line = $_;

    $line =~ s/\s($abbrevs)\|\S+//g;
    $line =~ s/xx\|/\|/g;

    print OUT "$line\n";
  }


