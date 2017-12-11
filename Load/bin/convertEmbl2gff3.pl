#!/usr/bin/perl

use strict;
use FileHandle;

## a script to convert embl format to a standard gff3 format
## the embl file contains CDS, tRNA, ncRNA, rRNA only, no gene and exon feature

## usage: convertEmbl2gff3.pl $inputEmblFile $outputGffFile $outputFastaFile

my ($input, $gffOutput, $fastaOutput) = @ARGV;

my $gff = FileHandle->new();
$gff->open (">$gffOutput") || die "can not open gffOutput file to write\n";

$gff->print ("##gff-version 3\n");
$gff->print ("##date-created at ".localtime()."\n");

my ($ifSeqStart, $seqName, %seqs, %geneStart, %geneEnd,
    $id, $product, $ifPseudo, $geneId, $transId,
    @exonPairs,
    @tagValuePair,
    %ifPartial,
    %geneIds,
    %transIds,
    %geneStrand,
    %transType,
    %tagValuePairs,
    $strand,
    $transType,
    $exonType,
    $seq,
    %transStart, %transEnd);

my $cdsCt = 1;
open (IN, $input) || die "can not open input file to read.\n";

my @inLines;
while (<IN>) {
  chomp;
  push (@inLines, $_);
}
close IN;

OUTER: foreach my $i (0..$#inLines) {

  my @items = split (/\s+/, $inLines[$i]);

#  print STDERR "$items[0], $items[1], $items[2],\n";

  if ($items[0] eq "ID") {
    $seqName = $items[1];
    $seqName =~ s/\;+$//;
  } elsif ($items[0] eq "FT") {

    if ($items[1] eq "CDS"
        || $items[1] eq "tRNA"
        || $items[1] eq "rRNA"
        || $items[1] eq "ncRNA"
       ) {


      ## print the previous if $cdsCt > 1;
      if ($cdsCt > 1) {
	foreach my $exonPair (@exonPairs) {
	  if ($exonPair =~ /\>/ || $exonPair =~ /\</) {
	    $exonPair =~ s/\>//;
	    $exonPair =~ s/\<//;
	    $ifPartial{$transId} = 1;
	  }
	  my @cols;
	  $cols[0] = $seqName;
	  $cols[1] = "chado";
	  $cols[2] = $exonType;
	  ($cols[3], $cols[4]) = split (/\.\./, $exonPair);
	  $cols[4] = $cols[3] if (!$cols[4]); ## for some error in embl file that missing eithe exon start or exon end
	  $cols[5] = ".";
	  $cols[6] = $strand;
	  $cols[7] = 0;  ## set to 0 here because all codon_start=1 in testing embl file
	                 ## TODO, need to equal to codon_start-1
	  $cols[8] = "Parent \"".$transId."\"";

	  &printGff3Column ($gff, \@cols);

	  ## set geneStart and geneEnd
	  $geneStart{$geneId} = ($geneStart{$geneId}) ? getMin($geneStart{$geneId}, $cols[3], $cols[4]) : getMin($cols[3], $cols[4]);
	  $geneEnd{$geneId} = ($geneEnd{$geneId}) ? getMax($geneEnd{$geneId}, $cols[3], $cols[4]) : getMax($cols[3], $cols[4]);

	  ## set transStart and transEnd
	  $transStart{$transId} = ($transStart{$geneId}) ? getMin($transStart{$transId}, $cols[3], $cols[4]) : getMin($cols[3], $cols[4]);
	  $transEnd{$transId} = ($transEnd{$geneId}) ? getMax($transEnd{$transId}, $cols[3], $cols[4]) : getMax($cols[3], $cols[4]);

	  ## assign transType
	  $transType{$transId} = $transType;

	  ## assign geneStrand
	  $geneStrand{$geneId} = $strand;
	}
	## assign tagValuePair
	push (@{$tagValuePairs{$transId}}, @tagValuePair);
      }

      ## intial values
      @tagValuePair = ();
      @exonPairs = ();
      $transType = "";

      ## read the currents
      ## check if it is the end of coordinates
      $transType = ($items[1] eq "CDS" ) ? "mRNA" : "$items[1]";
      $exonType = ($items[1] eq "CDS") ? "CDS" : "exon";

      print STDERR "before, $items[2]\n";
      while ($inLines[$i+1] !~ /^FT\s+\//) {
	$i++;
	$inLines[$i] =~ s/FT\s+//;
	$items[2] .= $inLines[$i];
      }
      print STDERR "after, $items[2]\n";

      $strand = ($items[2] =~ /^complement/) ? "-" : "+";
      $items[2] =~ s/complement//;
      $items[2] =~ s/join//;
      $items[2] =~ s/\(+//g;
      $items[2] =~ s/\)+//g;
      @exonPairs = split (/\,/, $items[2]);

      $cdsCt++;

      next OUTER;

    } elsif ($items[1] =~ /^\//) {
      my @tags = split (/\=/, $items[1]);
      $tags[0] =~ s/^\///;

      if ($tags[0] eq "locus_tag" || $tags[0] eq "ID") {
	$tags[1] =~ s/\"//g;
	if ($tags[1] =~ /\.\d$/) {
	  $geneId = $tags[1];
	  $geneId =~ s/\.\d$//;
	  $transId = $tags[1];
	} else {
	  $geneId = $tags[1];
	  $transId = $tags[1] . ".1";
	}
	$geneIds{$geneId} = $geneId;
	$transIds{$transId} = $transId;

      } else {
	$inLines[$i] =~ s/FT\s+\///g;
	my ($t, $v) = split (/\=/, $inLines[$i]);

	while ($t =~ /product/i
	       && $inLines[$i] !~ /\"$/
	       && $inLines[$i+1] !~ /^FT\s+\//
	      ) {
	  $i++;
	  $inLines[$i] =~ s/FT\s+//;
	  $v .= $inLines[$i];
	}

	push (@tagValuePair, "$t $v") if ($t !~ /codon_start/ && $t !~ /estimated_length/);

	next OUTER;
      }
    }
  } elsif ($items[0] eq "SQ") {
    $ifSeqStart = 1;

    ## print the last cds
#     if ($cdsCt > 1) {
	foreach my $exonPair (@exonPairs) {
	  if ($exonPair =~ /\>/) {
	    $exonPair =~ s/\>//;
	    $ifPartial{$transId} = 1;
	  }
	  my @cols;
	  $cols[0] = $seqName;
	  $cols[1] = "chado";
	  $cols[2] = $exonType;
	  ($cols[3], $cols[4]) = split (/\.\./, $exonPair);
	  $cols[5] = ".";
	  $cols[6] = $strand;
	  $cols[7] = 0;  ## set to 0 here because all codon_start=1 in testing embl file
	                 ## TODO, need to equal to codon_start-1
	  $cols[8] = "Parent \"".$transId."\"";

	  &printGff3Column ($gff, \@cols);

	  ## set geneStart and geneEnd
	  $geneStart{$geneId} = ($geneStart{$geneId}) ? getMin($geneStart{$geneId}, $cols[3], $cols[4]) : getMin($cols[3], $cols[4]);
	  $geneEnd{$geneId} = ($geneEnd{$geneId}) ? getMax($geneEnd{$geneId}, $cols[3], $cols[4]) : getMax($cols[3], $cols[4]);

	  ## set transStart and transEnd
	  $transStart{$transId} = ($transStart{$geneId}) ? getMin($transStart{$transId}, $cols[3], $cols[4]) : getMin($cols[3], $cols[4]);
	  $transEnd{$transId} = ($transEnd{$geneId}) ? getMax($transEnd{$transId}, $cols[3], $cols[4]) : getMax($cols[3], $cols[4]);

	  ## assign transType
	  $transType{$transId} = $transType;

	  ## assign geneStrand
	  $geneStrand{$geneId} = $strand;
	}
        ## assign tagValuePair
        push (@{$tagValuePairs{$transId}}, @tagValuePair);
 #     }

  } elsif ($items[0] =~ // && $ifSeqStart == 1) {
    $inLines[$i] =~ s/\d+//g;
    $inLines[$i] =~ s/\s+//g;

#    $seqs{$seqName} .= $inLines[$i];
    $seq .= "$inLines[$i]\n" if ($inLines[$i] !~ //);
  } else {
    next;
  }

}

## print gene line
foreach my $k (sort keys %geneIds) {
  my @items;
  $items[0] = $seqName;
  $items[1] = "chado";
  $items[2] = "gene";
  $items[3] = $geneStart{$k};
  $items[4] = $geneEnd{$k};
  $items[5] = ".";
  $items[6] = $geneStrand{$k};
  $items[7] = ".";
  $items[8] = "ID \"$geneIds{$k}\";";
  &printGff3Column ($gff, \@items);
}

## print the transcript line if it is not in the file
foreach my $k (sort keys %transIds) {
#  if (!$hasTransLine{$k}) {
    my $key4gene = $k;
    $key4gene =~ s/\.\d+$//;

    my @items;
    $items[0] = $seqName;
    $items[1] = "chado";
    $items[2] = $transType{$k};
    $items[3] = $transStart{$k};
    $items[4] = $transEnd{$k};
    $items[5] = ".";
    $items[6] = $geneStrand{$key4gene};
    $items[7] = ".";
    $items[8] = "ID \"$transIds{$k}\"; Parent \"$geneIds{$key4gene}\";";

    foreach my $tagVal (@{$tagValuePairs{$k}}) {
      $items[8] .= " " . $tagVal . ";";
    }
    &printGff3Column ($gff, \@items);
#  }
}
close GFF;


## output fasta sequence file
open (FAS, ">$fastaOutput") || die "can not open output file to write\n";
print FAS ">$seqName\n";
print FAS "$seq\n";
close FAS;


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
#  my $fileH = shift;
#  my $array = shift;
  my ($fileH, $array) = @_;
  foreach my $i (0..$#{$array}) {
    ($i == 8) ? $fileH->print ("$array->[$i]\n") : $fileH->print ("$array->[$i]\t");
  }
  return 0;
}
