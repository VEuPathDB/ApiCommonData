#!/usr/bin/perl
use strict;
use Getopt::Long;
use lib "$ENV{GUS_HOME}/lib/perl";
use CBIL::Util::Utils;
use List::Util qw(min max);
use ApiCommonData::Load::AnalysisConfigRepeatFinder qw(displayAndBaseName);
use File::Basename;
use CBIL::StudyAssayResults::SplitBamUniqueNonUnique qw(splitBamUniqueNonUnique);
use Data::Dumper;
use Cwd;

# this script loops through each experiment output directory and sums the score under each experiment. 
# Use sum_score / max_sum_core as normalization ratio and update coverage file 

my %hash;

my ($inputDir, $topLevelSeqSizeFile, $seqIdPrefix, $analysisConfig);

&GetOptions("inputDir=s"            => \$inputDir,
            "seqSizeFile=s" => \$topLevelSeqSizeFile,
            "analysisConfig=s"      => \$analysisConfig,
            "seqIdPrefix=s"         => \$seqIdPrefix
 );

my $usage =<<endOfUsage;
Usage:
  normalizeCoverageEbi.pl --inputDir input_directory --topLevelSeqSizeFile chromosome_size_file --analysisConfig analysisConfigFile --seqIdPrefix

    inputDir: top level directory, e.g. /eupath/data/EuPathDB/workflows/PlasmoDB/bigwig/data/pfal3D7/organismSpecificTopLevel/Su_strand_specific
    topLevelSeqSizeFile: chromosome size text file e.g. /eupath/data/EuPathDB/workflows/PlasmoDB/bigwig/data/pfal3D7/organismSpecificTopLevel/topLevelSeqSizes.txt
    analysisConfig: analysisConfig file
    seqIdPrefix: prefix for sequence source ids (e.g., VB seqeuences are prefixed with the organism abbreviation in GUS to ensure uniqueness)
endOfUsage

die $usage unless -e $inputDir;
die $usage unless -e $topLevelSeqSizeFile;
die $usage unless -e $analysisConfig;

my $samplesHash = displayAndBaseName($analysisConfig);


# input dir will have subdirectories results,tpm,and analisis_output
my $artifactsDirName = "results";

# let's write all of our output to this directory
my $workingDirectory = "${inputDir}/normalize_coverage";
mkdir $workingDirectory;

my %dealingWithReps;

my $mappingStatsBasename = "mappingStats.txt";

foreach my $groupKey (keys %$samplesHash) {
    my @samples = @{$samplesHash->{$groupKey}->{samples}};
    my @mappingStatsFiles = map {"$inputDir/${artifactsDirName}/${_}"} @samples;

    if(scalar @mappingStatsFiles > 1) {
        push @{$dealingWithReps{$groupKey}}, @mappingStatsFiles;
    }
    else {
        my $directory_short = $mappingStatsFiles[0];
        $directory_short=~ s/$inputDir\///;
        $directory_short = "$directory_short";
        $hash{$directory_short} = &getCountHash($mappingStatsFiles[0], $mappingStatsBasename);
    } 
}


foreach my $expWithReps (keys %dealingWithReps) {

    my $count = 0;
    my %scoreHash;
    my $exp_dir = "$workingDirectory/$expWithReps"."_combined";
    my $cmd = "mkdir -p $exp_dir";
    &runCmd($cmd);
    my $listOfUniqueRepBwFiles;
    my $listOfNonUniqueRepBwFiles;
    my $listOfUniqueFirstStrandFiles;
    my $listOfUniqueSecondStrandFiles;
    my $listOfNonUniqueFirstStrandFiles;
    my $listOfNonUniqueSecondStrandFiles;
    my @FileSets;
    &makeMappingFile($dealingWithReps{$expWithReps}, $exp_dir, $mappingStatsBasename);
#need to add here dealing with the stand etc.     
    foreach my $replicateDir (@{$dealingWithReps{$expWithReps}}) {
 	    foreach	my $file_to_open (glob "$replicateDir/*.bed") {
            my $baseBed = basename $file_to_open;
            my $bwFile = $baseBed; 	    
            $bwFile =~ s/\.bed$/.bw/;
            $bwFile =~ s/\.bed$/.bw/;

            &sortBedGraph("$replicateDir/$baseBed");
            &runCmd("bedGraphToBigWig $replicateDir/$baseBed $topLevelSeqSizeFile $replicateDir/$bwFile"); 

            if ($baseBed =~ /^unique/) {
                if ($baseBed =~/firststrand/)  {
                    $listOfUniqueFirstStrandFiles.= "$replicateDir/$bwFile ";
                }
                elsif ($baseBed =~/secondstrand/) {
                    $listOfUniqueSecondStrandFiles.= "$replicateDir/$bwFile ";
                }
                else{
                    $listOfUniqueRepBwFiles.= "$replicateDir/$bwFile ";
                }
            }
            elsif ($baseBed =~ /^non_unique/) {
                if ($baseBed =~/firststrand/)  {
                    $listOfNonUniqueFirstStrandFiles.= "$replicateDir/$bwFile ";
                }
                elsif ($baseBed =~/secondstrand/) {
                    $listOfNonUniqueSecondStrandFiles.= "$replicateDir/$bwFile ";
                }
                else{
                    $listOfNonUniqueRepBwFiles.= "$replicateDir/$bwFile ";
                }
            }
        }
    }

    push @FileSets , ($listOfUniqueFirstStrandFiles, $listOfUniqueSecondStrandFiles, $listOfUniqueRepBwFiles, $listOfNonUniqueFirstStrandFiles, $listOfNonUniqueSecondStrandFiles, $listOfNonUniqueRepBwFiles);
    
    foreach my $set (@FileSets) {
        next unless (defined $set);
        my @temps = split  " ", $set;
        my $fileToUse = $temps[0];
        my $base = basename $fileToUse;
        $base =~ s/\.bw//;
        my $cmd = "bigWigMerge $set $exp_dir/${base}CombinedReps.bed";
        &runCmd($cmd);
    }
    my $direct= $exp_dir;
    $direct =~ s/$workingDirectory//;
	$hash{$direct} = &getCountHash($exp_dir, $mappingStatsBasename);
}

&update_coverage(\%hash, $seqIdPrefix);

&merge_normalized_coverage(\%hash);

sub merge_normalized_coverage {
    my $hash = shift;
    while(my ($k, $v) = each %$hash) {  # $k is exp directory; %v is sum_coverage
        my $dir = "$workingDirectory/$k/normalized";
        if(!-e "$dir/final") {
            &runCmd("mkdir $dir/final");
        }
        my $cwd = getcwd;
        chdir "$workingDirectory/$k/normalized/";
        my @bedFiles = glob "*.bed";
        chdir "$cwd";
     	foreach my $bedFile (@bedFiles) {
     	    my $baseBed = basename $bedFile;
     	    my $bwFile = $baseBed;
     	    $bwFile =~ s/\.bed$/.bw/;

            &sortBedGraph("$workingDirectory/$k/normalized/$baseBed");
     	    &runCmd("bedGraphToBigWig $workingDirectory/$k/normalized/$baseBed $topLevelSeqSizeFile $workingDirectory/$k/normalized/final/$bwFile");
     	}
    }
}

sub sortBedGraph {
  my $bedFile = shift;

  my $cmd = "mv $bedFile ${bedFile}.tmp; LC_COLLATE=C sort -k1,1 -k2,2n ${bedFile}.tmp > $bedFile; rm ${bedFile}.tmp";
  &runCmd($cmd);

  return $bedFile;
}


# # updates coverage file - score * normalization_ratio
# # save updated coverage file to the new 'normalized' directory
sub update_coverage {
    my ($hash, $seqIdPrefix) = @_;
    my %hash2 = %$hash;

    foreach my $k (keys %hash2) {  # $k is exp directory; $v is sum_coverage  
        my @sorted = sort {$a <=> $b } values %{$hash2{$k}};
        my $kIn;
        if ($k =~ /(.+)_combined/) {
            $kIn = $k;
        } elsif ($k =~ /(.+)/) {
            $kIn = $k;
        }
        my $out_dir = "$workingDirectory/$k/normalized";;
        my $dir_open = $inputDir."/".$kIn;


        print "OUT_DIR=$out_dir\n";
        print "DIR_OPEN=$dir_open\n";
        opendir(D, $dir_open) or die "Cannot open dir $dir_open for reading: $!";
        my @fs = readdir(D);
        my $cmd = "mkdir -p $out_dir";
        if(!-e $out_dir) {
            &runCmd($cmd);
        }
        
        my $normFactor = 1;

        if($k =~ /(.+)_combined/) {
          if($samplesHash->{$1}->{samples}) {
            $normFactor = scalar @{$samplesHash->{$1}->{samples}} * $normFactor;
          }
          else {
            die "Could not determine number of reps for combined file $k";
          }
        }
        
        foreach my $f (@fs) {
            next if $f !~ /\.bed$/i;
            open(F, "$inputDir/$kIn/$f") or die "cannot open file $inputDir/${artifactsDirName}/$kIn/$f for reading: $!";
            open OUT, ">$out_dir/$f" or die "Cannot open file $out_dir/$f for writing: $!";
            my $outputFile = $f;
            my $bamfile = $f;
            $bamfile =~ s/\.bed$/.bam/;
            $outputFile =~ s/\.bed$/_unlogged.bed/;
            open OUTUNLOGGED, ">$out_dir/$outputFile" or die "cannot open file $out_dir/$outputFile for writing :$!";
            my $coverage = $hash2{$k}{$bamfile}->[0];
            my $avgReadLength = $hash2{$k}{$bamfile}->[1];


            while(<F>) {
            my($chr, $start, $stop, $score) = split /\t/, $_;
            
            next unless ($chr && $start && $stop && $score);

            $chr = $seqIdPrefix ? "$seqIdPrefix:$chr" : $chr;
                        
            my $normalized_score = $score == 0 ? 0 : sprintf ("%.2f", (($score * (($stop-$start)/$avgReadLength)) / (($coverage /1000000) * (($stop - $start)/1000)))/$normFactor );
            #we want to set any that have a normalized score to <1 to 0 for only the score. 
            my $normalized_score_for_log = $normalized_score;
            if ($normalized_score_for_log < 1) {
                $normalized_score_for_log = 0;
            }
            print OUTUNLOGGED "$chr\t$start\t$stop\t$normalized_score\n";
            my $normalized_score_logged = $normalized_score_for_log == 0 ? 0 :sprintf ("%.2f", ((log($normalized_score_for_log))/(log(2))));
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
    my $f = shift;
    open my $IN, "$d/$f" or die "cant open mapping file $d/$f\n\n\n";
    while(my $line = <$IN>) {
	chomp $line;
	if ($line =~ /^file/) {
	    next;
	}
	elsif ($line =~ /^\s*$/) {
	    next;
	}
	elsif ($line =~ /DONE STATS/) {
	    next;
	}
	else {
	    my($file, $coverage, $percentage, $count, $avgReadLen) = split /\t/, $line;
	    my $shortfile = basename $file;
	    $hash{$shortfile} = [$count, $avgReadLen];
	}
    }
    return \%hash;
}


sub makeMappingFile{
    my ($repFiles, $comboDir, $mappingStatsBase) = @_;

    my $countReps = 0;
    my %totals;
    foreach my $rep (@$repFiles) {
            $countReps ++;
            open(R, "$rep/$mappingStatsBase") or die "Cannot open file $rep/$mappingStatsBase for reading:$!";;
            <R>;
            while(<R>) {
        	chomp $_;
        	if ($_ =~ /file/) {
        	    next;
        	}
        	elsif ($_ =~ /^\s*$/) {
        	    next;
        	}
        	elsif ($_ =~ /DONE STATS/) {
        	    next;
        	}
        	else {
        	    my($file, $coverage, $percentage, $count, $avgReadLen) = split /\t/, $_;
        	    my $shortname = basename $file;
        	    if (exists $totals{$shortname}) {
        		@{$totals{$shortname}}[0] += $coverage;
        		@{$totals{$shortname}}[1] += $percentage;
        		@{$totals{$shortname}}[2] += $count;
        		@{$totals{$shortname}}[3] += $avgReadLen;
        	    }
        	    else {
        		@{$totals{$shortname}} = ($coverage, $percentage, $count, $avgReadLen);
        	    }
		    
        	}
            }


    }
    my $mapping = $comboDir."/mappingStats.txt";
    open (M, ">$mapping") or die "Could not open file $mapping for writing: $!";;
    print M "file\tcoverage\tpercentageMapped\treadsMapped\n";

    foreach my $key (keys %totals) {
        my $finalFile = $key;
        $finalFile =~ s/.bam/CombinedReps.bam/;
        my $finalCoverage= ($totals{$key}->[0] / $countReps);
        my $finalPercentage= ($totals{$key}->[1]/ $countReps);
        my $finalCount = ($totals{$key}->[2] / $countReps) ;
        my $finalAvgReadLen = ($totals{$key}->[3] / $countReps) ;
        print M "$finalFile\t$finalCoverage\t$finalPercentage\t$finalCount\t$finalAvgReadLen\n";
	
    }
    print M "DONE STATS";
    close M;
    return "finished";
}
