#!/usr/bin/perl

# Adapted from code Written by Gregory R Grant
# University of Pennsylvania, 2010

use Bio::SeqIO;

if(@ARGV < 1) {
    die "
Usage: makePbaseTbase.pl <probes.fsa>

 This gets the pbase-tbase file needed by create_cdf.pl, this only works for match only arrays.

This script outputs to std out.

";
}


$compliment{"A"} = "T";
$compliment{"T"} = "A";
$compliment{"C"} = "G";
$compliment{"G"} = "C";

my $fasta = Bio::SeqIO->new(-file => $ARGV[0],
                       -format => 'fasta');

while ( my $seq = $fasta->next_seq() ) {
  my $probe = $seq->seq();
  @b = split(//,$probe);
  print $seq->display_id() . "\t" . $b[12] . "\t" . $compliment{$b[12]} .  "\n";
}
