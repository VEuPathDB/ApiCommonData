#!/usr/bin/perl

use strict;

my $headerName = $ARGV[0];

my $filename = $ARGV[1];

open(FILE, $filename) or die "Cannot open file $filename for reading: $!";

my $firstline = <FILE>;
chomp $firstline;

close FILE;

my @headers = split(/\t|,/, $firstline);

for(my $i = 0; $i < scalar @headers; $i++) {
  if($headers[$i] =~ /$headerName/i) {
    my $colNum = $i + 1;
    print "$headers[$i]\t$colNum\n";
  }
}
