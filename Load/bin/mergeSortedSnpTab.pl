#!/usr/bin/perl

use strict;
use Getopt::Long;

my ($file1, $file2);

my $sequenceIndex = 0;
my $locationIndex = 1;

&GetOptions("file_1=s"=> \$file1,
            "file_2=s" => \$file2,
    );

unless(-e $file1 && -e $file2) {
  print STDERR "usage: perl --file1 <FILE> --file2 <FILE>\n";
  exit;
}

my ($file1Fh, $file2Fh);

open($file1Fh, $file1) or die "Cannot open file $file1 for reading: $!";
open($file2Fh, $file2) or die "Cannot open file $file2 for reading: $!";

my $file1Line = readline($file1Fh);
my $file2Line = readline($file2Fh);

my ($firstLine, $firstFh, $secondLine, $secondFh) = &compareLines($file1Line, $file1Fh, $file2Line, $file2Fh);

while(1) {
  print $firstLine;  

  # If the second file is empty, simply print all of the first file
  if(!$secondLine) {
    &printRest($firstFh);
    last;
  }

  if(my $nextLine = readline($firstFh)) {
    ($firstLine, $firstFh, $secondLine, $secondFh) = &compareLines($nextLine, $firstFh, $secondLine, $secondFh);
  }
  else {
    print $secondLine;
    &printRest($secondFh);

    last;
  }
}

close $file1Fh;
close $file2Fh;


sub printRest {
  my ($fh) = @_;

  while(readline($fh)) {
      print;
    }
}

sub compareLines {
  my ($line, $fh, $otherLine, $otherFh) = @_;

  my @a = split(/\t/, $line);
  my @b = split(/\t/, $otherLine);

  if($a[$sequenceIndex] lt $b[$sequenceIndex] || ($a[$sequenceIndex] eq $b[$sequenceIndex] && $a[$locationIndex] <= $b[$locationIndex])) {
    return($line, $fh, $otherLine, $otherFh);
  }
  return($otherLine, $otherFh, $line, $fh);
}

