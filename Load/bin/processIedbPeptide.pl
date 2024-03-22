#!/usr/bin/env perl

use warnings;
use strict;
use Getopt::Long;


my ($inputPepFasta, $peptideTab, $peptideProtein);
&GetOptions("inputPepFasta=s"=> \$inputPepFasta,
            "peptideTab=s"=> \$peptideTab,
            "peptideProtein=s"=> \$peptideProtein,
    ) ;

unless (-e $inputPepFasta && $peptideTab && $peptideProtein) {
    &usage("Both input files must exist;  output file must be declared")
}

sub usage {
    my ($e) = @_;

    print STDERR "processIedb.pl --inputPepFasta <FILE> --peptideTab OUT --peptideProtein OUT\n";
    die $e if($e);
}


my $outfile =  $peptideTab;
open(FH, '>>', $outfile) or die $!;

local $/ = ">";

my $epitopesFile = $inputPepFasta;

open(my $epitopes, $epitopesFile) or die "Could not open file '$epitopesFile' $!";

my %geneIdHash;

while(my $record = <$epitopes>){
  chomp $record;
  
  my $newline_loc = index($record,"\n");
  my $header = substr($record,0,$newline_loc);
  
  my @headerSplir = split(/\|/, $header);
  my $sequence = substr($record,$newline_loc+1);
  $sequence =~ tr/\n//d;

  my $id = $headerSplir[3];
 
  $geneIdHash{$id} = $id;
  
  print FH ( $headerSplir[3] . "\t" . $headerSplir[0] . "\t" . $headerSplir[2] .  "\t" ."$sequence\t" . $headerSplir[1] . "\n");

}
close FH;

my $keyFile = $peptideProtein;
open(FH, '>>', $keyFile) or die $!;

foreach my $key (keys %geneIdHash){
  $key =~ s/\.[0-9].*//;
  print FH ($key . "\n");
  
}

close FH;
