#!/usr/bin/perl -w

use strict;

use Bio::SeqIO;
use List::Util qw(min max);

use lib "/home/pinney/toxo/lib";
use Suffix::Array;

my $sarr = Suffix::Array->new();

my $db = Bio::SeqIO->new(-file => shift(@ARGV),
			 -format => "fasta"
			);

# read in the sequence database to be matched against:

my @names; my $i = 0;
while (my $seq = $db->next_seq) {
    $names[$i] = $seq->display_id;
    my $str = uc $seq->seq;
    $sarr->add(\$str);
    $i++;
}

# OK, now do the actual mapping:

my $tagdb = Bio::SeqIO->new(-format => "fasta", -file => shift(@ARGV));

my $outputFile = shift(@ARGV);

print "outputFile=$outputFile\n";

open (OUT, ">$outputFile") if ($outputFile);

while (my $tag = $tagdb->next_seq) {
  my $tagseq = uc $tag->seq;

  # match against forward strand sequence:
  for my $match ($sarr->match($tagseq)) {
    my ($pos, $idx) = @$match;
    
    print OUT $tag->display_id . " matched against $names[$idx] from $pos to " . ($pos + length($tagseq)) . " on forward strand\n" if ($outputFile);
    
#    warn $tag->display_id . " matched against $names[$idx] from $pos to " . ($pos + length($tagseq)) . " on forward strand\n";
  }

  # reverse complement the SAGE tag:
  $tagseq =~ tr/acgtrymkswhbvdnxACGTRYMKSWHBVDNX/tgcayrkmswdvbhnxTGCAYRKMSWDVBHNX/;
  $tagseq = reverse $tagseq;

  # match against reverse strand sequence:
  for my $match ($sarr->match($tagseq)) {
    my ($pos, $idx) = @$match;

    print OUT $tag->display_id . " matched against $names[$idx] from $pos to " . ($pos + length($tagseq)) . " on reverse strand\n" if ($outputFile);

#    warn $tag->display_id . " matched against $names[$idx] from $pos to " . ($pos + length($tagseq)) . " on reverse strand\n";
  }

}

close OUT;
