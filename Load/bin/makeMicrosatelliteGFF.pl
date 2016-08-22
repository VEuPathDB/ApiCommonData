#!/usr/bin/perl
#vvvvvvvvvvvvvvvvvvvvvvvvv GUS4_STATUS vvvvvvvvvvvvvvvvvvvvvvvvv
  # GUS4_STATUS | SRes.OntologyTerm              | auto   | absent
  # GUS4_STATUS | SRes.SequenceOntology          | auto   | absent
  # GUS4_STATUS | Study.OntologyEntry            | auto   | absent
  # GUS4_STATUS | SRes.GOTerm                    | auto   | absent
  # GUS4_STATUS | Dots.RNAFeatureExon            | auto   | absent
  # GUS4_STATUS | RAD.SageTag                    | auto   | absent
  # GUS4_STATUS | RAD.Analysis                   | auto   | absent
  # GUS4_STATUS | ApiDB.Profile                  | auto   | absent
  # GUS4_STATUS | Study.Study                    | auto   | absent
  # GUS4_STATUS | Dots.Isolate                   | auto   | absent
  # GUS4_STATUS | DeprecatedTables               | auto   | absent
  # GUS4_STATUS | Pathway                        | auto   | absent
  # GUS4_STATUS | DoTS.SequenceVariation         | auto   | absent
  # GUS4_STATUS | RNASeq Junctions               | auto   | absent
  # GUS4_STATUS | Simple Rename                  | auto   | absent
  # GUS4_STATUS | ApiDB Tuning Gene              | auto   | absent
  # GUS4_STATUS | Rethink                        | auto   | absent
  # GUS4_STATUS | dots.gene                      | manual | unreviewed
die 'This file has broken or unreviewed GUS4_STATUS rules.  Please remove this line when all are fixed or absent';
#^^^^^^^^^^^^^^^^^^^^^^^^^ End GUS4_STATUS ^^^^^^^^^^^^^^^^^^^^

use strict;
use IO::File; 
use Getopt::Long;

my ($help, $stsFile, $genomeFasta, $mapFile, $outputGff);

&GetOptions('help|h' => \$help,
            'stsFile=s' => \$stsFile,
            'mapFile=s' => \$mapFile,
            'genomeFasta=s' => \$genomeFasta,
	    'outputGff=s' => \$outputGff,
            );

unless(-e $stsFile && $mapFile && $genomeFasta) {
  print STDERR "usage:  perl      makeMicrosatelliteGFF.pl      --stsFile <Microsatellite sts file>       --genomeFasta <xdformatted fasta file of Genome>     --mapFile  <Microsatellites-Centimorgan mapping file>      --outputGff  Output file to print the GFF features to\n";
  exit;
}



open(sts,$stsFile );
open(fwdFasta,">forwardPrimers.fasta");
open(rvsFasta,">reversePrimers.fasta");

while (<sts>) {
  chomp;
  my $stsLine = $_;
  my @elements = split(/\t/,$stsLine);
  print(fwdFasta ">$elements[0]\n$elements[1]\n");
  print(rvsFasta ">$elements[0]\n$elements[2]\n");
}


#The command is optimized with parameters to search for similarity for very short sequences. Additionally B=14 has been set because Pfalciparum has 14 chromosomes and along with hspmax=1, only one best hit per chromosome will be reported. This is then correlated with the centimorgan-microsatellite map provided to determine which chromosome is the correct match.
my $cmd1 = `blastn $genomeFasta  forwardPrimers.fasta -sort_by_pvalue -mformat=2 E=1000 W=7 M=1 N=-3 Q=5 R=2 B=14 hspmax=1 warnings >forwardHits.txt`;

my $cmd2 = `blastn $genomeFasta reversePrimers.fasta -sort_by_pvalue -mformat=2 E=1000 W=7 M=1 N=-3 Q=5 R=2 B=14 hspmax=1 warnings  >reverseHits.txt`;


eval $cmd1;
eval $cmd2;



my (%IdChrMap,%fwdCood,%revCood,%strand,%cMorgan,%stsName);

open (mapFile,$mapFile);

while (<mapFile>) {

   my @elements = split(/\t/,$_);
   chomp(@elements);

   next unless (($elements[1] =~ /G/) || ($elements[3] ne "."));

   $cMorgan{$elements[1]} = $elements[3];
   $stsName{$elements[1]} = $elements[0];

#map chromosome number to chromosome Id in the DB
  if ($elements[4] < 10) {
        $IdChrMap{$elements[1]} = "Pf3D7_0".$elements[4];
     } else {
        $IdChrMap{$elements[1]} = "Pf3D7_".$elements[4];
     }
}



open (fwdHits,"forwardHits.txt");

while (<fwdHits>) {
  chomp;
  my $line = $_;

  my @hitElements = split(/\t/,$line);
  my $Id = $hitElements[0];
  my $chromId = $hitElements[1];
  my $strand = $hitElements[16];

  next unless (exists $IdChrMap{$Id});
  next unless $chromId =~ m/$IdChrMap{$Id}/; #proceed only if the chromosome reported as hit is the same as provided in the Map.

  if ($strand eq "+1") {
    $fwdCood{$chromId}{$Id} = $hitElements[20];
    $strand{$chromId}{$Id} = "+";
  } else {
    $revCood{$chromId}{$Id} = $hitElements[21];
    $strand{$chromId}{$Id} = "-";
  }
}
close (fwdHits);


open (revHits,"reverseHits.txt");

while (<revHits>) {
  chomp;
  my $line = $_;

  my @hitElements = split(/\t/,$line);
  my $Id = $hitElements[0];
  my $chromId = $hitElements[1];
  my $strand = $hitElements[16];

  next unless (exists $IdChrMap{$Id});
  next unless $chromId =~ m/$IdChrMap{$Id}/;

  if ($strand eq "-1") {
    $revCood{$chromId}{$Id} = $hitElements[21];
  } else {
    $fwdCood{$chromId}{$Id} = $hitElements[20];
  }
}
close (revHits);

open (gffFile, ">$outputGff");

foreach my $chromosome (sort keys %fwdCood){
  foreach my $Id (sort {$fwdCood{$chromosome}{$a} <=> $fwdCood{$chromosome}{$b} } %{ $fwdCood{$chromosome} }) {
    next unless (exists $revCood{$chromosome}{$Id});
    next unless (abs($fwdCood{$chromosome}{$Id} - $revCood{$chromosome}{$Id}) < 1000);
    my $chr = $chromosome;
    $chr =~ s/psu\|//g;
    print  gffFile "$chr\tSu\tmicrosatellite\t$fwdCood{$chromosome}{$Id}\t$revCood{$chromosome}{$Id}\t.\t$strand{$chromosome}{$Id}\t.\tID $Id\; Name $stsName{$Id}\n";
  }
}
close(gffFile);
