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

# Brian Brunk 9/02/97

use strict;
use lib "$ENV{GUS_HOME}/lib/perl";
use Getopt::Long;

my($reverse,$outputFile,$inputFile,$minPloyALength,$help);

&GetOptions("help|h" => \$help,
            "inputFile=s" => \$inputFile,
            "outputFile=s" => \$outputFile,
	    "reverse!" => \$reverse,
            "minPolyALength=s" => \$minPloyALength);

&usage() if($help);
&usage("FASTQ file is required") unless(-e $inputFile);
&usage("There is an output file") if (-e $outputFile);

my $forSeq = 'AAAAAAAA';
my $revSeq = 'TTTTTTTT';
print STDERR "Note: not reverse complementing sequences\n" if $reverse;
open (IN, "$inputFile") or die "Cannot open file for reading:  $!";
open(OUT, "> $outputFile") or die "Cannot open file for writing:  $!";

my $id;
while(<IN>){
    if(/^@(.*)/){
	$id=$1;
    }
    if($reverse){
	if(/($revSeq+)(.*)$/){
	    print OUT ">$id\n$2\n" if (length($2) >= $minPloyALength and $2!~ m/N/);
	}
    }else{
	if(/(\S*?)($forSeq+)$/){
	    print OUT ">$id\n$1\n" if (length($1) >= $minPloyALength and $1!~ m/N/);
	}
    }
}



sub usage {
  my ($m) = @_;

  print STDERR "ERROR:  $m\n" if($m);

  print STDERR "usage: findPloyASites.pl --inputFile FASTQ --outputFile FASTA --minPloyALength 14  [--reverse]\n";

  exit;
}
