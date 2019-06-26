#!/usr/bin/perl

use strict;
use Getopt::Long;


my ($verbose, $help, $inputGffFile, $outputGffFile, $proteinFile, $idSuffix, $translTable);

&GetOptions('help|h' => \$help,
            'inputGffFile=s' => \$inputGffFile,
            'proteinFile=s' => \$proteinFile,
            'idSuffix=s' => \$idSuffix,
            'translTable=s' => \$translTable,
           );

&usage() if($help);

&usage("Missing Required Arguments") unless (defined ($inputGffFile && $proteinFile) );


my (%proteins, $seqId, %translTables);

open (IN, $proteinFile) || die "can not open proteinFile file to read.\n";
while (<IN>) {
  chomp;
  next if ($_ =~ /^\s*$/);

  if ($_ =~ /^\>(\S+)/) {
    $seqId = $1;

    ## for protein sequence from VectorBase, it uses proetin ID instead of transcript ID
    ## need to replace protein ID with transcript ID
    $seqId =~ s/\-P(\w)$/\-R$1/;

    if ($idSuffix) {
      $seqId .= $idSuffix;
    }

    ## some protein sequence files have translated table info at the defline
    if ($_ =~ /translated using codon table (\d+)/) {
      $translTables{$seqId} = $1;
      #print STDERR "\$translTable = $translTable\n";
    }
  } else {
    $proteins{$seqId} .= $_;
  }
}
close IN;

open (INN, $inputGffFile) || die "can not open inputGffFile to read\n";
while (<INN>) {
  chomp;
  my @items = split (/\t/, $_);
  #$items[2] = "gene" if ($items[2] eq "CDS");  ## only need with special case
  #$items[8] =~ s/cds_//;  ## only need with special case
  if ($items[2] eq 'mRNA') {
    if ($items[8] =~ /ID \"(\S+?)\"/) {
#    if ($items[8] =~ /Parent \"(\S+?)\"/) {  ## for these protein sequences named by gene ID
      $items[8] .= "transl_table \"$translTable\"\;" if ($translTable);
      $items[8] .= "transl_table \"$translTables{$1}\"\;" if ($translTables{$1});
      $items[8] .= "translation \"$proteins{$1}\"\;";
    }
  }

  foreach my $i (0..8) {
    ($i == 8) ? print "$items[$i]\n" : print "$items[$i]\t";
  }
}
close INN;


sub usage {
  die
"
A script to add protein sequence to a gff file
Usage:

addProteinSeqs2GffFile.pl --inputGffFile whole_genome.gff.prev --proteinFile C_albicans_SC5314_version_A22-s07-m01-r59_orf_trans_all.fasta --idSuffix -T > whole_genome.gff

where
  --inputGffFile: required, the input gff file name
  --proteinFile: required, the protein file name
  --idSuffix: transcript Ids in the gff file have a id Suffix compare to the gene Ids in the protein file
  --translTable: the translation table for sepecial organism

";
}

