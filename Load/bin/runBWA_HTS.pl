#!/usr/bin/perl

use strict;
use Getopt::Long;

my($fastaFile,$mateA,$mateB,$bwaIndex,$strain);
my $out = "result";
my $varscan = "/Users/brunkb/Software_Downloads/varscan/VarScan.v2.2.5.jar";
my $percentCutoff = 80; ## use to generate consensus
my $minPercentCutoff; ## use for snps and indels
my $editDistance = 0.04;

&GetOptions("fastaFile|f=s" => \$fastaFile, 
            "mateA|ma=s"=> \$mateA,
            "mateB|mb=s" => \$mateB,
            "outputPrefix|o=s" => \$out,
            "bwaIndex|b=s" => \$bwaIndex,
            "varscan|v=s" => \$varscan,
            "strain|s=s" => \$strain,
            "percentCutoff|pc=s" => \$percentCutoff,
            "minPercentCutoff|mpc=s" => \$minPercentCutoff,
            "editDistance|ed=s" => \$editDistance,
            );

die "varscan jar file not found\n" unless -e "$varscan";
die "mateA file not found\n" unless -e "$mateA";
die "mateB file not found\n" if ($mateB && !-e "$mateB");
die "fasta file not found\n" unless -e "$fastaFile";
die "bwa indices not found\n" unless -e "$bwaIndex.amb";
die "you must provide a strain\n" unless $strain;
##should add in usage

$minPercentCutoff = $percentCutoff unless $minPercentCutoff;

print STDERR "runBWA_HTS.pl ... parameter values:\n\tfastaFile=$fastaFile\n\tbwa_index=$bwaIndex\n\tmateA=$mateA\n\tmateB=$mateB\n\toutputPrefix=$out\n\tstrain=$strain\n\tpercentCutoff=$percentCutoff\n\tminPercentCutoff=$minPercentCutoff\n\teditDistance=$editDistance\n\tvarscan=$varscan\n\n";

## indices ..  bwa index -p <prefix for indices> <fastafile>  ##optional -c flag if colorspace

system("(bwa aln -t 4 -n $editDistance $bwaIndex $mateA > $out.mate1.sai) >& $out.bwa_aln_mate1.log");

if(-e "$mateB"){
  system("(bwa aln -t 4 -n $editDistance $bwaIndex $mateB > $out.mate2.sai) >& $out.bwa_aln_mate2.log");

  system("(bwa sampe $bwaIndex $out.mate1.sai $out.mate2.sai $mateA $mateB > $out.sam) >& $out.bwa_sampe.log");
}else{
  print STDERR "Aligning in single end mode only\n";
  
  system("(bwa samse $bwaIndex $out.mate1.sai $mateA > $out.sam) >& $out.bwa_samse.log");
}

system("samtools faidx $fastaFile") unless -e "$fastaFile.fai";

system("(samtools view -t $fastaFile.fai -uS $out.sam | samtools sort - $out) >& $out.samtools_view.log");

system("(samtools pileup -f $fastaFile $out.bam > $out.pileup) &> $out.pileup.err");

my $pc = $percentCutoff / 100;
my $mpc = $minPercentCutoff / 100;

system("(java -jar $varscan pileup2snp $out.pileup --p-value 0.01 --min-coverage 5 --min-var-freq $mpc > $out.varscan.snps ) >& $out.varscan_snps.log");

system("(java -jar $varscan pileup2indel $out.pileup --p-value 0.01 --min-coverage 5 --min-var-freq $mpc > $out.varscan.indels ) >& $out.varscan_indels.log");

system("parseVarscanToGFF.pl --f $out.varscan.snps --strain $strain --pc $minPercentCutoff --o $out.SNPs.gff >& $out.parseVarscan.err");

system("(java -jar $varscan pileup2cns $out.pileup --p-value 0.01 --min-coverage 5 --min-var-freq $pc > $out.varscan.cons ) >& $out.varscan_cons.log");

