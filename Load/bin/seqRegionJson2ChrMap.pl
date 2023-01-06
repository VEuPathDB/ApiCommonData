#!/usr/bin/perl

## usage: seqRegionJson2ChrMap.pl aedes_aegypti_lvpagwg_seq_region.json > chromosomeMap.txt
## grep sequence IDs from name(or maybe BRC4_seq_region_name) and chromosome info from synonyms, and generated chromosomeMap.txt file

use strict;
use JSON;
use Data::Dumper;

my ($jsonFile) = @ARGV;

open (IN, $jsonFile) || die "can not open $jsonFile to read\n";
#my $json = <IN>;
my $json;
while (<IN>) {
  chomp;
  $_ =~ s/^\s+//;
  $_ =~ s/\s+$//;
  next if ($_ =~ /^$/);
  $json .= $_;
}
close IN;

my $text = decode_json($json);
#print STDERR Dumper($text);

my %chrMap;

foreach my $t (@{$text}) {

#  foreach my $k (sort keys %{$t}) {
#    if ($t->{coord_system_level} eq "chromosome" && ($t->{location} ne "mitochondrial_chromosome" && $t->{location} ne "apicoplast_chromosome" ) ) {
    if ($t->{coord_system_level} eq "chromosome" && $t->{location} eq "nuclear_chromosome" ) {

#      my ($chrId, $chrNum);
      my $chrId = $t->{name};
      my $chrNum;
      foreach my $synonym (@{$t->{synonyms}}) {
	## $synonym->{source} = INSDC, GenBank, INSDC_submitted_name
	## $synonym->{name} = 1, CM043769.1, PB_01
#	$chrId = $synonym->{name} if ($synonym->{source} =~ /genbank/i );
	$chrNum = $synonym->{name} if ($synonym->{source} =~ /^insdc$/i);
      }

      if ($chrId && $chrNum) {
	$chrMap{$chrId} = $chrNum;
      } else {
	print STDERR "double check $t->{name}\n";
      }
    }
#  }
}


my $chrCount;
foreach my $k (sort keys %chrMap) {
  $chrCount++;
  print "$k\t$chrMap{$k}\t$chrCount\n";

}


