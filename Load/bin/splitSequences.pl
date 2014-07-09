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
die 'This file has broken or unreviewed GUS4_STATUS rules.  Please remove this line when all are fixed or absent';
#^^^^^^^^^^^^^^^^^^^^^^^^^ End GUS4_STATUS ^^^^^^^^^^^^^^^^^^^^

use strict;
use warnings;

use lib "$ENV{GUS_HOME}/lib/perl";
use Getopt::Long qw(GetOptions);

use Bio::Seq;
use Bio::SeqIO;
use Bio::Location::Simple;

my $verbose;
my $breakLength;
my $minSubSeqLength;
my $overlap;
my $inputFile;
my $outputFile;
my $inputType;
my $outputType;

GetOptions("verbose!"           => \$verbose,
           "breakLength=s"      => \$breakLength,
	   "minSubSeqLength=s"  => \$minSubSeqLength,
	   "overlap=s"          => \$overlap,
	   "inputFile=s"        => \$inputFile,
	   "outputFile=s"       => \$outputFile,
	   "inputType=s"        => \$inputType,
	   "outputType=s"       => \$outputType,
          );

unless ($breakLength && $overlap && $minSubSeqLength && $outputFile) {
  die "usage:  perl splitSequences.pl --inputFile <FILENAME> --inputType <INPUTFILE FORMAT> --outputFile <FILENAME> --outputType <OUTPUTFILE FORMAT> --breakLength <INT length into which full sequence should be broken> --overlap <INT amount of overlap to have between subsequences> --minSubSeqLength <INT length of smallest allowable subsequence> [--verbose]";
}

if ($overlap >= $breakLength){
  die "Your overlap length of $overlap will either cause your subsequence to exceed the bounds of your original sequence or will cause this program to loop indefinately.  Please pick an overlap length that is smaller than your breaklength of $breakLength and try again.\n";
}

print "break: $breakLength\nminSubSeqLength: $minSubSeqLength\noverlap: $overlap\n" if $verbose;

unless (-e $inputFile){
  die "The file $inputFile does not exist.\n";
}

parseFile();




sub splitSeq {
  my ($seq) = @_;
  my $sourceId = $seq->id;
  my $fullSeqLength = $seq->length;

  my @subSeqs;
  my $subSeqEnd;
  my $subSeqStart;
  my $subSeqName;
  my $subSeq;

  $subSeqEnd = $fullSeqLength;
  $subSeqStart = $subSeqEnd - $breakLength;


  if ($subSeqStart < 1){
    $subSeqName = "${sourceId}.1";
    $subSeq = Bio::Seq->new(-id => $subSeqName,
			    -seq => $seq->subseq(1,$fullSeqLength),
			   );

    push (@subSeqs, $subSeq);
    return @subSeqs;
  }


  if ($subSeqStart % 3 != 1){
    if ($subSeqStart % 3 == 0){
      $breakLength = $breakLength - 1;
    }elsif ($subSeqStart % 3 == 2){
      $breakLength = $breakLength + 1;
    }
    $subSeqStart = $subSeqEnd - $breakLength;
  }

  $subSeqName = "${sourceId}.${subSeqStart}";
print "ID: $subSeqName\n" if $verbose;
print "Start mod 3 = ".$subSeqStart % 3 .", should be = 1\n" if $verbose;
print "End mod 3 = ".$subSeqEnd % 3 .", should be = ".$fullSeqLength %3 ."\n" if $verbose;

  $subSeq = Bio::Seq->new(-id => $subSeqName,
			     -seq => $seq->subseq($subSeqStart,$subSeqEnd),
			    );

  push (@subSeqs, $subSeq);


  $subSeqEnd = $subSeqStart + $overlap;
  until ($subSeqEnd % 3 == $fullSeqLength % 3){
    $overlap = $overlap - 1;
    $subSeqEnd = $subSeqStart + $overlap;
  }

  $subSeqStart = $subSeqEnd - $breakLength;
  $subSeqName = "${sourceId}.${subSeqStart}";

print "ID: $subSeqName\n" if $verbose;
print "Start mod 3 = ".$subSeqStart % 3 .", should be = 1\n" if $verbose;
print "End mod 3 = ".$subSeqEnd % 3 .", should be = ".$fullSeqLength %3 ."\n" if $verbose;

  $subSeq = Bio::Seq->new(-id => $subSeqName,
			  -seq => $seq->subseq($subSeqStart,$subSeqEnd),
			 );

  push (@subSeqs, $subSeq);


  while ($subSeqStart + $overlap >= $minSubSeqLength && $subSeqStart + $overlap >= $breakLength){
    $subSeqEnd = $subSeqStart + $overlap;
    $subSeqStart = $subSeqEnd - $breakLength;
    $subSeqName = "${sourceId}.${subSeqStart}";

print "ID: $subSeqName\n" if $verbose;
print "Start mod 3 = ".$subSeqStart % 3 .", should be = 1\n" if $verbose;
print "End mod 3 = ".$subSeqEnd % 3 .", should be = ".$fullSeqLength %3 ."\n" if $verbose;

    $subSeq = Bio::Seq->new(-id => $subSeqName,
			    -seq => $seq->subseq($subSeqStart,$subSeqEnd),
			   );

    push (@subSeqs, $subSeq);

  }

#replace the last subseq in the array with a subseq starting at location 1
  if($subSeqStart > 1){
    $subSeqStart = 1;
    $subSeqName = "${sourceId}.1";
    $subSeq = pop @subSeqs;

print "ID: $subSeqName\n" if $verbose;
print "Start mod 3 = ".$subSeqStart % 3 .", should be = 1\n" if $verbose;
print "End mod 3 = ".$subSeqEnd % 3 .", should be = ".$fullSeqLength %3 ."\n" if $verbose;

    $subSeq = Bio::Seq->new(-id => $subSeqName,
			    -seq => $seq->subseq($subSeqStart,$subSeqEnd),
			   );

    push (@subSeqs, $subSeq);
  }

return @subSeqs;

}


sub parseFile {

  my $seqIn  = Bio::SeqIO->new( '-format' => $inputType , -file => $inputFile);
  my $seqOut = Bio::SeqIO->new('-format' => $outputType , -file => ">$outputFile");
  while (my $seq = $seqIn->next_seq()){

    print "Seq: ".$seq->id." length: ".$seq->length."\n\n" if $verbose;

    my @subSeqs = splitSeq($seq);

    foreach my $subSeq (@subSeqs){
      $seqOut->write_seq($subSeq);
    }

  }

}

1;
