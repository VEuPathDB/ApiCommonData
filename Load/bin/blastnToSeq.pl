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

use Bio::SearchIO; 
use Getopt::Long;

my ($help, $fn, $minPercentage, $minLength);

&GetOptions('help|h' => \$help,
            'blast_result_file=s' => \$fn,
            'min_percent=i' => \$minPercentage,
            'min_length=i' => \$minLength,
           );

&usage if($help);

unless(-e $fn && $minPercentage && $minLength) {
  &usage("Arguments not specified Correctly!");
}

my $in = new Bio::SearchIO(-format => 'blast', 
                           -file   => $fn);

while( my $result = $in->next_result ) {
  while( my $blastHit = $result->next_hit ) {
    while( my $hsp = $blastHit->next_hsp ) {

      my $fracIdentical = $hsp->frac_identical();
      my $length = $hsp->length();

      my $query = $hsp->query();
      my $querySeqId = $query->seq_id();

      my $hit = $hsp->hit();
      my $hitSeqId = $hit->seq_id();

      my $strand = $hit->strand();

      my $printStrand;
      if($strand == 1) {
        $printStrand = 'forward';
      }
      elsif($strand == -1) {
        $printStrand = 'reverse';
      }
      else {
        $printStrand = 'unknown';
      }

      my $start = $hit->start();
      my $end = $hit->end();

      if($length >= $minLength && ($fracIdentical * 100) >= $minPercentage) {
        print STDERR "$querySeqId matched against $hitSeqId from $start to $end on $printStrand strand\n";
        print STDOUT "$querySeqId\t$hitSeqId\n";
      }
    }
  }
}


sub usage {
  my $m = shift;

  print "$m\n" if($m);

  print "usage perl simpleBlastParse --blast_result_file <FILE> --min_percent <int> --min_length <int>\n";
}

1;

