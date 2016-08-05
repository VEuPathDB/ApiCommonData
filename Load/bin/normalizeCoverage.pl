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
use ApiCommonData::Load::AnalysisConfigRepeatFinder qw(displayAndBaseName);
use File::Basename;
use CBIL::TranscriptExpression::SplitBamUniqueNonUnique qw(splitBamUniqueNonUnique);
use Data::Dumper;
# this script loops through each experiment output directory and sums the score under each experiment. 
# Use sum_score / max_sum_core as normalization ratio and update coverage file 
#
#  ... Su_strand_specific/analyze_lateTroph/master/mainresult
#  ... Su_strand_specific/analyze_schizont/master/mainresult
#  ... Su_strand_specific/analyze_gametocyteII/master/mainresult
#  ... Su_strand_specific/analyze_gametocyteV/master/mainresult

my %hash;

my ($inputDir, $strandSpecific, $topLevelSeqSizeFile, $isPairedEnd); 

&GetOptions("inputDir=s"            => \$inputDir,
            "topLevelSeqSizeFile=s" => \$topLevelSeqSizeFile,
            "strandSpecific!"       => \$strandSpecific,
	    "isPairedEnd!" => \$isPairedEnd
 );

my $usage =<<endOfUsage;
Usage:
  normalizeCoverage.pl --inputDir input_diretory --topLevelSeqSizeFile chrosome_size_file --strandSpecific --isPairedEnd

    intpuDir: top level directory, e.g. /eupath/data/EuPathDB/workflows/PlasmoDB/bigwig/data/pfal3D7/organismSpecificTopLevel/Su_strand_specific
    topLevelSeqSizeFile: chromosome size text file e.g. /eupath/data/EuPathDB/workflows/PlasmoDB/bigwig/data/pfal3D7/organismSpecificTopLevel/topLevelSeqSizes.txt
    strandSpecific: required if the experiement is strand specific
  isPairedEnd: required if the experiment is paired end 
endOfUsage

die $usage unless -e $inputDir;
die $usage unless -e $topLevelSeqSizeFile;

opendir(DIR, $inputDir);
my @ds = readdir(DIR);

# pull display name and base name for any with replciation
my $analysis_config_display;
my %samplesWithRepsHash;
foreach my $analysis_config (glob "$inputDir/*/final/analysisConfig.xml") {
    %samplesWithRepsHash = displayAndBaseName($analysis_config);	
}    

my %dealingWithReps;


my $mappingStatsBasename = "mappingStats.txt";

foreach my $exp_dir (glob "$inputDir/analyze_*/master/mainresult") {
  my $mappingStats = "$exp_dir/$mappingStatsBasename";


  if(-e $mappingStats) {
    my $statsString = `cat $mappingStats`;
    if($statsString =~ /DONE STATS/) {
      next;

    }
    else {
      print "data set $exp_dir has not been split on unique non unique mapping. doing this now ...\n";
      my $splitExpDir = splitBamUniqueNonUnique($exp_dir, $strandSpecific, $isPairedEnd, "$exp_dir/results_sorted.bam");
    }
  }
  else {
    print "data set $exp_dir has not been split on unique non unique mapping. doing this now ...\n";
    my $splitExpDir = splitBamUniqueNonUnique($exp_dir, $strandSpecific, $isPairedEnd, "$exp_dir/results_sorted.bam");
  }
}


foreach my $exp_dir (glob "$inputDir/analyze_*/master/mainresult") {
    my %fileSpecificCoverage;
    if (keys %samplesWithRepsHash >=1) {
 	foreach my $keys (keys %samplesWithRepsHash) { 

 	    if ($exp_dir =~ /$samplesWithRepsHash{$keys}/) { # this pulls out any files that are replicates to deal with the seperately. 
 		my $fileBaseName = $samplesWithRepsHash{$keys};
                push @{$dealingWithReps{$fileBaseName}}, $exp_dir;
 	    }
 	    else {
		%fileSpecificCoverage = &getCountHash($exp_dir);
 		$hash{$exp_dir} = \%fileSpecificCoverage;
 	    }
 	}
    }
    else {
	%fileSpecificCoverage = &getCountHash($exp_dir);
	$hash{$exp_dir} = \%fileSpecificCoverage;
    }
}


foreach my $expWithReps (keys %dealingWithReps) {
    my $count = 0;
    my %scoreHash;
    my $exp_dir = "$inputDir/analyze_$expWithReps"."_combined";
    my $cmd = "mkdir $exp_dir";
     &runCmd($cmd);
     my $cmd = "mkdir $exp_dir/master";
     &runCmd($cmd);
     my $cmd = "mkdir $exp_dir/master/mainresult";
     &runCmd($cmd);
    $exp_dir = "$exp_dir/master/mainresult";
    my $listOfUniqueRepBwFiles;
    my $listOfNonUniqueRepBwFiles;
    &makeMappingFile($inputDir, $expWithReps, $exp_dir);
    
    foreach my $replicate (@{$dealingWithReps{$expWithReps}}) {
 	foreach	my $file_to_open (glob "$replicate/*.bed") {
 	    my $baseBed = basename $file_to_open;
 	    my $bwFile = $baseBed;
 	    $bwFile =~ s/\.bed$/.bw/;
	    &runCmd("bedGraphToBigWig $replicate/$baseBed $topLevelSeqSizeFile $replicate/$bwFile"); 
	    if ($baseBed =~ /^unique/) {
		$listOfUniqueRepBwFiles.= "$replicate/$bwFile ";
	    }
	    elsif ($baseBed =~ /^non_unique/) {
		$listOfNonUniqueRepBwFiles.= "$replicate/$bwFile ";
	    }
 	}
	
    }
       my $cmd = "bigWigMerge -max $listOfUniqueRepBwFiles $exp_dir/uniqueCombinedReps.bed";
       &runCmd($cmd);
    my $cmd = "bigWigMerge -max $listOfNonUniqueRepBwFiles $exp_dir/non_uniqueCombinedReps.bed";
     &runCmd($cmd);
    my %fileSpecificCoverage = &getCountHash($exp_dir);
    $hash{$exp_dir} = \%fileSpecificCoverage;
}


update_coverage(\%hash);

merge_normalized_coverage(\%hash);

sub merge_normalized_coverage {
    my $hash = shift;
    while(my ($k, $v) = each %$hash) {  # $k is exp directory; %v is sum_coverage
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

# # updates coverage file - score * normalization_ratio
# # save updated coverage file to the new 'normalized' directory
sub update_coverage {
    my $hash = shift;
    my %hash2 = %$hash;
    foreach my $k (keys %hash2) {  # $k is exp directory; $v is sum_coverage  
	my @sorted = sort {$a <=> $b } values %{$hash2{$k}};
	my $max_sum_coverage = pop @sorted;
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
	    my $bamfile = $f;
	    $bamfile =~ s/\.bed$/.bam/;
	    $outputFile =~ s/\.bed$/_unlogged.bed/;
	    open OUTUNLOGGED, ">$out_dir/$outputFile";
	    #print Dumper %hash2;
	    #print "file to look for is $bamfile\n";
	    my $coverage = $hash2{$k}{$bamfile};
	    <F>;
	    while(<F>) {
		my($chr, $start, $stop, $score) = split /\t/, $_;
		
		next unless ($chr && $start && $stop && $score);
		
		my $normalized_score = $score == 0 ? 0 : sprintf ("%.2f", ($score * $max_sum_coverage / $coverage ));
		print OUTUNLOGGED "$chr\t$start\t$stop\t$normalized_score\n";
		my $normalized_score_logged = sprintf ("%.2f", ((log($normalized_score))/(log(2))));
		print OUT "$chr\t$start\t$stop\t$normalized_score_logged\n";
		
	    }
	    close F;
	    close OUT;
	    close OUTUNLOGGED;
	}
    }
}

sub getCountHash {
    
    my %hash;
    my $d = shift;
    open my $IN, "$d/mappingStats.txt" or die "cant find mapping file\n\n\n";
    while(my $line = <$IN>) {
	chomp $line;
	if ($line =~ /file/) {
	    next;
	}
	elsif ($line =~ /^\s*$/) {
	    next;
	}
	else {
	    my($file, $coverage, $percentage, $count) = split /\t/, $line;
	    my $shortfile = basename $file;
	    $hash{$shortfile} = $count;
	}
    }
    return %hash;
}


sub makeMappingFile{
    my ($inputDir, $baseName, $comboDir) = @_;
    my $countReps = 0;
    my %totals;
    foreach my $rep (glob "$inputDir/analyze_$baseName*/master/mainresult/mappingStats.txt") {
	if ($rep =~ /combined/) {
	    #combined already has a mapping file 
	    last;
	}
	else { 
	    $countReps ++;
	    open(R, "$rep");
	    <R>;
	    while(<R>) {
		chomp $_;
		if ($_ =~ /file/) {
		    next;
		}
		elsif ($_ =~ /^\s*$/) {
		    next;
		}
		else {
		    my($file, $coverage, $percentage, $count) = split /\t/, $_;
		    my $shortname = basename $file;
		    if (exists $totals{$shortname}) {
			@{$totals{$shortname}}[0] += $coverage;
			@{$totals{$shortname}}[1] += $percentage;
			@{$totals{$shortname}}[2] += $count;
		    }
		    else {
			@{$totals{$shortname}} = ($coverage, $percentage, $count);
		    }
		    
		}
	    }
	}

    }
    my $mapping = $comboDir."/mappingStats.txt";
    open (M, ">$mapping");
    print M "file\tcoverage\tpercentageMapped\treadsMapped\n";
    foreach my $key (keys %totals) {
	my $finalFile = $key;
	$finalFile =~ s/_results_sorted.bam/CombinedReps.bam/;
	my $finalCoverage= ($totals{$key}->[0] / $countReps);
	my $finalPercentage= ($totals{$key}->[1]/ $countReps);
	my $finalCount = ($totals{$key}->[2] / $countReps) ;
	print M "$finalFile\t$finalCoverage\t$finalPercentage\t$finalCount\n";
	
    }
    close M;
    return "finished";
}
