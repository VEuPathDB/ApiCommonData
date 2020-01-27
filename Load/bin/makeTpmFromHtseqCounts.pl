#!@perl@
# Take as input count files (two if strand-specific data, else one) from HTSeq and a gene footprint file and outputs tpm files (two if strand-specific data, else one). The denominator in the tpm is the product of the length of the gene footprint and the total counts (sense+antisense total if strand-specific).

use strict;
use warnings;
use lib "$ENV{GUS_HOME}/lib/perl";
use Getopt::Long;
use Data::Dumper;
use ApiCommonData::Load::AnalysisConfigRepeatFinder qw(displayAndBaseName);

#TODO: take in experiment dir and isStranded param instead of file names
#my ($verbose,$geneFootprintFile,$countFile,$tpmFile,$antisenseCountFile,$antisenseTpmFile);
#&GetOptions("verbose!"=>\$verbose,
#            "geneFootprintFile=s"=> \$geneFootprintFile,
#            "countFile=s" => \$countFile,
#            "tpmFile=s" => \$tpmFile,
#            "antisenseCountFile=s" => \$antisenseCountFile,
#            "antisenseTpmFile=s" => \$antisenseTpmFile,
#    ); 

my ($verbose, $geneFootprintFile, $studyDir, $outputDir, $isStranded);
&GetOptions("verbose!"=>\$verbose,
            "geneFootprintFile=s"=> \$geneFootprintFile,
            "studyDir=s"=>\$studyDir,
            "isStranded!"=>\$isStranded
    );

#if(!$geneFootprintFile || !$countFile || !$tpmFile){
if(!$geneFootprintFile || !$studyDir) {
	die "usage: makeTpmFromhtseqCounts.pl --geneFootprintFile <geneFootprintFile> --studyDir <study directory for this experiment> --isStranded <use this flag if the data is stranded>\n";
}


##need to test this with a correct gene footprint file but should work
##TODO: add back when I have a footprint file
##my %geneLengths;
##open(IN, "<$geneFootprintFile");
##my $line = <IN>;
##while ($line=<IN>) {
##    chomp($line);
##    my ($project, $gene, $length, @rest) = split(/\t/, $line);
##    $geneLengths{$gene} = $length;
##}
##close(IN);



#TODO: hard coded because I don't have a footprint file to read from
#will need to read from hash
my $geneLength = 10;

#TODO: figure out directory structure (hard coded from example)                                                                    
my $samplesHash;
foreach my $analysisConfig (glob "$studyDir/../../../analysis_configs/anopheles_gambiae/SRP013741.xml") {
    $samplesHash = displayAndBaseName($analysisConfig);
}

my $samples;
foreach my $group (keys %{$samplesHash}) {
    push @{$samples}, (@{${samplesHash}->{$group}->{'samples'}});
}

foreach my $sample (@{$samples}) {
    my $sampleDir = "$studyDir/$sample";
    if ($isStranded) {
        #TODO: not sure what dir structure looks like here so come back to this
        continue
    }
    else {
        #TODO: determine best location for these output files
        my $countFile = "$studyDir/$sample/genes.htseq-union.unstranded.counts";
        my $tpmFile = "$studyDir/$sample/TPM_unique.txt";
        &doTPMCalculation($geneLength, $countFile, $tpmFile);
        my $nonUniqueCountFile = "$studyDir/$sample/genes.htseq-union.unstranded.nonunique.counts";
        my $nonUniqueTpmFile = "$studyDir/$sample/TPM_nonunique.txt";
        &doTPMCalculation($geneLength, $nonUniqueCountFile, $nonUniqueTpmFile);
    }
}



sub _calcRPK {
    #TODO: will need to take gene lengths hash and find length for each gene
    my %specialCounters = ('__no_feature'=>1, '__ambiguous'=>1, '__too_low_aQual'=>1, '__not_aligned'=>1, '__alignment_not_unique'=>1);
    my($geneLength, $countFile) = @_;
    my $rpkHash;
    my $rpkSum = 0;
    open (IN, "<$countFile") or die "Cannot open file $countFile. Please check and try again\n$!\n";
    while (<IN>) {
        my($geneId, $count) = split /\t/, $_;
        next if ($specialCounters{$geneId});
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
