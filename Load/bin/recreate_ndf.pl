#!/usr/bin/perl

use strict;

use Getopt::Long;

my ($help, $ndfFile, $geneToOligoFile, $outputFile);

&GetOptions('help|h' => \$help,
            'original_ndf_file=s' => \$ndfFile,
            'gene_to_oligo_file=s' => \$geneToOligoFile,
            'output_file=s' => \$outputFile,
            );

if($help) {
  &usage();
}

unless(-e $geneToOligoFile && -e $ndfFile) {
  &usage("Required File does not exist");
}

my %oligoToGene;

open(FILE, $geneToOligoFile) or die "Cannot open file $geneToOligoFile for reading: $!";

while(<FILE>) {
  chomp;

  my ($gene, $oligoString) = split(/\t/, $_);

  my @oligos = split(',', $oligoString);
  foreach(@oligos) {
    $oligoToGene{$_} = $gene;
  }
}
    
close FILE;

open(OUT, "> $outputFile") or die "Cannot open file $outputFile for writing: $!";
open(NDF, $ndfFile) or die "Cannot open file $ndfFile for reading: $!";

my $header = <NDF>;
print OUT $header;

while(<NDF>) {
  chomp;


  my @a = split(/\t/, $_);

  my $probeId = $a[12];

  if(my $geneId = $oligoToGene{$probeId}) {
    $a[4] = $geneId;
  }
  else {
    $a[4] = $probeId;
  }

  print OUT join("\t", @a) . "\n";
}


close NDF;
close OUT;

sub usage {
  my $m = shift;
  print STDERR "ERROR:  ${m}\n" if($m);
  print STDERR "perl recreate_ndf.pl --original_ndf_file <NDF> --gene_to_oligo_file <GENE_TO_OLIGO> --output_file <OUT>\n";
  exit;
}
