#!/usr/bin/perl

use strict;

my $input = $ARGV[0];
my %trans2gene;

open (IN, $input) || die "can not open input file to read.\n";
while (<IN>) {
  chomp;
  my @items = split (/\t/, $_);

  if ($items[2] eq "transcript" && $items[8] =~ /ID \"transcript:(\S+?)\";Parent \"gene:(\S+?)\";/) {
    $trans2gene{$1} = $2;
  }

  $items[8] =~ s/ID \"gene:/ID \"/;
  $items[8] =~ s/Parent \"gene:/Parent \"/;

#  $items[8] =~ s/gene:EPr/EPr/;

  $items[2] = "pseudogenic_transcript" if ($items[2] eq "pseudogene" && $items[8] =~ /;Parent "/);
  $items[2] = "gene"
    if ($items[2] eq "rRNA_gene" || $items[2] eq "snRNA_gene"
	|| $items[2] eq "snoRNA_gene" || $items[2] eq "ncRNA_gene"
	|| $items[2] eq "tRNA_gene" || $items[2] eq "miRNA_gene" );

  $items[2] = "tRNA" if ($items[2] eq "transcript" && $items[8] =~ /biotype \"tRNA/);
  $items[2] = "misc_RNA" if ($items[2] eq "transcript" && $items[8] =~ /biotype \"misc_RNA/);
  $items[2] = "SRP_RNA" if ($items[2] eq "transcript" && $items[8] =~ /biotype \"SRP_RNA/);
  $items[2] = "RNase_MRP_RNA" if ($items[2] eq "transcript" && $items[8] =~ /biotype \"RNase_MRP_RNA/);

  if ($items[2] eq "pseudogenic_tRNA") {$items[2] = "gene"; $items[8] .= "pseudo;"; }

  if ($items[8] =~ /\"transcript:(\S+?)\"/) {
    my $ctId = $1;
    if ($trans2gene{$ctId}) {
      $items[8] =~ s/\"transcript:(\S+?)\"/\"$trans2gene{$1}:RNA\"/g;
    } else {
      $items[8] =~ s/\"transcript:(\S+?)\"/\"$1:RNA\"/g;
    }
  }

  ## for transcript that has tag biotype=nontranslating_CDS, set them as pseudo
  if ($items[2] eq "transcript" && $items[8] =~ /biotype \"nontranslating_/) {
    $items[8] .= "pseudo;";
  }

  &printGff3Column (\@items);
}
close IN;

sub printGff3Column {
  my $array = shift;
  foreach my $i (0..$#{$array}) {
    ($i == 8) ? print "$array->[$i]\n" : print "$array->[$i]\t";
  }
  return 0;
}
