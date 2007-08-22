#!/usr/bin/perl

# parse the dbSNP files from sanger and generate SNP GFF file for input into GUS
# Note that also have files indicating regions covered so we can determine when no changes
# between strain and reference
# note that for coverage files the first word up to the "." in the filename must be the strain and match the
# strain in the id of the snp file.

use strict;
use Getopt::Long;
use File::Basename;

my($seqFile,$snpFiles,$coverageFiles,$source,$refStrain,$doPoly);
my %snps;  ##record snps:  $snp{chromosome}->{location}->{strain} = character
my %cov;  ##record the coverage push(@{$cov{strain}->{chromosome}}, [start,stop]);
my %seq;  ## store sequences to generate flanking ...
my @strains;  ##strains from the names of the coverage files.
my $ctSNPs = 0;  ##count of the number of snps storing in %snps without overlaps
my $ctSingleSnps = 0;  ## sanity check to count single snps not in polys
my $ctPolySnps = 0;  ##count snps in polys
my $ctDiffs = 0;

&GetOptions("snpFiles|sf=s" => \$snpFiles, 
            "coverageFiles|cf=s"=> \$coverageFiles,
            "seqFile=s"=> \$seqFile,
            "source|s=s"=> \$source,  ##this is the source of the SNPs (Sanger)
            "referenceStrain|r=s"=> \$refStrain,  ##this is the name of the reference strain
            "doPoly!" => \$doPoly,
            );

die "Usage: combineSnps.pl --sf 'snp files .. can use *.dbsnp*' --cf 'coverage files .. *ORA' --source <source ie Sanger> --r <reference strain>\n" unless $snpFiles && $coverageFiles && $source && $refStrain;

print STDERR "Identifying SNPs and generating SNPs from POLY SNPs where length of reference and strain are equal\n" if $doPoly;

if($seqFile){
  my $seqId;
  open(F,"$seqFile");
  while(<F>){
    if(/^\>(\S+)/){
      $seqId = $1;
    }else{
      $seq{$seqId} .= $_;
    }
  }
  foreach my $id (keys(%seq)){
    $seq{$id} =~ s/\s//g;
  }
  print STDERR "Loaded ".scalar(keys%seq)." sequences\n";
}

foreach my $file (glob("$snpFiles")){
  print STDERR "processing $file\n";
  &processSnpFile($file);
}

print STDERR "Have identified $ctSNPs total snps in these files\n";
print STDERR "\ndifferences between su and broad = $ctDiffs\n";

##get the coverage info ...
foreach my $file (glob("$coverageFiles")){
  print STDERR "processing coverageFile $file\n";
  if($file =~ /^(.*)\.cov/){
    my $strain = $1;
    $strain = '106/1' if $strain =~ /106/;  ##106/1 has / so need to special case ...
    push(@strains,$strain);
    open(F,$file);
    my %tmp;  ##hold until sorted ...
    while(<F>){
      my @t = split("\t",$_);
#      print STDERR "$strain: $t[0],$t[3],$t[4]\n";
      if(/PercID\s(\S+?)\;/){
#        next if $1 < 95;  ##can choose to ignore alignments with lower than this percent identity
      }
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
  my $ct = 0;
  foreach my $loc (sort { $a <=> $b } keys%{$snps{$chrom}}){
    $ct++;
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
    print "$chrom\t$source\tSNP\t$loc\t$loc\t.\t+\t.\tID CombinedSNP.$chrom.$ct ; Allele \"".join('" "',@a)."\" ; FivePrimeFlank $snps{$chrom}->{$loc}->{$refStrain}->[1] ; ThreePrimeFlank $snps{$chrom}->{$loc}->{$refStrain}->[2]\n";
  }
}


sub isCovered {
  my($strain,$chrom, $pos) = @_;
  return 1 if $strain eq $refStrain;  ## covered by definition
  foreach my $loc (@{$cov{$strain}->{$chrom}}){
    return 1 if ($pos >= $loc->[0] && $pos <= $loc->[1]);
    return 0 if $pos < $loc->[0];  ##we're past this one;
  }
}

sub processSnpFile {
  my $file = shift;
  my $prov = basename($file);
  if($prov =~ /broad/i){
    $prov = "Broad";
  }elsif($prov =~ /sanger/i){
    $prov = "Sanger";
  }else{
    $prov = "NIH"; 
  }
  open(F,"$file");
  my $start = 0;
  while(<F>){
    my@tmp = split("\t",$_);
    if($tmp[8] =~ /^.*?Allele\s+\"(.*?)\"\s*\;.\s*Five\w+\s+(\w+)\s.*?Three\w+\s*(\w+)/){
 #     print STDERR "Matched $_";
      $ctSNPs++;
      my($chrom,$start,$alleles,$lflank,$rflank) = ($tmp[0],$tmp[3],$1,$2,$3);
      ##if negative  strand need to deal with flanks
      if($tmp[6] eq '-'){
        my $tl = $lflank;
        $lflank = &revcomp($rflank);
        $rflank = &revcomp($tl);
      }
      ##also want to make all flanks 50 bp long
      $lflank = substr($lflank,length($lflank) - 50,50) if length($lflank) > 50;
      $rflank = substr($rflank,0,50) if length($rflank) > 50;
      my %st;
      foreach my $all (split(/\"\s+\"/,$alleles)){
        $all =~ s/\"//g;
        my($s,$a) = split(":",$all);
        $st{$s} = $tmp[6] eq '-' ? &revcomp($a) : $a;
      }
      ## first do reference ... will always be 3d7
      $snps{$chrom}->{$start}->{$refStrain} = [$st{$refStrain}, $lflank, $rflank];
      foreach my $k (keys %st){
        next  unless $st{$k}; ##some of the Su snps are null
        next if $k eq $refStrain;
        ##deal with disagreements
        if($snps{$chrom}->{$start}->{$k} && $snps{$chrom}->{$start}->{$k}->[0] ne $st{$k}){
          print STDERR "Inconsistent base for $k - $prov .. strand '$tmp[6]', Broad:$snps{$chrom}->{$start}->{$k}->[0], Su:$st{$k}\n";
          $ctDiffs++;
          $snps{$chrom}->{$start}->{$k."-".$prov} = [$st{$k}];
        }else{
          $snps{$chrom}->{$start}->{$k} = [$st{$k}];
        }
      }
    }
  }
  close F;
}

sub revcomp {
  my $seq = shift;
  my $rev = reverse($seq);
  $rev =~ tr/ACGT/TGCA/;
  return $rev;
}

