#!/usr/bin/perl

use strict;

use lib $ENV{GUS_HOME} . "/lib/perl";
use Getopt::Long;
use CBIL::Util::Utils;
use ApiCommonData::Load::AnalysisConfigRepeatFinder qw(displayAndBaseName);
use Data::Dumper;

my ($help, $dir, $experimentName, $chromSize, $analysisConfig);

&GetOptions('help|h' => \$help,
            'dir=s' => \$dir,
            'experimentName=s' => \$experimentName,
	        'chromSize=s' => \$chromSize,
            'analysisConfig=s' => \$analysisConfig,
            );
      
&usage("RNAseq samples directory not defined") unless $dir;

chomp $dir;

my $sampleHash;
if (-e $analysisConfig) {
    $sampleHash = displayAndBaseName($analysisConfig);
} else {
    die "Analysis config file $analysisConfig cannot be opened for reading\n";
}

my @list;
my $sampleDirName;
foreach my $key (keys %$sampleHash) {
    my $samples = $sampleHash->{$key}->{samples};
    if (scalar @$samples > 1) {
        $sampleDirName = $key ."_combined";
    } elsif (scalar @$samples == 1) {
        $sampleDirName = $samples->[0]
    } else {
        die "No samples found for key $key\n";
    }

    my $sampleDirName = -e "$dir/analyze_$sampleDirName/master/mainresult" ? "$dir/analyze_$sampleDirName/master/mainresult" : "$dir/analyze_$sampleDirName";
    my @files = glob "$sampleDirName/normalized/final/*";

    my @files = grep !/logged/, @files;
    my @files = grep !/non_unique/, @files;
    push @list, @files;
}

my $outDir = "$dir/mergedBigwigs";
&runCmd("mkdir -p $outDir");

if ( grep( /firststrand/, @list ) ) {
  my @firstStrandFileList = grep /firststrand/, @list;
  &convertBigwig(\@firstStrandFileList, $outDir, $chromSize, $experimentName, "firststrand");
}
if ( grep( /secondstrand/, @list ) ) {
  my @secondStrandFileList = grep /secondstrand/, @list;
  &convertBigwig(\@secondStrandFileList, $outDir, $chromSize, $experimentName, "secondstrand");
}
else{
  &convertBigwig(\@list, $outDir, $chromSize, $experimentName, "unstranded");
}

sub convertBigwig {
    my ($fileList, $outDir, $chromSize, $experimentName, $pattern) = @_;
    my $fileNames = join ' ', @$fileList;
    #Check if more than 1 input bigwig file
    if (scalar @$fileList > 1){ 
    my $cmd = "bigWigMerge $fileNames $outDir/out.bedGraph";
    &runCmd($cmd);
    my $convertCmd = "bedGraphToBigWig $outDir/out.bedGraph $chromSize $outDir/$experimentName\_$pattern\_merged.bw";
    &runCmd($convertCmd);
    unlink "$outDir/out.bedGraph";
    }
    #If only one bigwig file copy to outdir
    else{
    my $cpCmd = "cp $fileNames $outDir/$experimentName\_$pattern\_merged.bw";
    &runCmd($cpCmd);   
    } 
}

sub usage {
  die "rnaseqMerge.pl --dir=s --organism_abbrev=s  --outdir=s --chromSize=s \n";
}

1;

