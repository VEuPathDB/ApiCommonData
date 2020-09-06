#!/usr/bin/perl

use strict;

use Getopt::Long;
use File::Basename;

my ($help, $outputDirectory, $inputDirectory, $sampleName) = @_;

&GetOptions('help|h' => \$help,
            'inputDirectory=s' => \$inputDirectory,
            'outputDirectory=s' => \$outputDirectory,
            'sampleName=s' => \$sampleName, 
    );

unless(-e $inputDirectory && -e $outputDirectory) {
  die "usage:  renameRnaseqIntensityFiles.pl --inputDirectory <DIR> --outputDirectory <DIR2> --sampleName=s";
}


my $suffix = ".fpkm_tracking";

foreach my $file (glob "$inputDirectory/*$suffix") {
  open(FILE, "cut -f 1,10 $file|") or die "Cannot open file $file for reading: $!";

  my $basename = basename $file;
  my $newFile = $basename;
  $newFile =~ s/$suffix/\.fpkm/;
  $newFile = "$sampleName.$newFile";

  open(OUT, ">$outputDirectory/$newFile") or die "Cannot open file $newFile for writing: $!";

  while(<FILE>) {
    # ARGH...GSNAP adds rna_ as prefix to unique id.  need to remove
    s/^rna_// if($newFile =~ /isoform/);

    print OUT;
  }
  close OUT;
  close FILE;
}

foreach my $suffix ('.fpkm', '.counts', '.tpm') {
    foreach my $file (glob "$inputDirectory/*$suffix") {
	open(FILE, $file) or die "Cannot open file $file for reading: $!";

	my $basename = basename $file;
	my $newFile = "$sampleName.$basename";
	
	open(OUT, ">$outputDirectory/$newFile") or die "Cannot open file $newFile for writing: $!";
	
	while(<FILE>) {
	    print OUT;
	}
	close OUT;
	close FILE;
    }
}

1;


