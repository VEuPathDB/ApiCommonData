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
  # GUS4_STATUS | dots.gene                      | manual | unreviewed
die 'This file has broken or unreviewed GUS4_STATUS rules.  Please remove this line when all are fixed or absent';
#^^^^^^^^^^^^^^^^^^^^^^^^^ End GUS4_STATUS ^^^^^^^^^^^^^^^^^^^^

# blat
# 0      1       2       3               4       5       6               7               8
# qName	tName	strand	blockCount	qStarts	tStarts	blockSizes	misMatches	genomeMatches

# bowtie
#  0         1       2          3                            4                5     6               7
# query_id  strand  target_id  target_start(offset from 0)  query_sequence   ???   genomeMatches   misMatch string
#7_14_2008:1:2:117:568   +       Tb927_03_v4     927217  TTTTGGTTGCGCACCTACAAATTGCCAACTCAGAAC    IIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIII   9 

use strict;
use Getopt::Long;

# my $filename; ##take in on commandline
my $maxGenomeMatch = 14; ##max number of repeated gene in Tbrucei
my $maxBlockCount = 1;
my $extDbSpecs;
my $sample;
my $fileType;
my $mappingFile;
my $normalizeUnique;
my $normalizeMultiple;


&GetOptions("maxGenomeMatch|m=i" => \$maxGenomeMatch,
            "maxBlockCount|b=i" => \$maxBlockCount,
            "extDbSpecs|s=s" => \$extDbSpecs,
            "sample|t=s" => \$sample,
            "fileType|ft=s" => \$fileType,
            "mappingFile|mf=s" => \$mappingFile,
            "normalizeUnique|nu=i" => \$normalizeUnique,
            "normalizeMultiple|nm=i" => \$normalizeMultiple,
            );

die "usage: generateCoveragePlot 
      --filename|f <filename> 
      --maxGenomeMatch|m <matchesToGenome[1]> 
      --maxBlockCount|b <maxBlocks[1]> 
      --extDbSpecs|s <Db Specs for experiment (required)> 
      --sample <sample name (required)> 
      --fileType|ft <(blat|bowtie) .. required> 
      --mappingFile|mf <filename of source_id\tna_sequence_id mapping (optinal)> 
      --normalizeUnique|nu <integer to normalize unique reads to> 
      --normalizeMultiple|nm <integer to normalize multiple reads to>\n" unless $extDbSpecs && $fileType =~ /(blat|bowtie)/i;

#=======================================================================

my ($extDbName,$extDbRlsVer)=split(/\|/,$extDbSpecs);

my $sql = "select external_database_release_id from sres.externaldatabaserelease d, sres.externaldatabase x where x.name = '${extDbName}' and x.external_database_id = d.external_database_id and d.version = '${extDbRlsVer}'";

my $extDbRlsId= `getValueFromTable --idSQL \"$sql\"`;

my %map;
my $ctUnique = 0;
my $ctMultiple = 0;
if($mappingFile){
  open(M,"$mappingFile") || die "unable to open $mappingFile\n";
  while(<M>){
    chomp;
    my@tmp = split("\t",$_);
    next unless scalar(@tmp) == 2;
    $map{$tmp[0]} = $tmp[1];
  }
  close M;
}



my $ct = 0;
my $cov = {};
foreach my $filename (@ARGV){
  print STDERR "Processing $filename\n";
  open(F,"$filename") || die "unable to open $filename\n";
  
  while(<F>){
    chomp;
    my @line = split("\t",$_);
    #  last if $ct++ > 1000;
    if($fileType eq 'blat'){
      next if $line[8] > $maxGenomeMatch;
      next if $line[3] > $maxBlockCount;
      &processHit($line[1],$line[5],$line[6],$line[8]);
    }elsif($fileType eq 'bowtie'){
      next if $line[6] + 1 > $maxGenomeMatch;
      &processHit($line[2],$line[3],length($line[4]),$line[6]+1);
    }else{
      die "fileType $fileType not recognized  ...valid fileTypes blast|bowtie\n";
    }
  }
  close F;
}

my %notMapped;

# deal with normalization
my $normUniq = $normalizeUnique ? $normalizeUnique / $ctUnique : 1;
my $normMult = $normalizeMultiple ? $normalizeMultiple / $ctMultiple : $normalizeUnique ? $normUniq : 1;

##print normalization information to stderr
print STDERR "extDbRlsId: $extDbRlsId, sample: $sample\n$ctUnique unique reads normalization factor = $normUniq\n$ctMultiple multiple reads normalization factor = $normMult\n\n";

##now output the coverage
foreach my $id (keys%{$cov}){
  my $newId = $mappingFile ? $map{$id} : $id;
  if(!$newId){
    print STDERR "unable to map $id\n";
    $notMapped{$id} = scalar(keys%{$cov->{$id}});
    next;
  }
  foreach my $p (keys%{$cov->{$id}}){
    if($cov->{$id}->{$p}->[0] > 0){
      my $log = $cov->{$id}->{$p}->[0] == 1 ? 0.5 * $normUniq : log($cov->{$id}->{$p}->[0] * $normUniq)/log(2);
      print "$extDbRlsId\t$sample\t$newId\t$p\t$log\t0\n";
    }
    if($cov->{$id}->{$p}->[1] > 0){
      my $log = $cov->{$id}->{$p}->[1] == 1 ? 0.5 * $normMult : log($cov->{$id}->{$p}->[1] * $normMult)/log(2);
      print "$extDbRlsId\t$sample\t$newId\t$p\t",(0 - $log),"\t1\n";
    }
  }
}

print STDERR "Unable to map the following ids:\n" if scalar(keys%notMapped) > 0;
foreach my $id (keys%notMapped){
  print STDERR "$id: $notMapped{$id} alignments\n";
}

sub processHit {
  my($id,$sStarts,$bSizes,$gm) = @_;
  my @sS = split(",",$sStarts);
  my @bS = split(",",$bSizes);
  if($gm == 1){ $ctUnique++; }else{ $ctMultiple++; }
  for(my $a = 0;$a<scalar(@sS);$a++){
    for(my $b = 1;$b <= $bS[$a];$b++){  ##start with 1 to adjust for index of sStart of 0
      if($gm == 1){
        $cov->{$id}->{$sS[$a]+$b}->[0]++;
      }else{
        $cov->{$id}->{$sS[$a]+$b}->[1]++;
      }
    }
  }
}
