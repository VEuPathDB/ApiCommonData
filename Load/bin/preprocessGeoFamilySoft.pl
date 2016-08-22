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

=pod

The purpose of this script is to parse a geo series record into separate data files.  The sample names are used as file names... some of the desciptive information (name and description) are also printed to STDOUT.

=cut

if(!$ARGV[0]) {
  print STDERR "usage perl preprocessGeoFamilySoft.pl <GSE>\n";
  exit(0);
}

my $fn = $ARGV[0];
open(FILE, "< $fn") or die "Cannot open file $fn for reading:  $!";

my ($sample, @series, @platforms, $okToPrint, %samples, %columns, $junk);

while(<FILE>) {
  if(/^\!Series_sample_id/) {
    my ($s) = &_splitEntry($_);
    push(@series, $s);
  }
  elsif(/^\!Series_platform_id/) {
    my ($p) = &_splitEntry($_);
    push(@platforms, $p);
  }
  elsif(/^\^SAMPLE/ || /^\^PLATFORM/) {
    my ($v, $p) = &_splitEntry($_);
    $sample = $v;
    my $out = $sample . ".txt";
    $samples{$sample} = {};

    open(RES, "> $out") || die "Cannot open file $out for writing: $!";
  }
  elsif(/\!sample_table_end/ || /\!platform_table_end/) {
    close(RES);
    $okToPrint = 0;
  }
  elsif(/\!sample_table_begin/ || /\!platform_table_begin/) {
    $okToPrint = 1;
    next;
  }
  elsif(/\!Sample/) {
    my ($v, $p) = &_splitEntry($_);
    next unless $p;
    push(@{$samples{$sample}->{$p}}, $v) unless(&included($samples{$sample}->{$p}, $v));
    $columns{$p} = 1;
  }
  else {}

  print RES if($okToPrint);
}
close(FILE);

print join("\t", sort keys(%columns)) . "\n";

foreach my $id (keys(%samples)) {
  foreach my $col (sort keys(%columns)) {
    if($samples{$id}->{$col}) {
      my $outputString = join('|', @{$samples{$id}->{$col}})."\t";
      $outputString =~ s/[\n\r]//g;
      print $outputString;
    }
    else {
      print "\t";
    }
  }
  print "\n";
}

my $n = scalar(keys %samples);
if($n != scalar(@series) + scalar(@platforms)) {
  print STDERR "WARNING:  $n data files were generated and ". scalar(@series) ." samples expected\n";
}

#--------------------------------------------------------

sub _splitEntry {
  my ($line) = @_;

  my ($prefix, $value) = $line =~ /^[\^\!](.+) = (.+)$/;

  return($value, $prefix);
}

#--------------------------------------------------------

sub included {
  my ($ar, $val) = @_;

  if(!$ar) {
    return(0);
  }
  foreach(@$ar) {
    return(1) if($_ eq $val);
  }
  return(0);
}


1;
