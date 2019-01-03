#!/usr/bin/perl

## usage: perl addGenbankProteinSeq2Gff3.pl --genbankFile genome.gbf --gffFile whole_genome.gff.orig > whole_genome.gff
## take protein sequences in genbank file, then put into gff3 file, based on the protein_id tag

use strict;
use Getopt::Long;
use Bio::SeqFeature::Generic;
use ApiCommonData::Load::AnnotationUtils qw{getSeqIO};

my ($genbankFile, $gffFile, $help);

&GetOptions('genbankFile=s' => \$genbankFile,
            'gffFile=s' => \$gffFile,
            'help|h' => \$help,
           );

&usage() if($help);
&usage("Missing a Required Argument") unless(defined $genbankFile && $gffFile);

my (%protId2Transl, %locusTag2ProtId);
my ($c, $c2);

my $seqIn = Bio::SeqIO->new ('-file' => "<$genbankFile", '-format' => 'genbank');

while (my $seq = $seqIn->next_seq() ) {

  foreach my $bioperlFeature ($seq->get_SeqFeatures()) {
    my $type = $bioperlFeature->primary_tag();

    if ($type eq "CDS") {
      if ($bioperlFeature->has_tag("protein_id") && $bioperlFeature->has_tag("translation")) {
	my ($key) = $bioperlFeature->get_tag_values("protein_id");
	my ($translation) = $bioperlFeature->get_tag_values("translation");
	$protId2Transl{$key} = $translation;
	#print STDERR ">$key\n$translation\n" if ($c < 10);
	$c++;
      }
    }
  }
}

open (GFF, $gffFile) || die "can not open gff file to read\n";
while (<GFF>) {
  chomp;
  my @items = split (/\t/, $_);
  if ($items[2] eq "CDS") {
    if ($items[8] =~ /Parent \"(\S+?)\";.+protein_id \"(\S+?)\";/) {
      my $key = $1;
      my $val = $2;
      #print STDERR ">$1..$2\n" if ($c2 < 10);
      $locusTag2ProtId{$key} = $val if ($key && $val);
      $c2++;
    }
  }
}
close GFF;

open (GF, $gffFile) || die "can not open gff file to read\n";
while (<GF>) {
  chomp;
  my @items = split (/\t/, $_);
  if ($items[2] eq "mRNA") {
    if ($items[8] =~ /ID \"(\S+?)\";/) {
      my $id = $1;
      if ($locusTag2ProtId{$id} && $protId2Transl{$locusTag2ProtId{$id}}) {
	$items[8] .= "translation \"".$protId2Transl{$locusTag2ProtId{$id}}."\";";
      }
    }
  }
  &printGff3Column (\@items);
}
close GF;

###########

sub printGff3Column {
  my $array = shift;
  foreach my $i (0..$#{$array}) {
    ($i == 8) ? print "$array->[$i]\n" : print "$array->[$i]\t";
  }
  return 0;
}


sub usage {
  die
"
Usage: perl addGenbankProteinSeq2Gff3.pl --genbankFile genome.gbf --gffFile whole_genome.gff.orig > whole_genome.gff

where
  --genbankFile: required, the genbank file name that has translation
  --gffFile: required, the gff file name that wants to add translation sequence

";
}

