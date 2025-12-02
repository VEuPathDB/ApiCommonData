#!/usr/bin/perl

## usage: makeChrMapFileFromGenbank.pl whole_genome.gbf > ../final/chromosomeMap.txt
## The elsif statement needs to be updated to handle variations in the DEFINITION line of the GenBank annotation file

use strict;

my $input = $ARGV[0];
my ($id, $vId, $chr, %chrs);
open (IN, $input) || die "Can not open the genbank file, '$input' to read\nOr missing the argument input file\n  usage: makeChrMapFileFromGenbank.pl whole_genome.gbf > ../final/chromosomeMap.txt\n";
while (<IN>)
{
	if ($_ =~ /^LOCUS\s+(\S+)/) {
		$id = $1;
		print STDERR "id found $id\n";
	}elsif ($_ =~ /^DEFINITION.*chromosome\s+(\S+),/ || $_ =~ /^DEFINITION.*chromosome\:?\s+(\S+)\./ || $_ =~ /^DEFINITION.*chromosome\s+(\S+)\s/) {  ## for FungiDB/pansSmat
#	}elsif ($_ =~ /^DEFINITION.*chromosome\s*:\s*(\S+?)[\,|\.]/ ) {
#	}elsif ($_ =~ /^DEFINITION.*Puerto Rico chromosome\s+(\S+), complete/ ) {  ##
#	}elsif ($_ =~ /^DEFINITION.*chromosome\s+(\S+)\./ ) {  ##
#	}elsif ($_ =~ /^DEFINITION.*chromosome\s+(\S+)\s+/ ) {  ##
#	}elsif ($_ =~ /^DEFINITION.*chromosome\s*\:\s+(\S+)\./) {  ## chromosome : 1.
#	}elsif ($_ =~ /^DEFINITION.*chromosome\s*(\S+)\,/) {  ## chromosome X, 
#	}elsif ($_ =~ /^DEFINITION.*Chr_(\S+),/ ) { ## for 
#	}elsif ($_ =~ /^DEFINITION.*chromosome\s+(\S+) of strain/ ) {  ## for ecunGBM1
#	}elsif ($_ =~ /^DEFINITION.*contig: LinJ(\S+),/ ) {  ## for linfJPCM5 from genbank
#	}elsif ($_ =~ /^DEFINITION.*(Nc_unp_\d+)[\,|\.]/ ) { ## for ncanLiverpool2019 GCA_016097395.1
#	}elsif ($_ =~ /^DEFINITION.*(CH\S+_ECIII-L),/ ) {  ## for ecunEcunIII-L
#	}elsif ($_ =~ /^DEFINITION.*chromosome\s+(\S+), Macaca_fascicularis\_5\.0, whole/) {  ## for HostDB/mfasREF RefSeq
#	}elsif ($_ =~ /^DEFINITION.*chromosome\s+(\S+), whole genome shotgun/) {  ## for HostDB/mfasREF Genbank
#	}elsif ($_ =~ /^DEFINITION.*linkage group\s+(\S+), whole genome shotgun/) {  ## for blacSF5

		$chr = $1;
#		$chr =~ s/PkA1H1_(\d+)_v1/$1/;
		$chr =~ s/PVVCY_(\d+)/$1/;
		$chr =~ s/PVPCR_(\d+)/$1/;
		$chr =~ s/PVSEL_(\d+)/$1/;
		$chr =~ s/^0//;
		print STDERR "chr found $chr\n";	
	}elsif ($_ =~ /^VERSION\s+(\S+)/ ) {
	  $vId = $1;
	  print STDERR "id found at VERSION $id\n";
	}elsif ($_ =~ /^\/\// ) {
		$id = '';
		$vId = '';
		$chr = '';
	}

#	if ($id && $chr) {
	if ($vId && $chr) {
	  $chr =~ s/^\s+//g;
	  $chr =~ s/\s+$//g;
#		$chrs{$id} = $chr;
		$chrs{$vId} = $chr;
		$id = '';
		$vId = '';
		$chr = '';
	}
}

close IN;

my $ct = 1;
#foreach my $k (sort keys %chrs) {
foreach my $k (sort {$chrs{$a} <=> $chrs{$b} } keys %chrs) {  ## sort the keys of the hash based on the values in the hash
  next if ($chrs{$k} =~ /mit/i || $chrs{$k} =~ /api/i);
#	print "$k"."\.1\t$chrs{$k}\t$ct\n";
  ($k =~ /\.\d$/) ? print "$k" : print "$k"."\.1";
  print "\t$chrs{$k}\t$ct\n";
    $ct++;
}

