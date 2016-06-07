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
  # GUS4_STATUS | dots.gene                      | manual | absent
#^^^^^^^^^^^^^^^^^^^^^^^^^ End GUS4_STATUS ^^^^^^^^^^^^^^^^^^^^
#Writes unmapped reads from a bamfile to a fastq file
###########################################################
use strict;
use warnings;

use Getopt::Long;


my $bamFileName;
my $outFileName;

&GetOptions(
            "bamFileName|n=s" => \$bamFileName,
            "outFileName|o=s" => \$outFileName
            );


if (! -e $bamFileName){
    die <<endOfUsage;
        removeMappedReads.pl usage:
        removeMappedReads.pl --bamFileName|-n <path to BAM file from which to extract unmapped reads> --outFileName|-o <path to fastq output file>
endOfUsage
}

open(IDS, "samtools view -f 4 $bamFileName | cut -f 1,10,11|") or die "Cannot run samtools command on $bamFileName: $!";

open(OUT, ">$outFileName") or die "Cannot open output file $outFileName for writing\n$!\n";

while (<IDS>) {
  chomp;
  my ($id, $seq, $qual) = split(/\t/, $_);
  print OUT "\@$id\n$seq\n+\n$qual\n";
}
close IDS;
close OUT;
