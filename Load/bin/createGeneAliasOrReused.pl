#!/usr/bin/perl

use strict;
use lib "$ENV{GUS_HOME}/lib/perl";
use Bio::SeqIO;
use Getopt::Long;

use Data::Dumper;
use FileHandle;
use HTTP::Date;

use DBI;
use DBD::Oracle;
use CBIL::Util::PropertySet;
use Bio::SeqIO;
use Bio::Location::Simple;
use ApiCommonData::Load::BioperlTreeUtils qw{makeBioperlFeature};
use Bio::Seq::SeqBuilder;
use Bio::Species;
use Bio::Annotation::SimpleValue;

my ($date, ) = split(" ", HTTP::Date::time2iso());
$date = join("",split(/-/,$date));

my ($help, $oldTranscriptFile, $oldAnnotationFile, $oldAnnotationFormat, $newAnnotationFile, $newAnnotationFormat, $oldFastaFile, $newFastaFile, $seqIdAliasFile, $ifAlias, $ifReused);

&GetOptions('help|h' => \$help,
	    'oldTranscriptFile=s' => \$oldTranscriptFile,
	    'oldAnnotationFile=s' => \$oldAnnotationFile,
	    'oldFastaFile=s' => \$oldFastaFile,
	    'oldAnnotationFormat=s' => \$oldAnnotationFormat,
	    'newAnnotationFile=s' => \$newAnnotationFile,
	    'newFastaFile=s' => \$newFastaFile,
	    'newAnnotationFormat=s' => \$newAnnotationFormat,
	    'seqIdAliasFile=s' => \$seqIdAliasFile,
	    'ifAlias' => \$ifAlias,
	    'ifReused' => \$ifReused,
           );

&usage() if($help);

&usage("Missing a Required Argument") unless (defined ($newAnnotationFile && $oldAnnotationFile && ($ifAlias || $ifReused) ));


my ($oldSeqId, $oldGeneStart, $oldGeneEnd, $oldGeneStrand) = ($oldAnnotationFormat =~ /gff/i) ? getGeneInfoFromGff3 ($oldAnnotationFile) : getGeneInfoFromGenbank ($oldAnnotationFile);

my ($newSeqId, $newGeneStart, $newGeneEnd, $newGeneStrand) = ($newAnnotationFormat =~ /gff/i) ? getGeneInfoFromGff3 ($newAnnotationFile) : getGeneInfoFromGenbank ($newAnnotationFile);

my ($oldSeqs) = ($oldAnnotationFormat =~ /genbank/i) ? getSeqsFromGenbank ($oldAnnotationFile) : getSeqsFromFasta ($oldFastaFile);

my ($newSeqs) = ($newAnnotationFormat =~ /genbank/i) ? getSeqsFromGenbank ($newAnnotationFile) : getSeqsFromFasta ($newFastaFile);

my %seqAlias;
open (IN, "$seqIdAliasFile") || die "can not open seqIdAliasFiel to read\n";
while (<IN>) {
  chomp;
  my @items = split (/\t/, $_);
  $seqAlias{$items[0]} = $items[1] if ($items[0] && $items[1]);
}
close IN;

#foreach my $k (sort keys %{$oldSeqId}) { 
#  print STDERR "old seq id $k = $oldSeqId->{$k}\n";
#}
#foreach my $k (sort keys %{$newSeqId}) {
#  print STDERR "new seq id $k = $newSeqId->{$k}\n";
#}

my $outputFile = "mapping.out";
if ($ifAlias) {
  $outputFile = "aliases_". $outputFile;
} elsif ($ifReused) {
  $outputFile = "reused_gene_". $outputFile;
}

open (OUT, ">$outputFile") || die "can not open output file to write\n";

foreach my $k (sort keys %{$newGeneStart}) {
  foreach my $ko (sort keys %{$oldGeneStart}) {
    if ($seqAlias{$newSeqId->{$k}} eq $oldSeqId->{$ko}) {
      if ($newGeneStart->{$k} == $oldGeneStart->{$ko}) {
	if ($newGeneEnd->{$k} == $oldGeneEnd->{$ko} ) {
	  ## if old id in new id, then reused gene
	  ## otherwise is retired gene, write to alias file 
	  #($newGeneStart->{$ko} ) ? print RU "100, $k, $ko\n" : print AS "100, $k, $ko\n" if ($k ne $ko);
	  if ($ifReused) {
	    print OUT "$k\t$ko\n" if ($newGeneStart->{$ko} && ($k ne $ko));
	  } elsif ($ifAlias) {
	    print OUT "$k\t$ko\n" if (!$newGeneStart->{$ko} && ($k ne $ko));
	  } else {
	    die "miss required argument --ifReused or --isAlias\n";
	  }
	} else {
	  #($newGeneStart->{$ko} ) ? print RU "50, $k, $ko, new = $newGeneStart->{$k}..$newGeneEnd->{$k}, old = $oldGeneStart->{$ko}..$oldGeneEnd->{$ko}\n" : print AS "50, $k, $ko, new = $newGeneStart->{$k}..$newGeneEnd->{$k}, old = $oldGeneStart->{$ko}..$oldGeneEnd->{$ko}\n" if ($k ne $ko);
          if ($ifReused) {
            print OUT "$k\t$ko\n" if ($newGeneStart->{$ko} && ($k ne $ko));
          } elsif ($ifAlias) {
            print OUT "$k\t$ko\n" if (!$newGeneStart->{$ko} && ($k ne $ko));
          } else {
            die "miss required argument --ifReused or --isAlias\n";
          }
	}
      } else {
	if ($newGeneEnd->{$k} == $oldGeneEnd->{$ko} ) {
	  #($newGeneStart->{$ko} ) ? print RU "50, $k, $ko, new = $newGeneStart->{$k}..$newGeneEnd->{$k}, old = $oldGeneStart->{$ko}..$oldGeneEnd->{$ko}\n" : print  AS "50, $k, $ko, new = $newGeneStart->{$k}..$newGeneEnd->{$k}, old = $oldGeneStart->{$ko}..$oldGeneEnd->{$ko}\n" if ($k ne $ko);
          if ($ifReused) {
            print OUT "$k\t$ko\n" if ($newGeneStart->{$ko} && ($k ne $ko));
          } elsif ($ifAlias) {
            print OUT "$k\t$ko\n" if (!$newGeneStart->{$ko} && ($k ne $ko));
          } else {
            die "miss required argument --ifReused or --isAlias\n";
          }

	}
      }
    }
  }
}

###########

sub getGeneInfoFromGenbank {
  my ($inputFile) = @_;
  my (%seqId, %geneStart, %geneEnd, %geneStrand);

  my $bioperlSeqIO = Bio::SeqIO->new(-format => 'genbank',
				     -file => $inputFile);
  while (my $seq = $bioperlSeqIO->next_seq() ) {
    my $sId = ($seq->id) ? ($seq->id) : ($seq->accession());
    my @seqFeatures = $seq->get_SeqFeatures;
    foreach my $feature (@seqFeatures) {
      my $type = $feature->primary_tag();
      if ($type eq "gene" || $type eq "pseudogene") {
	my ($geneId) = $feature->get_tag_values('locus_tag');
	if ($geneId) {
	  $seqId{$geneId} = $sId;
	  $geneStart{$geneId} = $feature->location->start;
	  $geneEnd{$geneId} = $feature->location->end;
	  $geneStrand{$geneId} = $feature->location->strand;
	   print STDERR "process pro $geneId...$seqId{$geneId}\n";
	}
      }
    }
  }
  return (\%seqId, \%geneStart, \%geneEnd, \%geneStrand);
}

sub getGeneInfoFromGff3 {
  my ($inputFile) = @_;
  my (%seqId, %geneStart, %geneEnd, %geneStrand);
  open (IN, $inputFile) || die "can not open inputFile to read\n";
  while (<IN>) {
    chomp;
    my @items = split (/\t/, $_);
    if ($items[2] eq "gene") {
      if ($items[8] =~ /ID \"(\S+?)\"/) {
	my $id = $1;
	$seqId{$id} = $items[0];
	$geneStart{$id} = $items[3];
	$geneEnd{$id} = $items[4];
	$geneStrand{$id} = ($items[6] eq "-") ? "-1" : "1";
	  print STDERR "GFF3 process pro $id...$seqId{$id}\n";
      }
    }
  }
  close IN;
  return (\%seqId, \%geneStart, \%geneEnd, \%geneStrand);
}

sub getSeqsFromFasta {
  my ($inputFile) = @_;
  my ($sId, %seqs);

  open (IN, "$inputFile") || die "can not open inputFile to read\n";
  while (<IN>) {
    chomp;
    if ($_ =~ /^>(\S+?)\s+/) {
      $sId = $1;
      print STDERR "duplicated sourceId $sId in the file $inputFile\n" if ($seqs{$sId});
    } else {
      my $curr = $_;
      $curr =~ s/\s+//g;
      $curr =~ s/\n//g;
      $seqs{$sId} .= uc($curr);
    }
  }
  close IN;
  return (\%seqs);
}

sub getSeqsFromGenbank {
  my ($inputFile) = @_;
  my (%seqs);

  my $bioperlSeqIO = Bio::SeqIO->new(-format => 'genbank',
				     -file => $inputFile);
  while (my $seq = $bioperlSeqIO->next_seq() ) {
    my $sId = ($seq->id) ? ($seq->id) : ($seq->accession());
    $seqs{$sId} = uc($seq->seq()) if ($sId && $seq->seq());
  }
  return (\%seqs);
}

sub readFromDatabase {
  my ($sql, $dbh) = @_;
  my $stmt = $dbh->prepare($sql);
  $stmt->execute;
  my (@arrays);
  while (my @fetchs = $stmt->fetchrow_array()) {
    my $oneline;
    foreach my $i (0..$#fetchs) {
      $oneline .= "$fetchs[$i] ";
    }
    push @arrays, $oneline;
  }
  $stmt->finish();
  return \@arrays;
}

sub usage {
  die
"
A script to use gene location to compare the gene IDs in the current annotation with the previous annotation,
generate an gene aliases file or a mapping file that has previous gene IDs been reused in current annotation

The standard output file is mapping.out

Usage: createGeneAliasOrReused.pl --oldAnnotationFile pre.genome.gff --oldFastaFile pre.genome.fasta --oldAnnotationFormat gff3 
             --newAnnotationFile curr.genome.gbf --newAnnotationFormat genbank --seqIdAliasFile seqAliasesFile.txt --ifReused

where
	    --ifAlias: optional, either ifAlias or ifReused
	    --ifReused: optional, either ifReused or ifAlias
	    --seqIdAliasFile: sequence alises file
	    --oldAnnotationFile: old annotation file name
	    --oldFastaFile: old genome sequence file name, fasta foramt
	    --oldAnnotationFormat: old annotation file format
	    --newAnnotationFile: new annotation file name
	    --newFastaFile: new genome sequence file name, fasta format
	    --newAnnotationFormat: new annotation file format

";
}


