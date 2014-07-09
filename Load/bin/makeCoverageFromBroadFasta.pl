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

my $strain; 
my $chr;
my %st;
while(<>){
  if(/chr\s(\d+).*strain\s(.*)$/){
    $chr = $1; 
    $strain = $2;
  }else{
    chomp;
    $st{$strain}->{$chr} .= $_;
  } 
}


foreach my $str (keys%st){
  open(F,">$str.cov");
  foreach my $chrom (keys%{$st{$str}}){
    while( $st{$str}->{$chrom} =~ m/(\w+)/g){
      my $end = pos($st{$str}->{$chrom});
      my $start = pos($st{$str}->{$chrom}) - length($1) + 1;
      print F "MAL$chrom\t.\t.\t$start\t$end\t.\t.\t.\t.\n";
#      print F "MAL$chrom\t.\t.\t$start\t",(length($1) - 1),"\t.\t.\t.\t.\n";
    }
  }
  close F;
}
