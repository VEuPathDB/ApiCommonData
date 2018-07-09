#!/usr/bin/perl

use strict;
use Tie::IxHash;

my %library;
tie my %hash, "Tie::IxHash";

my $usage = "getSampleInfoFromSRA.pl SRP106638\n";
my $study = shift or die $usage;

my $cmd = "wget -O $study.runInfo.csv 'http://trace.ncbi.nlm.nih.gov/Traces/sra/sra.cgi?save=efetch&db=sra&rettype=runinfo&term=$study'";
print "$cmd\n";

system($cmd);

open INFO, "$study.runInfo.csv";

while(<INFO>) {
  my $header = $_ and next if /^Run/;
  next if /^\s+$/;
  my @arr = split /,/, $_; 
  my $run_id      = $arr[0];
  my $lib         = $arr[11];
  my $sample_id   = $arr[24]; # ERS number
  my $sample_name = $arr[29]; # sample name
  $library{$sample_id} = "$sample_name $lib";

  push @{$hash{$sample_id}}, $run_id; 
}

open OUT, ">$study.samples.txt";

while(my ($k, $v) = each %hash) {
  my $runs = join ',', @$v;
  my $display = &getSampleInfo($k);

  print OUT "$display|$runs\n";
}

close OUT;

sub getSampleInfo {
  my $sample_id = shift;

  my $cmd = "wget -O $sample_id.tmp 'https://www.ncbi.nlm.nih.gov/biosample/$sample_id?report=full&format=text'";
  system($cmd);
  
  $sample_id = "$library{$sample_id}"; 

  open S, "$sample_id.tmp";
  while(<S>) {
    chomp;
    next unless /^\s+\//;
    my ($attr, $val) = split /=/, $_; 
    $val =~ s/"//g;
    if($attr =~ /strain/ || $attr =~ /host/ || $attr =~ /individual/) {
      $sample_id .= " $val";
    }   
  }
  return $sample_id;
}
