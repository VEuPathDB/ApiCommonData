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

# parse the dbSNP files from sanger and generate SNP GFF file for input into GUS
# Note that also have files indicating regions covered so we can determine when no changes
# between strain and reference
# note that for coverage files the first word up to the "." must be the strain and match the
# strain in the id of the snp file.

use strict;
use Getopt::Long;

my($snpFiles,$coverageFiles,$source,$refStrain,$doPoly);
my %snps;  ##record snps:  $snp{chromosome}->{location}->{strain} = character
my %cov;  ##record the coverage push(@{$cov{strain}->{chromosome}}, [start,stop]);
my @strains;  ##strains from the names of the coverage files.
my $ctSNPs = 0;  ##count of the number of snps storing in %snps without overlaps
my $ctSingleSnps = 0;  ## sanity check to count single snps not in polys
my $ctPolySnps = 0;  ##count snps in polys

&GetOptions("snpFiles|sf=s" => \$snpFiles, 
            "coverageFiles|cf=s"=> \$coverageFiles,
            "source|s=s"=> \$source,  ##this is the source of the SNPs (Sanger)
            "referenceStrain|r=s"=> \$refStrain,  ##this is the name of the reference strain
            "doPoly!" => \$doPoly,
            );

die "Usage: sangerSnps2Gff.pl --sf 'snp files .. can use *.dbsnp*' --cf 'coverage files .. *ORA' --source <source ie Sanger> --r <reference strain>\n" unless $snpFiles && $coverageFiles && $source && $refStrain;

print STDERR "Identifying SNPs and generating SNPs from POLY SNPs where length of reference and strain are equal\n" if $doPoly;

foreach my $file (glob("$snpFiles")){
  print STDERR "processing $file\n";
  &processSnpFile($file);
}

print STDERR "Have identified $ctSNPs total snps and $ctPolySnps POLY snps in these files\n";

##get the coverage info ...
foreach my $file (glob("$coverageFiles")){
  print STDERR "processing coverageFile $file\n";
  if($file =~ /^(\w+)\./){
    my $strain = $1;
    push(@strains,$strain);
    open(F,"$file") || die "sangerSnps2Gff.pl ERROR: unable to open '$file'\n";
    my %tmp;  ##hold until sorted ...
    while(<F>){
      my @t = split("\t",$_);
      push(@{$tmp{$t[0]}},[$t[3],$t[4]]);
    }
    ## probably shouldn't assume that the coverage files are sorted by location .. 
    foreach my $chr (keys%tmp){
      @{$cov{$strain}->{$chr}} = sort {$a->[0] <=> $b->[0]} @{$tmp{$chr}};
    }
  }else{
    print STDERR "Unable to determine strain from coverage file $file .. aborting\n";
  }
  close F;
}


##now need to go through the snps and generate the GFF lines ...
foreach my $chrom (sort { $a <=> $b } keys%snps){
  foreach my $loc (sort { $a <=> $b } keys%{$snps{$chrom}}){
    ##need to get the coverage info here ... get all strains covered and if not a snp then assign reference
    my @a;
    my %tmpStr;
    foreach my $strain (keys%{$snps{$chrom}->{$loc}}){
      $tmpStr{$strain} = 1;
      push(@a,"$strain:$snps{$chrom}->{$loc}->{$strain}->[0]");
      ##sanity check to make certain snp is in covered region
      print STDERR "Error: snp in $strain:$chrom at $loc is not covered by sequence\n" unless &isCovered($strain,$chrom,$loc);
    }
    ## add the strains that are same as reference...
    foreach my $strain (@strains){
      next if $tmpStr{$strain};  ##already have this one
      push(@a, "$strain:$snps{$chrom}->{$loc}->{$refStrain}->[0]") if &isCovered($strain,$chrom,$loc);
    }
    ## now print the thing
    print "$chrom\t$source\tSNP\t$loc\t$loc\t.\t+\t.\tID $snps{$chrom}->{$loc}->{$refStrain}->[1] ; Allele \"".join('" "',@a)."\" ; FivePrimeFlank $snps{$chrom}->{$loc}->{$refStrain}->[2] ; ThreePrimeFlank $snps{$chrom}->{$loc}->{$refStrain}->[3]\n";
  }
}

sub isCovered {
  my($strain,$chrom, $pos) = @_;
  return 1 if $strain eq $refStrain;  ## covered by definition
  foreach my $loc (@{$cov{$strain}->{$chrom}}){
    return 1 if ($pos > $loc->[0] && $pos < $loc->[1]);
    return 0 if $pos < $loc->[0];  ##we're past this one;
  }
}

sub processSnpFile {
  my $file = shift;
  open(F,"$file") || die "sangerSnps2Gff.pl ERROR: unable to open '$file'\n";
  my @snp;
  my $start = 0;
  while(<F>){
    if(/^SNP:/){
      $start = 1;
      &parseSnp(\@snp) if @snp;
      undef @snp;
    }
    next unless $start;
    push(@snp,$_);
  }
  &parseSnp(\@snp) if @snp;
  close F;
}

sub parseSnp {
  my($snp) = @_;
  my %tmp;
  foreach my $line (@$snp){
    if($line =~ /^(\S*?):(.*)$/){
      $tmp{$1} = $2;
    }
  }
  return if (!$doPoly && $tmp{COMMENT} =~ /POLY/);
  if($tmp{OBSERVED} =~ /(\S+)\/(\S+)/){
    my($ref,$allele) = ($1,$2);
    ##check to make certain that it is a snp ...or can be broken into snps without any indels
    return if($ref =~ /-/ || $allele =~ /-/ || length($ref) != length($allele));
    #now get the location and chromosome and strain ... is in the SNP identifier
    if($tmp{SNP} =~ /^\S+\.(\w+)\.\d+\.(\w+)\.(\d+)\.(\d+)\.\d+$/){
      my($strain,$chrom,$start,$end) = ($1,$2,$3,$4);
      my @ref = split("",$ref);
      my @all = split("",$allele);
      for(my $a = 0;$a < scalar(@ref);$a++){
        if($ref[$a] eq $all[$a]){
 #         print STDERR "In Poly ($ref/$allele):  not a snp at position ".($a+1)."\n";
          next;
        }
        $ctSNPs++;
        $ctSingleSnps++ if length($ref) == 1;
        $ctPolySnps++ if $tmp{COMMENT} =~ /POLY/;
        $snps{$chrom}->{$start + $a}->{$strain} = [$all[$a]];
        ##note that appending the position in the poly to the id when a snp is located in a poly
        ##otherwise the identifiers will not be unique.
        ##also need to adjust the flank as what is given flanks the entire poly ...
        my $lflank = substr($tmp{"5'_FLANK"},$a) . substr($ref,0,$a);
        my $refSubstr = substr($ref,$a+1,50); 
        my $rflank = $refSubstr . substr($tmp{"3'_FLANK"},0,50 - length($refSubstr));
        $snps{$chrom}->{$start + $a}->{$refStrain} = [$ref[$a], $tmp{SNP}.(scalar(@ref) > 1 ? ".".($a+1) : ""), $lflank, $rflank];
      }
    }else{
      print STDERR "Unable to parse @$snp\n";
    }
  }
}
