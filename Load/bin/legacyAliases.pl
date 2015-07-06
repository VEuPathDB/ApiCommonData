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
  # GUS4_STATUS | dots.gene                      | manual | reviewed
#^^^^^^^^^^^^^^^^^^^^^^^^^ End GUS4_STATUS ^^^^^^^^^^^^^^^^^^^^

use strict;

use Getopt::Long;

my ($help, $legacyFn, $aliasesFn, $outfile);

&GetOptions('help|h' => \$help,
            'cumulative_legacy_file=s' => \$legacyFn,
            'aliases_from_annotation_file=s' => \$aliasesFn,
            'output_file=s' => \$outfile,
            );

&usage if($help);

unless(-e $legacyFn) {
  &usage("Legacy File not specifiec correctly");
}
unless(-e $aliasesFn) {
  &usage("Aliases From Annotation File not specifiec correctly");
}


open(ALIAS, $aliasesFn) or die "Cannot open aliases file $aliasesFn for reading: $!";
open(LEGACY, $legacyFn) or die "Cannot open legacy file $legacyFn for reading: $!";
open(OUT, "> $outfile") or die "Cannot open output file $outfile for writing: $!";

my %map;

while(<ALIAS>) {
  chomp;

  my ($id, $prevId) = split(/\t/, $_);

  push @{$map{$prevId}},$id;

  print OUT "$id\t$prevId\n";
}

close ALIAS;

while(<LEGACY>) {
  chomp;

  next if(/^\#/);

  my ($prevId, $legacyAlias) = split(/\t/, $_);

  unless($map{$prevId}) {
    print STDERR "WARN:  No mapping found for Legacy Id [$prevId].  Skipping...\n";
    next;
  }

  my @ids = @{$map{$prevId}};

  foreach my $id(@ids) {
    print OUT "$id\t$legacyAlias\n";
  }
}

close LEGACY;
close OUT;

sub usage {

  if(my $e = shift) {
    print STDERR "$e\n";
  }
  print STDERR "usage legacyAliases --help|h --cumulative_legacy_file <TAB> --aliases_from_annotation_file <TAB> --output_file <OUT>\n";
  exit;
}
