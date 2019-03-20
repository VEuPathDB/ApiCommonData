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

my %hshAbbrevs; 

for my $a (split(/\,/,$abbrevs)){
  $hshAbbrevs{$a}=1;
}

while(<IN>){
  my $line = $_;

  if ($line =~ /^>(\w+)\|/) {
    my $ab = $1;
    $line =~ s/^>(\w+)\|/>${ab}xx\|/ if ($hshAbbrevs{$ab} == 1);
    print OUT "$line";
  }
  else {
    print OUT "$line";
  }
}
