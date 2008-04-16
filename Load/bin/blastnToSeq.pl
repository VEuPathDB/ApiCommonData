#!/usr/bin/perl

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

