#!/usr/bin/perl

use strict;
use Getopt::Long;


my ($verbose, $help, $inputGffFile, $outputGffFile, $proteinFile, $idSuffix, $idPrefix, $translTable, $ifRemove, $ifProteinIdInCds);

&GetOptions('help|h' => \$help,
            'inputGffFile=s' => \$inputGffFile,
            'proteinFile=s' => \$proteinFile,
            'idSuffix=s' => \$idSuffix,
            'idPrefix=s' => \$idPrefix,
            'translTable=s' => \$translTable,
            'ifRemove=s' => \$ifRemove,
            'ifProteinIdInCds=s' => \$ifProteinIdInCds,
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

    if ($ifRemove =~ /^T/i) {
      $seqId =~ s/$idSuffix// if ($idSuffix);
      $seqId =~ s/$idPrefix// if ($idPrefix);

    } else {
      $seqId .= $idSuffix if ($idSuffix);
      $seqId = $idPrefix . $seqId if ($idPrefix);
    }
#    print STDERR "\$seqId = $seqId, ";

    ## some protein sequence files have translated table info at the defline
    if ($_ =~ /translated using codon table (\d+)/) {
      $translTables{$seqId} = $1;
      #print STDERR "\$translTable = $translTable\n";
    }
  } else {
    $_ =~ s/^\s+//;
    $_ =~ s/\s+$//;
    $proteins{$seqId} .= $_;
  }
}
close IN;

## remove stop codon if exist
foreach my $k (sort keys %proteins) {
  $proteins{$k} =~ s/\*$//;
}

## for the case protein_id is in cds feature
my %t2p;
if ($ifProteinIdInCds =~ /^T/i) {
  open (GFF, $inputGffFile) || die "can't open inputGffFile to read\n";
  while (<GFF>) {
    my @items = split (/\t/, $_);
    if ($items[2] =~ /cds/i) {
      if ($items[8] =~ /Parent \"(\S+?)\";.*protein_id \"(\S+?)\";/) {
	$t2p{$1} = $2;
      } elsif ($items[8] =~ /Parent=(\S+?);.*protein_id=(\S+?);/) {
	$t2p{$1} = $2;
      }
    }
  }
  close GFF;
}


open (INN, $inputGffFile) || die "can not open inputGffFile to read\n";
while (<INN>) {
  chomp;
  if ($_ =~ /^\#/) {
    print "$_\n";
    next;
  }

  my @items = split (/\t/, $_);
  #$items[2] = "gene" if ($items[2] eq "CDS");  ## only need with special case
  #$items[8] =~ s/cds_//;  ## only need with special case
  if ($items[2] eq 'mRNA') {
    if ($items[8] =~ /ID \"(\S+?)\"/) {
#    if ($items[8] =~ /Parent \"(\S+?)\"/) {  ## for these protein sequences named by gene ID
      $items[8] .= "transl_table \"$translTable\"\;" if ($translTable);
      $items[8] .= "transl_table \"$translTables{$1}\"\;" if ($translTables{$1});
      $items[8] .= "translation \"$proteins{$1}\"\;" if ($proteins{$1});
      $items[8] .= "translation \"$proteins{$t2p{$1}}\"\;" if ($proteins{$t2p{$1}});
    } elsif ($items[8] =~ /ID=(\S+?);/) {
#    if ($items[8] =~ /Parent=(\S+?);/) {  ## for these protein sequences named by gene ID
      $items[8] .= "\;transl_table=$translTable" if ($translTable);
      $items[8] .= "\;transl_table=$translTables{$1}" if ($translTables{$1});
      $items[8] .= "\;translation=$proteins{$1}" if ($proteins{$1});
      $items[8] .= "\;translation=$proteins{$t2p{$1}}" if ($proteins{$t2p{$1}});
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

addProteinSeqs2GffFile.pl --inputGffFile whole_genome.gff.prev --proteinFile C_albicans_SC5314_version_A22-s07-m01-r59_orf_trans_all.fasta --idSuffix -T --ifProteinIdInCds true > whole_genome.gff

where
  --inputGffFile: required, the input gff file name
  --proteinFile: required, the protein file name
  --idSuffix: transcript Ids in the gff file have a id Suffix compare to the gene Ids in the protein file
  --idPrefix: transcript Ids in the gff file have a id Prefix compare to the gene Ids in the protein file
  --translTable: the translation table for sepecial organism
  --ifRemove: required, compare the transcript IDs in the GFF file with those in the protein file,
              if the IDs in the protein file contain a prefix or suffix not present in the GFF, set ifRemove = True, otherwise set ifRemove = false
  --ifProteinIdInCds: true of false. Set as true when the protein_id only present in CDS feature, and matches as ID in the protein sequence file

";
}

