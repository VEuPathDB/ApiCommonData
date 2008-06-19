#!/usr/bin/perl

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
  push @{$H{$contig}{$gene}}, {
                             start  => $f[3],
                             end    => $f[4],
                             strand => $f[6],
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
