#!/usr/bin/env perl

use warnings;
use strict;
use Getopt::Long;



my ($inputPepFasta, $peptideTab, $correctedFasta);
&GetOptions("inputPepFasta=s"=> \$inputPepFasta,
	    "correctedFasta=s"=> \$correctedFasta,
            "peptideTab=s"=> \$peptideTab,
    ) ;

unless (-e $inputPepFasta && $peptideTab) {
    &usage("Both input files must exist;  output file must be declared")
}

sub usage {
    my ($e) = @_;

    print STDERR "processIedb.pl --inputPepFasta <FILE> --correctedFasta FastaOut --peptideTab OUT \n";
    die $e if($e);
}


my $outfile =  $peptideTab;
open(FH, '>>', $outfile) or die $!;

local $/ = ">";

my $epitopesFile = $inputPepFasta;

system("sed 's/>/@/;s/>/PepId/g;s/@/>/' $epitopesFile > $correctedFasta");

my $modifiedFatsa = $correctedFasta;

open(my $epitopes, $modifiedFatsa) or die "Could not open file '$modifiedFatsa' $!";


while(my $record = <$epitopes>){
  chomp $record;
  
  my $newline_loc = index($record,"\n");
  my $header = substr($record,0,$newline_loc);
  
  my @headerSplir = split(/\|/, $header);
  my $sequence = substr($record,$newline_loc+1);
  $sequence =~ tr/\n//d;

  my $id = $headerSplir[3];
 
  
  print FH ( $headerSplir[3] . "\t" . $headerSplir[0] . "\t" . $headerSplir[2] .  "\t" ."$sequence\t" . $headerSplir[1] . "\n");

}
close FH;

