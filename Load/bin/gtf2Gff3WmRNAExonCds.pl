#!/usr/bin/perl

use strict;

## a script to convert annotation from Gtf format to standard gff3 format
## the gtf file contains mRNA, exon, and CDS

## usage: gtf2Gff3WmRNAExonCds.pl MacaM_Rhesus_Genome_Annotation_v7.8.2.gtf MMUL > whole_genome.gff
## MMUL is the prefix that want to add in the gene ID

my ($input, $gIdPrefix) = @ARGV;

print "##gff-version 3\n";
print "##date-created at ".localtime()."\n";


my (%geneIds, %transIds, $lineCtr);
open (IN, $input) || die "can not open input file to read.\n";
while (<IN>) {
  $lineCtr++;
  ## grep the gene_id and transId for current line
  my ($transKey, $gid, $tid);
  if($_ =~ /\tgene_id \"(\S+)\"\;.* transcript_id \"(\S+)\"\;/) {
    $geneIds{$1} = $gIdPrefix."_".$1;
    $transKey = $1."-".$2;
    $transIds{$transKey} = $geneIds{$1}.".".$2;
#    $transIds{$transKey} =~ s/_transcript_/\_/;
  } else {
    die "Can not find either gene_id or transcript_id at the line $lineCtr\n";
  }
}
close IN;

q{
foreach my $k (sort keys %geneIds) {
  print STDERR "$k, $geneIds{$k}\n";
}
foreach my $kk (sort keys %transIds) {
  print STDERR "  $kk, $transIds{$kk}\n";
}
};

my (%geneStarts, %geneEnds, %geneSeqId, %geneSource, %geneStrand, %ctrs, 
    %hasTransLine, %transStarts, %transEnds, %transSeqId, %transSource, %transStrand);

open (INN, $input) || die "can not open input file to read.\n";
while (<INN>) {
  chomp;

  ## skip the comment line(s)
  next if ($_ =~ /^\#/); 

  my @elems = split (/\t/, $_);

  if($elems[8] =~ /gene_id \"(\S+)\"\;.* transcript_id \"(\S+)\"\;/) {

    my $currentGeneId = $1;
    my $currentTransId = $2;
    my $curTransKey = $currentGeneId."-".$currentTransId;

    my ($id, $parent);
    if ($elems[2] =~ /mRNA/) {
      $id = $transIds{$curTransKey};   ## the transcript ID 
      $parent  = $geneIds{$currentGeneId};   ## the gene ID
#      print STDERR "\$id = $id, \$parent = $parent\n";

      $hasTransLine{$curTransKey} = 1;  ## assign if there is a transcript line in the file 
    } else {
      $ctrs{$curTransKey}{$elems[2]}++;
      $id = $transIds{$curTransKey}.":".$elems[2].":".$ctrs{$curTransKey}{$elems[2]};
      $parent = $transIds{$curTransKey};
    }

    ## grep gene and transcript info in the case there is no gene or transcript line in the annotation
    if ($elems[2] =~ /exon/) {
      ## geneStart and geneEnd
      $geneStarts{$currentGeneId} = ($geneStarts{$currentGeneId}) ? 
	getMin ($elems[3], $elems[4], $geneStarts{$currentGeneId}) : getMin($elems[3], $elems[4]);
      $geneEnds{$currentGeneId} = ($geneEnds{$currentGeneId}) ? 
	getMax($elems[3], $elems[4], $geneEnds{$currentGeneId}) : getMax($elems[3], $elems[4]);

      ## other gene info
      $geneSeqId{$currentGeneId} = $elems[0];
      $geneSource{$currentGeneId} = $elems[1];
      $geneStrand{$currentGeneId} = $elems[6];

      ## transStart and transEnd
      $transStarts{$curTransKey} = ($transStarts{$curTransKey}) ? 
	getMin ($elems[3], $elems[4], $transStarts{$curTransKey}) : getMin($elems[3], $elems[4]);
      $transEnds{$curTransKey} = ($transEnds{$curTransKey}) ? 
	getMax($elems[3], $elems[4], $transEnds{$curTransKey}) : getMax($elems[3], $elems[4]);

      ## other trans info
      $transSeqId{$curTransKey} = $elems[0];
      $transSource{$curTransKey} = $elems[1];
      $transStrand{$curTransKey} = $elems[6];
      print STDERR "Wrong strand for $currentGeneId in $currentTransId\n" unless ($elems[6] eq $geneStrand{$currentGeneId});
#      print STDERR "Wrong strand for $currentGeneId in $currentTransId\n" if ($transIds{$curTransKey} eq "MMUL_10313.RTN3_01");
    }

    $elems[8] = "ID \"$id\"; Parent \"$parent\"; ".$elems[8];
  }
  &printGff3Column (\@elems);

}
close INN;


## print gene line
foreach my $k (sort keys %geneIds) {
  my @items;
  $items[0] = $geneSeqId{$k};
  $items[1] = $geneSource{$k};
  $items[2] = "gene";
  $items[3] = $geneStarts{$k};
  $items[4] = $geneEnds{$k};
  $items[5] = "100";
  $items[6] = $geneStrand{$k};
  $items[7] = ".";
  $items[8] = "ID \"$geneIds{$k}\";";
  &printGff3Column (\@items);
}

## print the transcript line if it is not in the file
foreach my $k (sort keys %transIds) {
  if (!$hasTransLine{$k}) {
    my @items;
    $items[0] = $transSeqId{$k};
    $items[1] = $transSource{$k};
    $items[2] = "mRNA";
    $items[3] = $transStarts{$k};
    $items[4] = $transEnds{$k};
    $items[5] = "100";
    $items[6] = $transStrand{$k};
    $items[7] = ".";
    my $key4gene = $k;
    $key4gene =~ s/\-.+$//;
    $items[8] = "ID \"$transIds{$k}\"; Parent \"$geneIds{$key4gene}\";";
    &printGff3Column (\@items);
  }
}

##################

sub getMax {
    my @array = @_;

    my @sortedArray = sort {$a <=> $b} @array;
    return $sortedArray[-1];
}

sub getMin {
    my @array = @_;
    my @sortedArray = sort {$a <=> $b} @array;
    return $sortedArray[0];
}

sub printGff3Column {
  my $array = shift;
  foreach my $i (0..$#{$array}) {
    ($i == 8) ? print "$array->[$i]\n" : print "$array->[$i]\t";
  }
  return 0;
}
