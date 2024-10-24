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

my ($help, $fn, $contigIdRegex, $geneIdRegex);

&GetOptions('help|h' => \$help,
            'file=s' => \$fn,
            'contigIdRegex=s' => \$contigIdRegex,
            'geneIdRegex=s' => \$geneIdRegex,
            );


unless(-e $fn) {
  print STDERR "Error File $fn not found\n";
  print STDERR "usage:  makeZff --file <GFF> --contigIdRegex <ContigIdRegEx> --geneIdRegex <GeneIdRegEx>\n";
  exit(1);
}

open(FILE, $fn) or die "Cannot open file $fn for reading:$!";

my %H;


while (<FILE>) {
  my @f = split;
   my $contig = $f[0];
   my $gene = $f[8];
  if (defined $contigIdRegex){
    ($contig) = $f[0] =~ /$contigIdRegex/;
  }
  if (defined $geneIdRegex){
    ($gene) = $f[8] =~ /$geneIdRegex/;
  }
  if($contig ne "" && $gene ne ""){
    push @{$H{$contig}{$gene}}, {
                             start  => $f[3],
                             end    => $f[4],
                             strand => $f[6],
                            }
  }
}

close FILE;

foreach my $contig (sort keys %H) {
  print ">$contig\n";
  foreach my $gene (sort keys %{$H{$contig}}) {

    
    foreach my $exon (@{$H{$contig}{$gene}}) {
      print 'Exon', "\t";
      if ($exon->{strand} eq '+') {
        print $exon->{start}, "\t", $exon->{end};
      } else {
        print $exon->{end}, "\t", $exon->{start};
      }
      print "\t", $gene, "\n";
    }
  }
}

__END__
