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
  my $x = $a[15];
  my $y = $a[16];

  my $alternateId = "${x}-${y}";

  if($oligoToGene{$probeId}) {
    $a[4] = $oligoToGene{$probeId};
  }
  elsif($oligoToGene{$alternateId}) {
    $a[4] = $oligoToGene{$alternateId};
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
