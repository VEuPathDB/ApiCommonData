#!/usr/bin/perl

use strict;

use lib $ENV{GUS_HOME} . "/lib/perl";
use Getopt::Long;
use ApiCommonData::Load::EBIUtils;
use CBIL::Util::Utils;
use IO::Zlib;
use File::Temp qw/ tempfile /;
use File::Copy;


my ($help, $samplesDirectory, $gusConfigFile, $organismAbbrev);

&GetOptions('help|h' => \$help,
            'samples_directory=s' => \$samplesDirectory,
            'organism_abbrev=s' => \$organismAbbrev,
            );

&usage("Sample directory does not exist") unless -d $samplesDirectory;
&usage("organismAbbrev not defined") unless $organismAbbrev;

chomp $organismAbbrev;

my $map = getGenomicSequenceIdMapSql($organismAbbrev);

foreach my $bed (glob "$samplesDirectory/*/*.bed") {
  my $oldBed = "$bed.old";

  move($bed, $oldBed);

  open(OLD, $oldBed) or die "Cannot open file $oldBed for reading: $!";
  open(BED, ">$bed") or die "Cannot open file $bed for writing: $!";

  while(<OLD>) {
    chomp;
    my @a = split(/\t/, $_);
    if($map->{$a[0]}) {
      $a[0] = $map->{$a[0]};
    }

    print BED join("\t", @a) . "\n";
  }

  close BED;
  close OLD;

}

foreach my $junction (glob "$samplesDirectory/*/junctions.tab") {
  my $oldJunction = "$junction.old";

  move($junction, $oldJunction);

  open(OLD, $oldJunction) or die "Cannot open file $oldJunction for reading: $!";
  open(JXN, ">$junction") or die "Cannot open file $junction for writing: $!";

  my $header = <OLD>;
  print JXN $header;

  while(<OLD>) {
    chomp;
    my @a = split(':', $_);
    if($map->{$a[0]}) {
      $a[0] = $map->{$a[0]};
    }

    print JXN join(":", @a) . "\n";
  }

  close JXN;
  close OLD;
}


sub usage {
  die "ebiRNASeqSeqRegionNameMapping.pl --samples_directory=PATH --organism_abbrev==s\n";
}

1;

