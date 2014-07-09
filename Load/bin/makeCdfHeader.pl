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

use strict;

use Getopt::Long;

my ($outputFilePath, $probeFile, $name, $row, $col, $minProbes);

GetOptions("outputFilePath=s" => \$outputFilePath,
           "gene2probes=s" => \$probeFile,
           "name=s" => \$name,
           "rows=i" => \$row,
           "cols=i" => \$col,
           "minProbes=i" => \$minProbes,
          ) or die "Incorrect useage : $?  - Please see below

Purpose: Builds the header for a generated cdf file for affy arrays

Usage: makeCdfHeader.pl --outputFileNam <filePath> --gene2probes <filePath>  --name <string> --rows <integer> --cols <integer> --minProbes <integer>

Where:
       -outputFileName <filePath> is the path to the file that you want to make into a cdf file.
       Please note this script overwrites this file if it exist, otherwise the file is
       created. Please note that the file name must match the cel files.

       -gene2probes <filePath> is the file mapping genes to probes, with gene id followed by
       a tab delimited list of all probe ids mapping to that gene. Used to find the 
       NumberOfUnits and MaxUnits fields.

       -name <string> the value to use in the Name field of the header. This is usually the name of
       the cdf file, without the suffix.

       -rows <integer> the value to use in the Rows field of the header.

       -cols <integer> the value to use in the Cols field of the header.

       -minProbes <integer> min number of Probes a gene must have to be included in the cdf file."
;

open(FILE, "< $probeFile") or die "can't open $probeFile for reading: $!";
my $unit = 0;
while (my $line = <FILE>) {
  my @a = split(/\t/,$line,2);
  my @probes = split(/\t/,$a[1]);
  my $numprobes = @probes;
  if($numprobes >= $minProbes) {
    $unit = $unit+1;
  }
}
close FILE;
$name =~s/\.\w*$//;
open (OUTFILE, "> $outputFilePath") or die "can't open $outputFilePath for writing: $!";
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
