#!/usr/bin/perl
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
  # GUS4_STATUS | dots.gene                      | manual | absent
#^^^^^^^^^^^^^^^^^^^^^^^^^ End GUS4_STATUS ^^^^^^^^^^^^^^^^^^^^
#Uses the BioPerl SeqIO library to filter a fastq library for reads of a given range (quick 'n' dirty - need to add default values for range boundaries and parse input better)
###########################################################
use strict;
use warnings;
use Bio::SeqIO;
use Getopt::Long;

my $readsFile;
my $type;
my $minLength = 0;
my $maxLength = 2000;
my $outFile;

&GetOptions("readsFile|r=s" => \$readsFile,
            "type|t=s" => \$type,
            "minLength|m=i" => \$minLength,
            "maxLength|x=i" => \$maxLength,
            "outFile|o=s" => \$outFile
            );

if (! -e $readsFile || $maxLength <= $minLength){
    die <<endOfUsage;
        filterFastqByLength.pl usage:
        filterFastqByLength.pl --readsFile|-r <path to file to filter> --type|-t <file type (fastq, fastq-illumina) --minLength|-m <minimum length of reads to retain (integer, default = 0)> --maxLength|-M <maximum length of reads to retain (integer, default=2000)> --outFile|-o <path to output file>  Defaults are set such that if a value is not provided it is highly unlikely that any reads will be trimmed at that end of the scale.
endOfUsage
}

#SeqIO object to read from
my $sequences = Bio::SeqIO->new(
    -format => $type,
    -file => "<$readsFile"
    );

#SeqIO object to write to
my $output = Bio::SeqIO->new(
    -format => $type,
    -file => ">$outFile"
    );

while (my $seq = $sequences->next_seq){
    my $length = $seq->length;
    if ($minLength <= $length and $length <= $maxLength){
        $output->write_fastq($seq);
    }
}    
