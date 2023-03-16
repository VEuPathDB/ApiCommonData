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
  # GUS4_STATUS | dots.gene                      | manual | unreviewed
#^^^^^^^^^^^^^^^^^^^^^^^^^ End GUS4_STATUS ^^^^^^^^^^^^^^^^^^^^

use strict; 
use lib "$ENV{GUS_HOME}/lib/perl";
use CBIL::Util::Sra;
use Getopt::Long;

my($getFastq);

&GetOptions("getFastq|q!" => \$getFastq,
            "apiKey=s" => \$apiKey,
            );

if(scalar(@ARGV) == 0){
  die "testSRAFetch.pl usage:\n\ttestSRAFetch.pl --getFastq (if present retrieves fastq sequences ... normally would not include this argument if just testing) 'strings to test'\n\tNOTE: it takes in test strings on the commandline.  You can pass in multiple strings for one sample as a comma delimited list ... string1,string2 or 'string1, string2' ... each argument will be evaluated as a sample\n";
}

my $ct = 0;
foreach my $sampleId (@ARGV){
  $ct++;
  my @tmp;
  foreach my $s (split(/,\s*/,$sampleId)){
    push(@tmp,$s);
  }
  &getFastqForSampleIds(\@tmp,"readsFor$ct.fastq","readsRev$ct.fastq",$getFastq ? 0 : 1, $apiKey);
}
