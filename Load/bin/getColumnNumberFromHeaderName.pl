#!/usr/bin/perl

use strict;
use warnings;

use Getopt::Long;
use Text::CSV_XS;

unless (0 < @ARGV){
  printf STDERR (join("\n",(
    "Usage: getColumnNumberFromHeaderName.pl [-v|values] [-e|exact] [column_header] [file]",
    "\t-e exact match (default is not case-sensitive and allows partial match)",
    "\t-v get unique values in this column with count for each value (implies -e even if it is not specified)",
    "\t-t tab delimiter (default is comma)",
    "\t-I identifiers only (first column)",
    "")));
  exit;
}

my ($values,$exact,$tab,$identifiers,$delim);

GetOptions('v|values!' => \$values, 'e|exact' => \$exact, 't|tab', \$tab, 'I|identifiers!' => \$identifiers);

$exact = 1 if $values;

$delim = $tab ? "\t" : ",";

my $csv = Text::CSV_XS->new({ binary => 1, sep_char => $delim, quote_char => '"' }) or die "Cannot use CSV: ".Text::CSV_XS->error_diag ();  


my($headerName, @files) = @ARGV;

foreach my $filename (@files){

  printf STDERR ("\n\nReading: %s\n", $filename);

  open(FILE, $filename) or die "Cannot open file $filename for reading: $!";
  
  my $head = <FILE>;
  chomp $head;
	if($head =~ /\t/){ $delim = "\t"; $tab = 1; $csv->sep_char($delim); }

	printf STDERR "Delimeter:[$delim]\n";
  
  my @headers = map { $_ =~ s/"//g; $_ } split(/$delim/, $head);
  
  my $colNum;
  
  for(my $i = 0; $i < scalar @headers; $i++) {
    my $match = 0;
    if($exact){
      $match = ($headers[$i] =~ /^$headerName$/i);
    }
    else{
      $match = ($headers[$i] =~ /$headerName/i);
    }
    if($match) {
      $colNum = $i;
      printf STDERR ("Found \"%s\" at column %d\n", $headers[$i],$colNum + 1);
      last;
    }
  }
  
  if( $values && defined($colNum)){
    my %vals;
    my @ids;
    while(my $line = <FILE>){
      chomp $line;
      my @data; # = split(/$delim/, $line);
      if($csv->parse($line)) {
        @data = $csv->fields();
      }
      else {
          my $error= "".$csv->error_diag;
        die "Could not parse line: $error";
      }
      next unless defined($data[$colNum]);
      $vals{ $data[$colNum] } ||= 0;
      $vals{ $data[$colNum] }++;
      push(@ids, $data[0]) if ($data[$colNum] ne "");
    }
    print STDERR ("\nvalue\tcount\n-----\t-----\n");
		printf ("%s\n", join("\n", map { sprintf("%s\t%5d", $_, $vals{$_}) } sort keys %vals));
		my $nonempty = 0;
		map { $nonempty += $vals{$_} if ($_ ne "")  } keys %vals;
    printf STDERR ("-----\nNon-empty\t%d\n", $nonempty);
    if($identifiers){
      printf STDERR ("%d identifiers\n", scalar @ids);
      printf STDERR ("%s\n", join("\n", @ids)) if (20 > @ids);
    }
  }
  elsif(!defined($colNum)){
    printf STDERR ("Column \"%s\" not found in %s\n", $headerName, $filename);
  }
  close FILE;
}

