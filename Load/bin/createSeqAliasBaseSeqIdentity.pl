#!/usr/bin/perl

use Bio::SeqIO;
use Getopt::Long;
use strict;


my ($help, $oldSequenceFile, $oldSequenceFormat, $newSequenceFile, $newSequenceFormat);

&GetOptions('help|h' => \$help,
            'oldSequenceFile=s' => \$oldSequenceFile,
            'oldSequenceFormat=s' => \$oldSequenceFormat,
            'newSequenceFile=s' => \$newSequenceFile,
            'newSequenceFormat=s' => \$newSequenceFormat,
           );

&usage() if($help);
&usage("Missing a Required Argument") unless (defined ($oldSequenceFile && $oldSequenceFormat && $newSequenceFile && $newSequenceFormat ));

my ($oldSeq, $newSeq);

my $oldSeq = getSeqsFromFile ($oldSequenceFile, $oldSequenceFormat);
my $newSeq = getSeqsFromFile ($newSequenceFile, $newSequenceFormat);

my $outputFile ="seqAliases.txt";
open (OUT, ">$outputFile") || die "can not open output file to write\n";
foreach my $k (sort keys %{$newSeq}) {
  foreach my $kk (sort keys %{$oldSeq}) {
    if ($oldSeq->{$kk} eq $newSeq->{$k}) {
      print OUT "$k\t$kk\n";
    }
  }
}
close OUT;


###############
sub getSeqsFromFile {
  my ($inputFile, $format) = @_;
  my (%seqs);

  if ($format =~ /genbank/i) {
    my $bioperlSeqIO = Bio::SeqIO->new(-format => 'genbank',
				       -file => $inputFile);
    while (my $seq = $bioperlSeqIO->next_seq() ) {
      my $sId = ($seq->id) ? ($seq->id) : ($seq->accession());
      $seqs{$sId} = uc($seq->seq()) if ($sId && $seq->seq());
    }

  } elsif ($format =~ /fasta/i) {
    my $sId;
    open (IN, "$inputFile") || die "can not open inputFile to read\n";
    while (<IN>) {
      chomp;
      if ($_ =~ /^>(\S+)/) {
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

  } else {
    print STDERR "file format has not been configured yet\n";
  }
  return (\%seqs);
}

sub usage {
  die
"
A script to use generate sequence aliases file based on sequence similarity, 100% identity

The standard output file is seqAliases.txt 

Usage: perl createSeqAliasBaseSeqIdentity.pl --oldSequenceFile pre.genome.gbf --oldSequenceFormat genbank 
                                             --newSequenceFile current.genome.gbf --newSequenceFormat genbank

where
            --oldSequenceFile: old sequence file name
            --oldSequenceFormat: old sequence file format
            --newSequenceFile: new sequence file name
            --newSequenceFormat: new annotation file format

";
}
