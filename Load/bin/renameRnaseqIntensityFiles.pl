#!/usr/bin/perl

use strict;

use Getopt::Long;
use File::Basename;
use File::Copy qw(copy);

my ($help, $outputDirectory, $inputDirectory) = @_;

&GetOptions('help|h' => \$help,
            'inputDirectory=s' => \$inputDirectory,
            'outputDirectory=s' => \$outputDirectory,
    );

unless(-e $inputDirectory && -e $outputDirectory) {
  die "usage:  renameRnaseqIntensityFiles.pl --inputDirectory <DIR> --outputDirectory <DIR2>";
}


my $replacement = ".fpkm_tracking";

foreach my $file (glob "$inputDirectory/*$replacement*") {
  my $basename = basename $file;
  my $newFile = $basename;
  $newFile =~ s/$replacement//;

  copy $file, "$outputDirectory/$newFile";
}



