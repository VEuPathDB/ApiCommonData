#!/usr/bin/perl

use strict;
use Getopt::Long;

my ($outFile, $sampleName, $inputName, $fragmentLength);
&GetOptions("outFile=s" => \$outFile,
	    "sampleName=s" => \$sampleName,
	    "inputName=s" => \$inputName,
	    "fragmentLength=i" => \$fragmentLength
    ); 

die "USAGE: $0 --outFile <out_file> --sampleName <sample_name> --inputName <input_name> [--fragmentLength i]\n"    if (!$outFile || !$sampleName || !$inputName);

open(FILE, ">$outFile") || die "Couldn't open $outFile for writing\n";
print FILE "sampleName=$sampleName\ninputName=$inputName\nfragLength=$fragmentLength\n";
close(FILE);

