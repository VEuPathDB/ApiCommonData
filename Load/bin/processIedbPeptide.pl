#!/usr/bin/env perl


use strict;
use Getopt::Long;


use Bio::SeqIO;
use Data::Dumper;

my ($inputPepFasta, $peptideTab, $correctedFasta, $mergedNcbiFile);
&GetOptions("inputPepFasta=s"=> \$inputPepFasta,
            "correctedFasta=s"=> \$correctedFasta,
            "mergedNcbi=s" => \$mergedNcbiFile,
            "peptideTab=s"=> \$peptideTab,
    ) ;

unless (-e $inputPepFasta && $peptideTab) {
    &usage("Both input files must exist;  output file must be declared")
}

sub usage {
    my ($e) = @_;

    print STDERR "processIedb.pl --inputPepFasta <FILE> --correctedFasta FastaOut --peptideTab OUT \n";
    die $e if($e);
}



my $mergedTaxa = &readMergedFile($mergedNcbiFile);


my $outfile =  $peptideTab;
open(FH, '>', $outfile) or die $!;


my $inseq = Bio::SeqIO->new(-file   => $inputPepFasta,
                            -format => 'fasta' );

my $outseq = Bio::SeqIO->new( -file   => ">$correctedFasta",
                               -format => 'fasta',
                             );

while (my $seq = $inseq->next_seq) {
    my $iedbId = $seq->id();

    my $seqString = $seq->seq();


    my $desc = $seq->desc();
    my @deflineElements = split(/\|/, $desc);

    my $iedbTaxon = $deflineElements[1];
    if($mergedTaxa->{$iedbTaxon}) {
        $iedbTaxon = $mergedTaxa->{$iedbTaxon};
    }

    print FH $deflineElements[2], "\t",
        $iedbId, "\t",
        $iedbTaxon, "\t",
        $seqString, "\t",
        $deflineElements[0], "\n";

    my $newDesc = $deflineElements[0] . "|" . $iedbTaxon . "|" . $deflineElements[2];

    my $correctedSeq = Bio::Seq->new( -display_id => $iedbId,
                                      -desc => $newDesc,
                         -seq => $seqString);

    $outseq->write_seq($correctedSeq);
}

 close FH;


sub readMergedFile {
    my ($merged) = @_;

    open(MERGED, $merged) or die "Cannot open merged ncbi file $merged for reading: $!";

    my %rv;

    while(<MERGED>) {
        chomp;

        my ($oldNcbiTaxId, $newNcbiTaxId) = split(/\s*\|\s*/, $_);

        $rv{$oldNcbiTaxId} = $newNcbiTaxId;
    }

    return \%rv;
}
