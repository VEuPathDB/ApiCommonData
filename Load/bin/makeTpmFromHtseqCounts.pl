#!@perl@
# Take as input count files (two if strand-specific data, else one) from HTSeq and a gene footprint file and outputs tpm files (two if strand-specific data, else one). The denominator in the tpm is the product of the length of the gene footprint and the total counts (sense+antisense total if strand-specific).

use strict;
use warnings;
use lib "$ENV{GUS_HOME}/lib/perl";
use Getopt::Long;
use Data::Dumper;
use File::Path qw( make_path );
use ApiCommonData::Load::AnalysisConfigRepeatFinder qw(displayAndBaseName);
use CBIL::StudyAssayResults::CalculationsForTPM qw(doTPMCalculation);


my ($verbose, $geneFootprintFile, $studyDir, $outputDir, $analysisConfig, $isStranded);
&GetOptions("verbose!"=>\$verbose,
            "geneFootprintFile=s"=> \$geneFootprintFile,
            "studyDir=s"=>\$studyDir,
            "outputDir=s"=>\$outputDir,
            "analysisConfig=s"=>\$analysisConfig,
            "isStranded!"=>\$isStranded
    );

if(!$geneFootprintFile || !$studyDir || !$analysisConfig || !$outputDir) {
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
    my $sampleOutDir = "$outputDir/$sample";

    if ( !-d $sampleOutDir ) {
        make_path $sampleOutDir or die "Failed to create directory: $sampleOutDir";
    }

    my ($senseUniqueCountFile, $senseNUCountFile, $antisenseUniqueCountFile, $antisenseNUCountFile, $senseUniqueTpmFile, $senseNUTpmFile, $antisenseUniqueTpmFile, $antisenseNUTpmFile);
    if ($isStranded) {
        $senseUniqueCountFile = "$sampleDir/genes.htseq-union.firststrand.counts";
        $senseUniqueTpmFile = "$sampleOutDir/genes.htseq-union.firststrand.tpm";

        $senseNUCountFile = "$sampleDir/genes.htseq-union.firststrand.nonunique.counts";
        $senseNUTpmFile = "$sampleOutDir/genes.htseq-union.firststrand.nonunique.tpm";

        $antisenseUniqueCountFile = "$sampleDir/genes.htseq-union.secondstrand.counts";
        $antisenseUniqueTpmFile = "$sampleOutDir/genes.htseq-union.secondstrand.tpm";

        $antisenseNUCountFile = "$sampleDir/genes.htseq-union.secondstrand.nonunique.counts";
        $antisenseNUTpmFile = "$sampleOutDir/genes.htseq-union.secondstrand.nonunique.tpm";
    }
    else {
        $senseUniqueCountFile = "$sampleDir/genes.htseq-union.unstranded.counts";
        $senseUniqueTpmFile = "$sampleOutDir/genes.htseq-union.unstranded.tpm";

        $senseNUCountFile = "$sampleDir/genes.htseq-union.unstranded.nonunique.counts";
        $senseNUTpmFile = "$sampleOutDir/genes.htseq-union.unstranded.nonunique.tpm";
    }
    &doTPMCalculation($geneLengths, $senseUniqueCountFile, $senseNUCountFile, $antisenseUniqueCountFile, $antisenseNUCountFile, $senseUniqueTpmFile, $senseNUTpmFile, $antisenseUniqueTpmFile, $antisenseNUTpmFile);
}
