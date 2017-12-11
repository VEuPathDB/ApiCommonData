#!/usr/bin/perl

use strict;

## a script to call convertEmbl2gff3.pl script
## to batch conver embl to gff and fasta files

## usage: batchConvertEmbl2gff3.pl embl gff

my ($inputDir, $outputDir) = @ARGV;

my $command = "ls $inputDir | grep embl";
my @inputFiles = `$command`;

foreach my $file (@inputFiles) {
  chomp ($file);

  my $gffFile = $file;
  $gffFile =~ s/\.embl$/\.gff/;

  my $fastaFile = $file;
  $fastaFile =~ s/\.embl$/\.fasta/;

  my $eachCommand = "convertEmbl2gff3.pl $inputDir/$file $outputDir/$gffFile $outputDir/$fastaFile";
  `$eachCommand`;

#  print STDERR "$file\n";
}
