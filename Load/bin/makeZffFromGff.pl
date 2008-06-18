#!/usr/bin/perl

use strict;

use Getopt::Long;

my ($help, $fn);

&GetOptions('help|h' => \$help,
            'file=s' => \$fn,
            );


unless(-e $fn) {
  print STDERR "Error File $fn not found";
  print STDERR "usage:  makeZff <GFF>\n";
  exit(1);
}

open(FILE, $fn) or die "Cannot open file $fn for reading:$!";

my %H;


while (<FILE>) {
  my @f = split;
  push @{$H{$f[0]}{$f[8]}}, {
                             start  => $f[3],
                             end    => $f[4],
                             strand => $f[6],
                            }
}

close FILE;

foreach my $contig (sort keys %H) {
  print ">$contig\n";
  foreach my $gene (sort keys %{$H{$contig}}) {
    my ($name) = $gene =~ /\|(rna.+)$/;
    
    foreach my $exon (@{$H{$contig}{$gene}}) {
      print 'Exon', "\t";
      if ($exon->{strand} eq '+') {
        print $exon->{start}, "\t", $exon->{end};
      } else {
        print $exon->{end}, "\t", $exon->{start};
      }
      print "\t", $name, "\n";
    }
  }
}

__END__
