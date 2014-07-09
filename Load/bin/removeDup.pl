#!/usr/bin/perl -w
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

# Removes duplicate lines from a file
# Original file is overwritten, but the content order is preserved
# Usage: script filename.gff [file2.gff] [file3.gff] ...

use strict;
my (@data, %hash, $file) = ((), (), "");

if (not defined $ARGV[0]) {
	print "Usage: script filename.gff [file2.gff] [file3.gff] ...\n";
	exit -1;
}
foreach $file (@ARGV) {
	if (!open FILE, "+<$file") {
		print "Unable to open input csv file for read-write, '$file' $!\n";
		next;
	}
	while (<FILE>) {
		if (not exists $hash{$_}) {
			push @data, $_;
			$hash{$_} = 1;
		}
	}
	truncate FILE, 0;
	seek FILE, 0, 0;
	print FILE @data;
	close FILE;
	%hash = @data = ();
}
