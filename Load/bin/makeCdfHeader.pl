#!/usr/bin/perl

use strict;

if(@ARGV< 4) {
	die "
Builds the header for a generated cdf file for affy arrays

Usage: makeCdfHeader.pl <outputFileName> <gene2probes> <name> <numRows> <numCols>

Where:
       <outputFileName> is the path to the file that you want to make into a cdf file.
       Please note this script overwrites this file if it exist, otherwise the file is
       created. Please note that the file name must match the cel files.

       <gene2probes> is the file mapping genes to probes, with gene id followed by
       a tab delimited list of all probe ids mapping to that gene. Used to find the 
       NumberOfUnits and MaxUnits fields.

       <name> the value to use in the Name field of the header. This is usually the name of
       the cdf file, without the suffix.

       <numRows> the value to use in the Rows field of the header.

       <numCols> the value to use in the Cols field of the header.";
	}

my ($outputFile, $probeFile, $name, $row, $col) = @ARGV;
open(FILE, "< $probeFile") or die "can't open $probeFile: $!";
my $unit = 1;
$unit++ while <FILE>;
close FILE;
$name =~s/\.\w*$//;
open (OUTFILE, "> $outputFile") or die "can't open $probeFile: $!";
print OUTFILE "[CDF]\nVersion=GC3.0\n\n";
print OUTFILE "[Chip]\n";
print OUTFILE "Name=$name\n";
print OUTFILE "Rows=$row\n";
print OUTFILE "Cols=$col\n";
print OUTFILE "NumberOfUnits=$unit\n";
print OUTFILE "MaxUnits=$unit\n";
print OUTFILE "NumQCUnits=0\n";
print OUTFILE "ChipReference=\n\n";
close OUTFILE;
