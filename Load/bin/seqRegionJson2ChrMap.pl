#!/usr/bin/perl

## usage: seqRegionJson2ChrMap.pl aedes_aegypti_lvpagwg_seq_region.json > chromosomeMap.txt
## grep all synonyms and assign them to sequence IDs, then generated chromosomeMap based on all sequence IDs

use strict;
use JSON;
use Data::Dumper;

my ($jsonFile) = @ARGV;

open (IN, $jsonFile) || die "can not open $jsonFile to read\n";
my $json = <IN>;
close IN;

my $text = decode_json($json);

my %chrMap;

foreach my $t (@{$text}) {
  foreach my $k (sort keys %{$t}) {
    if ($t->{coord_system_level} =~ /chromosome/i) {
#      foreach my $synonym (@{$t->{synonyms}}) {
#	$chrMap{$synonym} = $t->{name};
#      }
      $chrMap{$t->{name}} = $t->{name} if ($t->{name} !~ /^mt/i);
    }
  }
}

#my %chrMapNum2Id;
#foreach my $kk (sort keys %chrMap) {
#  push @{$chrMapNum2Id{$chrMap{$kk}}}, $kk;
#}

my $chrCount;
#foreach my $k3 (sort keys %chrMapNum2Id) {
foreach my $k (sort keys %chrMap) {
  $chrCount++;
  print "$k\t$k\t$chrCount\n";

#  foreach my $id (@{$chrMapNum2Id{$k3}}) {
#    print "$id\t$k3\t$chrCount\n";
#    print "$k3\t$k3\t$chrCount\n";
#  }
}

#print STDERR Dumper($text);

