#!/usr/bin/perl 

use strict; 
use lib "$ENV{GUS_HOME}/lib/perl";
use CBIL::Util::Sra;

my $ct = 0;
foreach my $sampleId (@ARGV){
  $ct++;
  my @tmp;
  foreach my $s (split(/,\s*/,$sampleId)){
    push(@tmp,$s);
  }
  &getFastqForSampleIds(\@tmp,"readsFor$ct.fastq","readsRev$ct.fastq",1);
}
