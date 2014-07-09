#!/usr/bin/perl -w
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

use Bio::SeqIO;
use List::Util qw(min max);



my $db = Bio::SeqIO->new(-file => shift(@ARGV),
			 -format => "fasta"
			);

# read in the sequence database to be matched against:

my @names; my @seqs;  my $i = 0;
while (my $seq = $db->next_seq) {
    $names[$i] = $seq->display_id;
    my $str = uc $seq->seq;
    $seqs[$i] = $str;
    $i++;
}


# OK, now do the actual mapping:

my $tagdb = Bio::SeqIO->new(-format => "fasta", -file => shift(@ARGV));

my $outputFile = shift(@ARGV);

open (OUT, ">$outputFile") if ($outputFile);

my $flag = 0;

while (my $tag = $tagdb->next_seq) {
  my $tagseq = uc $tag->seq;

  
  # match against forward strand sequence:
  for my $match (&matchArray($tagseq)) {
      $flag =1;
    my ($pos, $idx) = @$match;
    
    print OUT $tag->display_id . " matched against $names[$idx] from $pos to " . ($pos + length($tagseq)) . " on forward strand\n" if ($outputFile);
    
#    warn $tag->display_id . " matched against $names[$idx] from $pos to " . ($pos + length($tagseq)) . " on forward strand\n";
  }

  # reverse complement the SAGE tag:
  $tagseq =~ tr/acgtrymkswhbvdnxACGTRYMKSWHBVDNX/tgcayrkmswdvbhnxTGCAYRKMSWDVBHNX/;
  $tagseq = reverse $tagseq;

  # match against reverse strand sequence:
  for my $match (&matchArray($tagseq)) {
      $flag=1;
    my ($pos, $idx) = @$match;

    print OUT $tag->display_id . " matched against $names[$idx] from $pos to " . ($pos + length($tagseq)) . " on reverse strand\n" if ($outputFile);

#    warn $tag->display_id . " matched against $names[$idx] from $pos to " . ($pos + length($tagseq)) . " on reverse strand\n";
  }

  if($flag == 1){
      print STDERR $tag->display_id . " did not find a match against genome.\n";
  }else{
      print STDERR $tag->display_id . " found match(es) against genome.\n";
  }
  
}

close OUT;


sub matchArray{
    my($tagSeq) = @_;

    $tagSeq = uc $tagSeq;

 
    
    my @matchArray;

    my $flag = 0;

    my $i=0;
    foreach my $seq (@seqs){
	while ($seq =~ /$tagSeq/g){
	
	    $flag = 1;

	    push(@matchArray,[$-[0],$i]);
	     
	}

	$i++;
    }


    return @matchArray;
    
    

}
