#!/usr/bin/perl

use strict;
use Getopt::Long;
use CBIL::Util::Utils;
use lib "$ENV{GUS_HOME}/lib/perl";

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

foreach my $d (@ds) {
  next unless $d =~ /^analyze_/;
  $inputDir =~ s/\/$//;
  my $exp_dir = "$inputDir/$d/master/mainresult";

  my $sum_coverage = get_sum_coverage($exp_dir);
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

    if($strandSpecific) {  # strand specific Unique (forward +, reverse -) | NonUnique (forward +, reverse -)
      #&runCmd("cat $k/normalized/RUM_NU_plus.bedgraph $k/normalized/RUM_NU_minus.bedgraph | sort -k1,1 -k2,2n > $k/normalized/final/RUM_NU.bedgraph");
      #&runCmd("cat $k/normalized/RUM_Unique_plus.bedgraph $k/normalized/RUM_Unique_minus.bedgraph | sort -k1,1 -k2,2n > $k/normalized/final/RUM_Unique.bedgraph");

      #&runCmd("bedGraphToBigWig $k/normalized/final/RUM_Unique.bedgraph $topLevelSeqSizeFile $k/normalized/final/RUM_Unique.bw"); 
      #&runCmd("bedGraphToBigWig $k/normalized/final/RUM_NU.bedgraph $topLevelSeqSizeFile $k/normalized/final/RUM_NU.bw"); 

      &runCmd("bedGraphToBigWig $k/normalized/RUM_NU_plus.cov $topLevelSeqSizeFile $k/normalized/final/RUM_NU_plus.bw"); 
      &runCmd("bedGraphToBigWig $k/normalized/RUM_NU_minus.cov $topLevelSeqSizeFile $k/normalized/final/RUM_NU_minus.bw"); 
      &runCmd("bedGraphToBigWig $k/normalized/RUM_Unique_plus.cov $topLevelSeqSizeFile $k/normalized/final/RUM_Unique_plus.bw"); 
      &runCmd("bedGraphToBigWig $k/normalized/RUM_Unique_minus.cov $topLevelSeqSizeFile $k/normalized/final/RUM_Unique_minus.bw"); 

    } else {  # regular Unique +, Nonunique -
      #&runCmd("cat $k/normalized/RUM_Unique.bedgraph $k/normalized/RUM_NU.bedgraph | sort -k1,1 -k2,2n > $k/normalized/final/RUM.bedgraph");
      #&runCmd("bedGraphToBigWig $k/normalized/final/RUM.bedgraph $topLevelSeqSizeFile $k/normalized/final/RUM.bw"); 
      &runCmd("bedGraphToBigWig $k/normalized/RUM_Unique.cov $topLevelSeqSizeFile $k/normalized/final/RUM_Unique.bw"); 
      &runCmd("bedGraphToBigWig $k/normalized/RUM_NU.cov $topLevelSeqSizeFile $k/normalized/final/RUM_NU.bw"); 
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
      next if $f !~ /\.cov/i;
      open(F, "$k/$f");

      open OUT, ">$out_dir/$f";
      <F>;
      while(<F>) {
        my($chr, $start, $stop, $score) = split /\t/, $_;

        my $normalized_score = $score == 0 ? 0 : sprintf ("%.2f", log($score * $max_sum_coverage / $v )/log(2) );

        print OUT "$chr\t$start\t$stop\t$normalized_score\n";
      }
      close F;
      close OUT;
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
    next unless $f =~ /\.cov/;
    open(F, "$d/$f");
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
