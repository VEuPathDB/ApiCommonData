#!/usr/bin/perl

use strict;
use lib "$ENV{GUS_HOME}/lib/perl/";

use Getopt::Long;
use Bio::SeqIO;


my ($help, $fasta, $outputFile);
&GetOptions('help|h' => \$help,
            'fasta=s' => \$fasta,
            'outFile=s' => \$outputFile
    );


open(OUT, '>', $outputFile) or die "Cannot open file $outputFile for writing: $!";

my $in  = Bio::SeqIO->new(-file => $fasta ,
                          -format => 'fasta');


while ( my $seq = $in->next_seq() ) {
    print OUT $seq->primary_id(), "\t", $seq->length(), "\n";
}

close OUT;
