#!/usr/bin/perl

# DEPENDENCIES:
# Homer: homer/bin directory added to executable path (see http://homer.salk.edu/homer/introduction/install.html). 
# bedGraphToBigWig

use strict;
use Getopt::Long;

my ($inBamFile,$outDir, $topLevelSeqSizesFile);
&GetOptions("inBamFile=s" => \$inBamFile,
	    "outDir=s" => \$outDir,
	    "topLevelSeqSizesFile=s" => \$topLevelSeqSizesFile
    ); 

die "USAGE: $0 --inBamFile <input_bam_file> --outDir <output_dir> --topLevelSeqSizesFile <top_level_seq_sizes_file>\n"
    if (!$inBamFile|| !$outDir || !$topLevelSeqSizesFile);

my $samFile = $outDir . '/forHomer.sam';
my $homerOutDir = $outDir . '/homer/';
my $samtoolsCmd = "samtools view $inBamFile > $samFile";
print STDERR "\n$samtoolsCmd\n\n";
system($samtoolsCmd) == 0 or die "system $samtoolsCmd failed: $?";

my $makeTagDirCmd = "makeTagDirectory $homerOutDir -unique $samFile -format sam";
print STDERR "$makeTagDirCmd\n\n";
system($makeTagDirCmd) == 0 or die "system $makeTagDirCmd failed: $?";
unlink($samFile);

my $makeUcscFileCmd = "makeUCSCfile $homerOutDir -o auto"; 
print STDERR "$makeUcscFileCmd\n\n";
system($makeUcscFileCmd) == 0 or die "system $makeUcscFileCmd failed: $?";

my $bedGraphFile = $homerOutDir . 'homer.ucsc.bedGraph';
my $bwFile = $homerOutDir . 'homer.bw';

my $gunzipCmd = "gunzip $bedGraphFile.gz";
print STDERR "$gunzipCmd\n\n";
system("$gunzipCmd") == 0 or die "system $gunzipCmd failed: $?";

my $makeBwFileCmd = "bedGraphToBigWig $bedGraphFile $topLevelSeqSizesFile $bwFile";
print STDERR "$makeBwFileCmd\n\n";
system($makeBwFileCmd) == 0 or die "system $makeBwFileCmd failed: $?";

