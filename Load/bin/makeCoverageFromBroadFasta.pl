#!/usr/bin/perl

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
