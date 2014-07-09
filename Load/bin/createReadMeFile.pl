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

use Getopt::Long;
use Data::Dumper;

my ($baseDir,$verbose,$outputFile);
&GetOptions("verbose!" => \$verbose,
	    "baseDir=s" => \$baseDir,
	    "outputFile=s" => \$outputFile);

die "Must provide a baseDir\n" unless ($baseDir);

print "Process files recursively in $baseDir\n" if $verbose;

die "$baseDir doesn't exist\n"  unless (-w $baseDir);

my @resideFiles=process_files ($baseDir);

print Dumper (\@resideFiles) if $verbose;

my $cmd= "cat " . join (' ', grep {(/\.desc$/)} @resideFiles) . "> $outputFile";

system ($cmd) || print $!;

print STDERR "$cmd\n" ;

sub process_files {

    my $path = shift;

    opendir (DIR, $path)
        or die "Unable to open $path: $!";

    # LIST = map(EXP, grep(EXP, readdir()))
    my @files =
        map { $path . '/' . $_ }
        grep { !/^\.{1,2}$/ }
        readdir (DIR);

    closedir (DIR);

    for (@files) {
        if (-d $_) {
            push @files, process_files ($_);

        } else {
        }
    }
    return @files;
}


1;
