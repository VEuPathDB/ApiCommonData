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
  # GUS4_STATUS | dots.gene                      | manual | reviewed
#^^^^^^^^^^^^^^^^^^^^^^^^^ End GUS4_STATUS ^^^^^^^^^^^^^^^^^^^^

use strict;
use Getopt::Long;
use lib "$ENV{GUS_HOME}/lib/perl";
use CBIL::Util::Utils;
use List::Util qw(min max);

use File::Basename;

# this script loops through each experiment output directory and sums the score under each experiment. 
# Use sum_score / max_sum_core as normalization ratio and update coverage file 
#
#  ... Su_strand_specific/analyze_lateTroph/master/mainresult
#  ... Su_strand_specific/analyze_schizont/master/mainresult
#  ... Su_strand_specific/analyze_gametocyteII/master/mainresult
#  ... Su_strand_specific/analyze_gametocyteV/master/mainresult

my %hash;

my ($inputDir, $strandSpecific, $topLevelSeqSizeFile); 

&GetOptions("inputDir=s"            => \$inputDir,
            "topLevelSeqSizeFile=s" => \$topLevelSeqSizeFile,
            "strandSpecific!"       => \$strandSpecific
           );

my $usage =<<endOfUsage;
Usage:
  normalizeCoverage.pl --inputDir input_diretory --topLevelSeqSizeFile chrosome_size_file --strandSpecific 

    intpuDir: top level directory, e.g. /eupath/data/EuPathDB/workflows/PlasmoDB/bigwig/data/pfal3D7/organismSpecificTopLevel/Su_strand_specific
    topLevelSeqSizeFile: chromosome size text file e.g. /eupath/data/EuPathDB/workflows/PlasmoDB/bigwig/data/pfal3D7/organismSpecificTopLevel/topLevelSeqSizes.txt
    strandSpecific: required if the experiement is strand specific
endOfUsage

die $usage unless -e $inputDir;
die $usage unless -e $topLevelSeqSizeFile;

opendir(DIR, $inputDir);
my @ds = readdir(DIR);

foreach my $exp_dir (glob "$inputDir/analyze_*/master/mainresult") {
  my $sum_coverage = &get_sum_coverage($exp_dir);
  $hash{$exp_dir} = $sum_coverage;
}


update_coverage(\%hash);

merge_normalized_coverage(\%hash);

sub merge_normalized_coverage {
  my $hash = shift;
  while(my ($k, $v) = each %$hash) {  # $k is exp directory; $v is sum_coverage
    my $dir = "$k/normalized";
    if(!-e "$dir/final") {
      &runCmd("mkdir $k/normalized/final");
    }

    my @bedFiles = glob "$k/normalized/*.bed";

    foreach my $bedFile (@bedFiles) {
      my $baseBed = basename $bedFile;

      my $bwFile = $baseBed;
      $bwFile =~ s/\.bed$/.bw/;

      &runCmd("bedGraphToBigWig $k/normalized/$baseBed $topLevelSeqSizeFile $k/normalized/final/$bwFile"); 
    }
  }
}

# updates coverage file - score * normalization_ratio
# save updated coverage file to the new 'normalized' directory
sub update_coverage {
  my $hash = shift;

  my $max_sum_coverage = get_max_sum_coverage($hash);

  while(my ($k, $v) = each %$hash) {  # $k is exp directory; $v is sum_coverage
    opendir(D, $k);
    my @fs = readdir(D);

    my $cmd = "mkdir $k/normalized";
    if(!-e "$k/normalized") {
      &runCmd($cmd);
    }

    my $out_dir = "$k/normalized";

    foreach my $f (@fs) {
      next if $f !~ /\.bed/i;
      open(F, "$k/$f");

      open OUT, ">$out_dir/$f";

      my $outputFile = $f;
      $outputFile =~ s/\.bed$/_unlogged.bed/;

      open OUTUNLOGGED, ">$out_dir/$outputFile";
      <F>;
      while(<F>) {
        my($chr, $start, $stop, $score) = split /\t/, $_;

        next unless ($chr && $start && $stop && $score);

        my $normalized_score = $score == 0 ? 0 : sprintf ("%.2f", max((log($score * $max_sum_coverage / $v )/log(2)), 1) );
        print OUT "$chr\t$start\t$stop\t$normalized_score\n";

        my $normalized_score_unlogged = $score == 0 ? 0 : sprintf ("%.2f", max(($score * $max_sum_coverage / $v ), 1) );
        print OUTUNLOGGED "$chr\t$start\t$stop\t$normalized_score_unlogged\n";

      }
      close F;
      close OUT;
      close OUTUNLOGGED;
    }
  }
}


# get sum_coverage under each experiment
sub get_sum_coverage {
  my $d = shift; 
  my $sum_coverage = 0;
  opendir(D, $d);
  my @fs = readdir(D);

  foreach my $f (@fs) {
    next unless $f =~ /\.bed/;
    open(F, "$d/$f") or die "Cannot open file $d/$f for reading:  $!";
    <F>;
    while(<F>) {
      chomp;
      my($chr, $start, $stop, $score) = split /\t/, $_;
      $sum_coverage += $score;
    }
    close F;
  }
  close D;
  return $sum_coverage;
}

sub get_max_sum_coverage {
  my $hash = shift;
  my @arr;
  my @sorted = sort { $a <=> $b } values %$hash;
  return pop @sorted;
}
