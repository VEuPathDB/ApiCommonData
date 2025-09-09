#!/usr/bin/perl

## remove features from genbank format file

use strict;
use Getopt::Long;

my ($genbankFile, $features, $help);

&GetOptions('genbankFile=s' => \$genbankFile,
            'features=s' => \$features,
            'help|h' => \$help,
           );

&usage() if($help);
&usage("Missing a Required Argument") unless(defined $genbankFile);

$features = "CONTIG" if (!$features);

open (IN, $genbankFile) || die "cannt open $genbankFile to read\n";
my $ifSkip = 0;
while (<IN>) {
  if ($_ =~ /^$features/) {
    $ifSkip = 1;
  } elsif ($_ =~ /^ORIGIN/) {
    $ifSkip = 0;
  }
  print "$_" if ($ifSkip == 0);
}
close IN;

###########
sub usage {
  die
"
Usage: removeFeatureFromGenbankFile.pl --genbankFile GCF_000001735.4_TAIR10.1_genomic.gbff > whole_genome.gbf

where
  --genbankFile: required, the genbank file name
  --features: optional, default is CONTIG

";
}

