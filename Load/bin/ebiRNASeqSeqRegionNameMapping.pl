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
            'gusConfigFile=s' => \$gusConfigFile,
            );

&usage("Sample directory does not exist") unless -d $samplesDirectory;
&usage("organismAbbrev not defined") unless $organismAbbrev;

chomp $organismAbbrev;

my $map = getGenomicSequenceIdMapSql($organismAbbrev, $gusConfigFile);

foreach my $bed (glob "$samplesDirectory/*/*.bed") {
  my $oldBed = "$bed.old";

  move($bed, $oldBed);

  open(my $oldFh, '<', $oldBed) or die "Cannot open file $oldBed for reading: $!";
  open(my $bedFh, ">$bed") or die "Cannot open file $bed for writing: $!";

  while(<$oldFh>) {
    chomp;
    my @a = split(/\t/, $_);
    if($map->{$a[0]}) {
      $a[0] = $map->{$a[0]};
    }

    print $bedFh join("\t", @a) . "\n";
  }

  close $bedFh;
  close $oldFh;

}

foreach my $junction (glob "$samplesDirectory/*/junctions.tab") {
  my $oldJunction = "$junction.old";

  move($junction, $oldJunction);

  open(my $oldJuncFh, '<',  $oldJunction) or die "Cannot open file $oldJunction for reading: $!";
  open(my $jxnFh, ">$junction") or die "Cannot open file $junction for writing: $!";

  my $header = <$oldJuncFh>;
  print $jxnFh $header;

  while(<$oldJuncFh>) {
    chomp;
    my @a = split(':', $_);
    if($map->{$a[0]}) {
      $a[0] = $map->{$a[0]};
    }

    print $jxnFh join(":", @a) . "\n";
  }

  close $jxnFh;
  close $oldJuncFh;
}


sub usage {
  die "ebiRNASeqSeqRegionNameMapping.pl --samples_directory=PATH --organism_abbrev==s\n";
}

1;

