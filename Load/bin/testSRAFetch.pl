#!/usr/bin/perl 

use strict; 
use lib "$ENV{GUS_HOME}/lib/perl";
use CBIL::Util::Sra;
use Getopt::Long;

my($getFastq);

&GetOptions("getFastq|q!" => \$getFastq 
            );

if(scalar(@ARGV) == 0){
  die "testSRAFetch.pl usage:\n\ttestSRAFetch.pl --getFastq (if present retrieves fastq sequences ... normally would not include this argument if just testing) 'strings to test'\n\tNOTE: it takes in test strings on the commandline.  You can pass in multiple strings for one sample as a comma delimited list ... string1,string2 or 'string1, string2' ... each argument will be evaluated as a sample\n";
}

my $ct = 0;
foreach my $sampleId (@ARGV){
  $ct++;
  my @tmp;
  foreach my $s (split(/,\s*/,$sampleId)){
    push(@tmp,$s);
  }
  &getFastqForSampleIds(\@tmp,"readsFor$ct.fastq","readsRev$ct.fastq",$getFastq ? 0 : 1);
}
