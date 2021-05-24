#!/usr/bin/perl

# DEPENDENCIES:
# samtools
# bedGraphToBigWig
# wigToBigWig
# Homer: homer/bin directory added to executable path (see http://homer.salk.edu/homer/introduction/install.html). 
# Danpos2: https://sites.google.com/site/danposdoc/install
# note that due to conflicting dependencies, Danpos2 will be run from a a docker container using Singularity from May 2020


use strict;
use Getopt::Long;
use File::Basename;

my ($experimentType, $inBamFile,$outDir, $topLevelSeqSizeFile, $fragmentLength);
&GetOptions("experimentType=s" => \$experimentType,
            "inBamFile=s" => \$inBamFile,
	    "outDir=s" => \$outDir,
	    "topLevelSeqSizeFile=s" => \$topLevelSeqSizeFile,
	    "fragmentLength=i" => \$fragmentLength
    ); 

die "USAGE: $0 --experimentType <experimentType> --inBamFile <input_bam_file> --outDir <output_dir> --topLevelSeqSizeFile <top_level_seq_size_file> [--fragmentLength i]\n"
    if (!$experimentType || !$inBamFile|| !$outDir || !$topLevelSeqSizeFile);

my $bwFile = $outDir . 'results.bw';

# As of Aug 21, 2015, we have assessed the HOMER coverage plot feature only for histonemod and mnase single-end experiments (and, for mnase data, DANPOS2 was deemed preferable). As more types of experiments are assessed, the resulting HOMER cvg plots should be examined to determine whether the software is doing a good job on those. If not, other sections should be added to this script to deal with those cases.

if ($experimentType ne 'mnase') {
    my $samFile = $inBamFile;
    $samFile =~ s/bam$/sam/;
    my $samtoolsCmd = "samtools view $inBamFile > $samFile";
    print STDERR "\n$samtoolsCmd\n\n";
    system($samtoolsCmd) == 0 or die "system $samtoolsCmd failed: $?";

    my $makeTagDirCmd = "makeTagDirectory $outDir -unique -format sam";
    if ($fragmentLength) {
	$makeTagDirCmd .=  " -fragLength $fragmentLength";
    }
    $makeTagDirCmd .= " $samFile";
    print STDERR "$makeTagDirCmd\n\n";
    system($makeTagDirCmd) == 0 or die "system $makeTagDirCmd failed: $?";
    unlink($samFile);
    
    my $makeUcscFileCmd = "makeUCSCfile $outDir -o $outDir" . "results.bedGraph"; 
    if ($fragmentLength) {
	$makeUcscFileCmd .=  " -fragLength $fragmentLength";
    }
    print STDERR "$makeUcscFileCmd\n\n";
    system($makeUcscFileCmd) == 0 or die "system $makeUcscFileCmd failed: $?";
    
    my $gunzipCmd = "gunzip $outDir" . "results.bedGraph.gz";
    print STDERR "$gunzipCmd\n\n";
    system($gunzipCmd) == 0 or die "system $gunzipCmd failed: $?";
    
    my $makeBwFileCmd = "bedGraphToBigWig $outDir" . "results.bedGraph $topLevelSeqSizeFile $bwFile";
    print STDERR "$makeBwFileCmd\n\n";
    system($makeBwFileCmd) == 0 or die "system $makeBwFileCmd failed: $?";
}

else {
    my $bamFileDir = dirname($inBamFile);
    my $bamFileName = basename($inBamFile);
    my $seqSizeDirName = dirname($topLevelSeqSizeFile);
    my $dposCmd = "singularity exec --bind $bamFileDir:/tmp,$outDir:/data docker://biocontainers/danpos:v2.2.2_cv3 danpos.py dpos /tmp/$bamFileName -o /data";

    if ($fragmentLength) {
	$dposCmd .=  " --frsz $fragmentLength";
    }
    print STDERR "$dposCmd\n\n";
    system($dposCmd) == 0 or die "system $dposCmd failed: $?";
    
    opendir(DIR, "$outDir/pooled/");
    while (my $file = readdir(DIR)) {
	next unless (-f "$outDir/pooled/$file");
	if ($file =~ m/\.wig$/) {
	    my $makeBwFileCmd = "singularity exec --bind $outDir:/data,$seqSizeDirName:/tmp docker://biowardrobe2/ucscuserapps:v358_2 wigToBigWig -clip /data/pooled/$file /tmp/chrom.sizes /data/results.bw";
	    print STDERR "$makeBwFileCmd\n\n";
	    system($makeBwFileCmd) == 0 or die "system $makeBwFileCmd failed: $?";
	    last;
	}
    }
}

