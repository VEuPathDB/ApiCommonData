#!/usr/bin/perl

use strict;
use Getopt::Long;
use GUS::Supported::GusConfig;


my ($organismAbbrev, $outputFileDir, $help);

&GetOptions('organismAbbrev=s' => \$organismAbbrev,
            'outputFileDir=s' => \$outputFileDir,
            'help|h' => \$help
            );

&usage() if ($help);
&usage("Missing a Required Argument") unless (defined $organismAbbrev);

my $preProteinFile = $organismAbbrev . "_protein.fa";
my $finalGffFile =  $organismAbbrev . ".modified.gff3";

if ($outputFileDir) {
  $preProteinFile = "\./". $outputFileDir . "\/". $preProteinFile;
  $finalGffFile = "\./". $outputFileDir . "\/". $finalGffFile;
}

my $outputFileName = $preProteinFile;

my $tempProteinFile = $preProteinFile . ".temp";
my $renameProteinCmd = "mv $preProteinFile $tempProteinFile";
system($renameProteinCmd);

my $hasCdsHash = checkIfHasCdsInGff($finalGffFile);

open (OUT, ">$outputFileName") || die "cannot open $outputFileName file to write.\n";
open (IN, $tempProteinFile) || die "cannot open temp file: $tempProteinFile to read.\n";
my $ifSkip = 0;
while (<IN>) {
  if ($_ =~ /^>(\S+)/) {
    my $id = $1;
    $ifSkip = ($hasCdsHash->{$id} != 1) ? 1 : 0;
  }
  print OUT $_ if ($ifSkip == 0);
}
close IN;
close OUT;

my $removeTempFileCmd = "rm $tempProteinFile";
system($removeTempFileCmd);

###########
#    $translationIds{$trsltIds} = $trsltIds if ($isPseudo != 1 && $isPseudoFromGff->{$trcpIds} != 1);

sub checkIfHasCdsInGff {
  my ($gffFile) = @_;

  my %hasCds;
  my $c;
  open (IN, $gffFile) || die "can not open file \"$gffFile\" to read\n";
  while (<IN>) {
    my @items = split (/\t/, $_);
    if ($items[2] eq "CDS") {
      my ($idTag) = split (/\;/, $items[8]);
      my ($tag, $id) = split(/\=/, $idTag);
      $hasCds{$id} = 1;
    }
  }
  close IN;
  return \%hasCds;
}


sub usage {
  die
"
A script to modify protein sequence file for EBI file transferring, no protein sequence will be extrac if there is no CDS in gff3

Usage: modifyProteinSeqBasedGff.pl --organismAbbrev cneoJEC21 --outputFileDir FungiDB_2020-07-30_extra/cneoJEC21

where:
  --organismAbbrev: required, eg. pfal3D7
  --outputFileDir: optional, a directory name for output files

";
}
