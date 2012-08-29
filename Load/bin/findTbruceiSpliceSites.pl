#!/usr/bin/perl

# Brian Brunk 9/02/97

use strict;
use lib "$ENV{GUS_HOME}/lib/perl";
use Getopt::Long;

my($reverse,$outputFile,$inputFile,$minSpliceLeaderLength,$help);

&GetOptions("help|h" => \$help,
            "inputFile=s" => \$inputFile,
            "outputFile=s" => \$outputFile,
	    "reverse!" => \$reverse,
            "minSpliceLeaderLength=s" => \$minSpliceLeaderLength);

&usage() if($help);
&usage("FASTQ file is required") unless(-e $inputFile);
&usage("There is an output file") if (-e $outputFile);

my $forSeq = 'TTCTGTACTATATTG';
my $revSeq = 'CAATATAGTACAGAA';

open (IN, "$inputFile") or die "Cannot open file for reading:  $!";
open(OUT, "> $outputFile") or die "Cannot open file for writing:  $!";

my $id;
while(<IN>){
    if(/^@(.*)/){
	$id=$1;
    }
    if($reverse){
	if(/^(.*)$revSeq/){
	    print OUT ">$id\n$1\n" if (length($1) >= $minSpliceLeaderLength and $1!~ m/N/);
	}
    }else{
	if(/$forSeq(.*)/){
	    print OUT ">$id\n$1\n" if (length($1) >= $minSpliceLeaderLength and $1!~ m/N/);
	}
    }
}



sub usage {
  my ($m) = @_;

  print STDERR "ERROR:  $m\n" if($m);

  print STDERR "usage: findTbruceiSpliceSites.pl --inputFile FASTQ --outputFile FASTA --minSpliceLeaderLength 14  [--reverse]\n";

  exit;
}
