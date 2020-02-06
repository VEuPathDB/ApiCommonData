#!@perl@
# Take as input count files (two if strand-specific data, else one) from HTSeq and a gene footprint file and outputs tpm files (two if strand-specific data, else one). The denominator in the tpm is the product of the length of the gene footprint and the total counts (sense+antisense total if strand-specific).

use strict;
use warnings;
use lib "$ENV{GUS_HOME}/lib/perl";
use Getopt::Long;
use Data::Dumper;
use ApiCommonData::Load::AnalysisConfigRepeatFinder qw(displayAndBaseName);


my ($verbose, $geneFootprintFile, $studyDir, $outputDir, $analysisConfig, $isStranded);
&GetOptions("verbose!"=>\$verbose,
            "geneFootprintFile=s"=> \$geneFootprintFile,
            "studyDir=s"=>\$studyDir,
            "analysidConfig=s"=>\$analysisConfig,
            "isStranded!"=>\$isStranded
    );

if(!$geneFootprintFile || !$studyDir || !$analysisConfig) {
	die "usage: makeTpmFromhtseqCounts.pl --geneFootprintFile <geneFootprintFile> --studyDir <study directory for this experiment> --analysisConfig <analysisConfigFile> --isStranded <use this flag if the data is stranded>\n";
}


my $geneLengths;
open(IN, "<$geneFootprintFile");
my $line = <IN>;
while ($line=<IN>) {
    chomp($line);
    my ($project, $gene, $length, @rest) = split(/\t/, $line);
    $geneLengths->{$gene} = $length;
}
close(IN);


my $samplesHash = displayAndBaseName($analysisConfig);

my $samples;
foreach my $group (keys %{$samplesHash}) {
    push @{$samples}, (@{${samplesHash}->{$group}->{'samples'}});
}

foreach my $sample (@{$samples}) {
    my $sampleDir = "$studyDir/$sample";
    if ($isStranded) {
        my $firstStrandCountFile = "$studyDir/$sample/genes.htseq-union.firststrand.counts";
        my $firstStrandTpmFile = "$studyDir/$sample/genes.htseq-union.firststrand.tpm";
        &doTPMCalculation($geneLengths, $firstStrandCountFile, $firstStrandTpmFile);

        my $firstStrandNUCountFile = "$studyDir/$sample/genes.htseq-union.firststrand.nonunique.counts";
        my $firstStrandNUTpmFile = "$studyDir/$sample/genes.htseq-union.firststrand.nonunique.tpm";
        &doTPMCalculation($geneLengths, $firstStrandNUCountFile, $firstStrandNUTpmFile);

        my $secondStrandCountFile = "$studyDir/$sample/genes.htseq-union.secondstrand.counts";
        my $secondStrandTpmFile = "$studyDir/$sample/genes.htseq-union.secondstrand.tpm";
        &doTPMCalculation($geneLengths, $secondStrandCountFile, $secondStrandTpmFile);

        my $secondStrandNUCountFile = "$studyDir/$sample/genes.htseq-union.secondstrand.nonunique.counts";
        my $secondStrandNUTpmFile = "$studyDir/$sample/genes.htseq-union.secondstrand.nonunique.tpm";
        &doTPMCalculation($geneLengths, $secondStrandNUCountFile, $secondStrandNUTpmFile);
    }
    else {
        my $countFile = "$studyDir/$sample/genes.htseq-union.unstranded.counts";
        my $tpmFile = "$studyDir/$sample/genes.htseq-union.unstranded.tpm";
        &doTPMCalculation($geneLengths, $countFile, $tpmFile);

        my $nonUniqueCountFile = "$studyDir/$sample/genes.htseq-union.unstranded.nonunique.counts";
        my $nonUniqueTpmFile = "$studyDir/$sample/genes.htseq-union.unstranded.nonunique.tpm";
        &doTPMCalculation($geneLengths, $nonUniqueCountFile, $nonUniqueTpmFile);
    }
}



sub _calcRPK {
    my %specialCounters = ('__no_feature'=>1, '__ambiguous'=>1, '__too_low_aQual'=>1, '__not_aligned'=>1, '__alignment_not_unique'=>1);
    my($geneLengths, $countFile) = @_;
    my $rpkHash;
    my $rpkSum = 0;
    open (IN, "<$countFile") or die "Cannot open file $countFile. Please check and try again\n$!\n";
    while (<IN>) {
        my($geneId, $count) = split /\t/, $_;
        next if ($specialCounters{$geneId});
        my $geneLength = $geneLengths->{$geneId};
        $rpkSum += $count;
        my $rpk = $count/$geneLength;
        $rpkHash->{$geneId} = $rpk;
    }
    close IN;
    return ($rpkSum, $rpkHash);
}

sub _calcTPM {
    my ($rpkHash, $rpkSum) = @_;
    my $tpmHash;
    while (my($geneId, $rpk) = each %{$rpkHash}) {
        my $tpm = $rpk/$rpkSum;
        $tpmHash->{$geneId} = $tpm;
    }
    return $tpmHash;
}

sub _writeTPM {
    my ($tpmFile, $tpmHash) = @_;
    open (OUT, ">$tpmFile") or die "Cannot open TPM file $tpmFile for writing. Please check and try again.\n$!\n";
    while (my ($geneId, $tpm) = each %{$tpmHash}) {
        print OUT ("$geneId\t$tpm\n") 
    }
    close OUT;
}

sub doTPMCalculation {
    my ($geneLengths, $countFile, $tpmFile) = @_;
    my ($rpkSum, $rpkHash) = &_calcRPK($geneLengths, $countFile);
    $rpkSum = $rpkSum/1000000;
    my $tpmHash = &_calcTPM($rpkHash, $rpkSum);
    &_writeTPM($tpmFile, $tpmHash);
}
