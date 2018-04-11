#!/usr/bin/perl

use strict;
use warnings;

use Getopt::Long;

unless (0 < @ARGV){
  printf(join("\n",(
    "Usage: getColumnNumberFromHeaderName.pl [-v|values] [-e|exact] [column_header] [file]",
    "\t-e exact match (default is not case-sensitive and allows partial match)",
    "\t-v get unique values in this column with count for each value (implies -e even if it is not specified)",
    "\t-t tab delimiter (default is comma)",
    "")));
  exit;
}

my ($values,$exact,$tab,$delim);

GetOptions('v|values' => \$values, 'e|exact' => \$exact, 't|tab', \$tab);

$exact = 1 if $values;

$delim = $tab ? "\t" : ",";


my($headerName, @files) = @ARGV;

foreach my $filename (@files){

  printf("\n\nReading: %s\n", $filename);

  open(FILE, $filename) or die "Cannot open file $filename for reading: $!";
  
  my $firstline = <FILE>;
  chomp $firstline;
  
  
  my @headers = split(/$delim/, $firstline);
  
  my $colNum;
  
  for(my $i = 0; $i < scalar @headers; $i++) {
    my $match = 0;
    if($exact){
      $match = ($headers[$i] =~ /^$headerName$/);
    }
    else{
      $match = ($headers[$i] =~ /$headerName/i);
    }
    if($match) {
      $colNum = $i;
      printf("Found \"%s\" at column %d\n", $headers[$i],$colNum + 1);
      last;
    }
  }
  
  if( $values && defined($colNum)){
    my %vals;
    while(my $line = <FILE>){
      chomp $line;
      my @data = split(/$delim/, $line);
      next unless defined($data[$colNum]);
      $vals{ $data[$colNum] } ||= 0;
      $vals{ $data[$colNum] }++;
    }
    printf("\nvalue\tcount\n-----\t-----\n%s\n", join("\n", map { sprintf("%s\t%5d", $_, $vals{$_}) } sort keys %vals));
  }
  elsif(!defined($colNum)){
    printf("Column \"%s\" not found in %s\n", $headerName, $filename);
  }
  close FILE;
}

