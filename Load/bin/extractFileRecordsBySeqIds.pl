#!/usr/bin/perl

## usage: perl extractRecordsBySeqIds.pl --inFile whole_genome.gff --format gff --listFile B_seq_ids.txt --ifExtract > B_genome.gff

use Getopt::Long;
use strict;

my ($ifExtract, $ifDelete, $inFile, $listFile, $recordLists, $format, $help);

&GetOptions('ifExtract' => \$ifExtract,
	    'ifDelete' => \$ifDelete,
            'help|h' => \$help,
            'inFile=s' => \$inFile,
	    'listFile=s' => \$listFile,
	    'format=s' => \$format,
	    'recordLists=s' => \$recordLists,
           );

&usage() if($help);
&usage("Missing a Required Argument") unless(defined $inFile && ($listFile || $recordLists) && ($ifExtract || $ifDelete) && $format);

my %skipIds;

if ($recordLists) {
  my @items = split (/\;/, $recordLists);
  foreach my $i (0..$#items) {
    $items[$i] =~ s/^\s+//;
    $items[$i] =~ s/\s+$//;
    $skipIds{$items[$i]} = $items[$i];
  }
} elsif ($listFile) {
  print STDERR "\$listFile = $listFile\n";
  open (LIST, $listFile) || die "can not open list file to read.\n";
  while (<LIST>) {
    chomp;
    my $curr = $_;
    $curr =~ s/\s+//g;
    $skipIds{$curr} = $curr;
  }
  close LIST;
} else {
  print STDERR "missing required argument listFile or recordLists\n";
}

foreach my $k (sort keys %skipIds) {
  print STDERR "$k\t$skipIds{$k}\n";
}
my $ifSkip = 0;
open (GB, $inFile) || die "can not open infile to read.\n";
while (<GB>) {
  my $curr = $_;

  if ($format =~ /fasta/i) {
    if ($curr =~ /^>(\S+)/){
      my $seqId = $1;
      #print STDERR "..$seqId..";
      if ($skipIds{$seqId}) {
	$ifSkip = 1;
	print STDERR "process $seqId..\n";
      } else {
	$ifSkip = 0;
      }
    }
  } elsif ($format =~ /gff/i) {
    my @items = split (/\t/, $_);
    if ($skipIds{$items[0]}) {
      $ifSkip = 1;
      #print STDERR "process $items[0]..\n";
    } else {
      $ifSkip = 0;
    }
  } else {
    print STDERR "format does not config yet\n";
  }

#  print $curr if ($ifSkip == 0 && $ifDelete);
  if ($ifDelete) {
    print $curr if ($ifSkip == 0);
  } elsif ($ifExtract) {
    print $curr if ($ifSkip == 1);
  }
}
close GB;


sub usage {
  die
"
Usage: perl extractRecordsBySeqIds.pl --inFile whole_genome.gff --format gff --listFile B_seq_ids.txt --ifExtract > B_genome.gff

where
  --inFile:  the name of input file
  --format:  the format of input file
  --listFile:    the list of LOCUS IDs that need to be extracted or deleted from genbank file, one ID per line
  --recordLists:   semicolon delimited list of records that want to delete or extract
  --ifExtract:   if present, extract the records in the listFile from the genbank file
  --ifDelete:    if present, delete the records in the listFile from the genbank file 
";
}
