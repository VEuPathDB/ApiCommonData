#!/usr/bin/perl

## parses varscan output to generate a gff file that can be loaded with InsertSNPs plugin

use strict;
use Getopt::Long;

my $file; 
my $strain;
my $output = 'snps.gff';
my $percentCutoff = 25;
my $pvalueCutoff = .01;
my $depthCutoffMult = 2;

&GetOptions("file|f=s" => \$file, 
            "percentCutoff|pc=i"=> \$percentCutoff,
            "pvalueCutoff|pvc=i"=> \$pvalueCutoff,
            "depthCutoff|dc=i"=> \$depthCutoffMult,
            "output|o=s"=> \$output,
            "strain|s=s"=> \$strain,
            );

if (! -e $file || !$strain){
print <<endOfUsage;
parseVarscanToGFF.pl usage:

  parseVarscanToGFF.pl --file|f <varscan file> --strain <strain for snps> --percentCutoff|pc <frequency percent cutoff [25]> --pvalueCutoff|pvc <pvalue cutoff [0.01]> --depthCutoff|dc <multiplier times medidan for depth cutoff [2]> --output|o <outputFile [snps.gff]>
endOfUsage
}

open(O,">$output");

my %iupac = ('A' => ['A'],
             'C' => ['C'],
             'G' => ['G'],
             'T' => ['T'],
             'R' => ['A','G'],
             'Y' => ['C','T'],
             'M' => ['A','C'],
             'K' => ['G','T'],
             'S' => ['C','G'],
             'W' => ['A','T'],
             'B' => ['C','G','T'],
             'D' => ['A','G','T'],
             'H' => ['A','C','T'],
             'V' => ['A','C','G'],
             'N' => ['A','C','G','T']
            );

##first determine the depthCutoff
open(F, "$file") || die "unable to open file $file\n";
my @lines;
my @covArr;
while(<F>){
  next if /^Chrom\s+Position/;
  chomp;
  my @tmp = split("\t",$_);
  push(@lines,\@tmp);
  push(@covArr,$tmp[4] + $tmp[5]);

}

##determine median..
my @sorted = sort{$a <=> $b}@covArr;
my $median = $sorted[int(scalar(@sorted) / 2)];
my $depthCutoff = int($median * $depthCutoffMult);
print STDERR "Maximum depth cutoff for considering SNPs = $depthCutoff\n";

my @tmpLines;
foreach my $line (@lines){
  if(scalar(@tmpLines) > 0 && $tmpLines[-1]->[1] == $line->[1] && $tmpLines[-1]->[0] eq $line->[0]){  ##same position
    push(@tmpLines,$line);
  }else{
    &process(\@tmpLines) if scalar(@tmpLines) > 0;
    undef @tmpLines;
    push(@tmpLines,$line);
  }
}

close O;

#process this one and print to O 
sub process {
  my($lines) = @_;
    
  my $cov =  &getCoverage($lines);
  return if $cov > $depthCutoff;  ## exceeds depthCutoff

  ##want to reprint with percent properly computed if multiple lines
#  if(scalar(@{$lines}) > 1){
#    foreach my $l (@{$lines}){
#      $l->[6] = int($l->[5] / $cov * 1000) / 10;
#      print join("\t",@{$l})."\n";
#    }
#    print "-------------------\n";
#  }
  ## now process ... 
  my $f = $lines->[0];  ##process the first one ....
  my @alleles = &getAlleles($lines,$cov);
  return unless scalar(@alleles) >= 1;
  my $id = "NGS_SNP.$f->[0].$f->[1]";
  print O "$f->[0]\tNGS_SNP\tSNP\t$f->[1]\t$f->[1]\t.\t+\t.\tID $id; Allele \"".join("\" \"",@alleles)."\";\n";
}

sub getAlleles {
  my($lines,$cov) = @_;
  my $minPvalue = &getMinPvalue($lines);
  my $f = shift(@{$lines});
  my @alleles;
  ##make a reference entry if > $depthCutoff ... how can we determine p value .. don't really have one!
  ## could use the minimum pvalue ...
  push(@alleles,"$strain:$f->[2]:$cov:".(int($f->[4] / $cov * 1000) / 10).":$f->[9]:$minPvalue") if $f->[4] / $cov * 100 > $percentCutoff;
  push(@alleles,"$strain:".&getAllele($f).":$cov:".(int($f->[5] / $cov * 1000) / 10).":$f->[10]:$f->[11]") if $f->[5] / $cov * 100 > $percentCutoff;
  foreach my $l (@{$lines}){
    push(@alleles,"$strain:".&getAllele($l).":$cov:".(int($l->[5] / $cov * 1000) / 10).":$l->[10]:$l->[11]") if $l->[5] / $cov * 100 > $percentCutoff;
  }
  return @alleles;
}

##note that am summing coverage at each position for each base.
sub getCoverage {
  my($lines) = @_;
  my $cov = $lines->[0]->[4] + $lines->[0]->[5];
  for(my $a = 1;$a < scalar(@{$lines}); $a++){
    $cov += $lines->[$a]->[5];
  }
  return $cov;
}

sub printGFF {
  my($l,$cov,$type,$pvalue) = @_;
#  print STDERR "printGFF('line',$cov,$type,$pvalue)\n";
  my $allele = $type eq 'reference' ? $l->[2] : &getAllele($l);
  my $perc = $type eq 'reference' ? int($l->[4] / $cov * 1000) / 10 : int($l->[5] / $cov * 1000) / 10;
  my $id = "NGS_SNP.".$l->[0] .".".$l->[1];
  print O "$l->[0]\t$type\tSNP\t$l->[1]\t$l->[1]\t.\t.\t.\tID $id; Allele \"$strain:$allele:$cov:$perc:$pvalue:".($type eq 'reference' ? $l->[9] : $l->[10])."\"\n";
}

sub getAllele {
  my($l) = @_;
  die "ERROR: consensus symbol '$l->[3]' has > 2 possibilities (".join(",",@{$iupac{$l->[3]}}).")" if scalar(@{$iupac{$l->[3]}}) > 2;
  foreach my $n (@{$iupac{$l->[3]}}){
    return $n if $n ne $l->[2];
  }
  return 'undefined';
}

sub getMinPvalue {
  my($lines) = @_;
  my $p = 1;
  foreach my $l (@{$lines}){
    $p = $l->[11] if $l->[11] < $p;
  }
  return $p;
}
