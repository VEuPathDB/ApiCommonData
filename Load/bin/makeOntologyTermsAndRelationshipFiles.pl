#!/usr/bin/perl

use strict;

use Getopt::Long;

my ($help, $fn, $termOut, $relOut, $relType);

&GetOptions('help|h' => \$help,
            'file=s' => \$fn,
            'out_term_file=s' => \$termOut,
            'out_rel_file=s' => \$relOut,
            'relationship_type=s' => \$relType,
            );

open(FILE, $fn) or die "Could not open file $fn for reading: $!";

open(TERM, "|sort -u > $termOut") or die "Could not open file $termOut for writing: $!";
open(REL, "> $relOut") or die "Could not open file $relOut for writing: $!";


while(<FILE>) {
  chomp;
  my ($parent, $child) = split(/\t/,  $_);

  print TERM "$parent\t$parent\n";
  print TERM "$child\t$child\n";

  print REL "$child\t\t$parent\t$relType\n";
}


close FILE;
close TERM;
close REL;

1;
