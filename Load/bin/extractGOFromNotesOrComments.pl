#!/usr/bin/perl
## usage: perl extractGOFromNotesOrComments.pl comments.txt Genbank 432359 > ../final/associations.gas
## usage: perl extractGOFromNotesOrComments.pl comments.txt Genbank 432359 product.txt > ../final/associations.gas
##                           give product.txt file if there is no product info in Note or Comment file

use strict;
use Getopt::Long;
use HTTP::Date;

my ($date, ) = split(" ", HTTP::Date::time2iso());
$date = join("",split(/-/,$date));


my ($inputFile, $db, $taxonId, $productFile) = @ARGV;
$taxonId = "taxon:".$taxonId;

print STDERR "inputFile = $inputFile\ndb = $db\ntaxonId = $taxonId\nproductFile = $productFile\n";

my %products;

if ($productFile) {
  open (PD, "$productFile") || die "can not open productFile to read\n";
  while (<PD>) {
    chomp;
    my ($id, $product) = split (/\t/, $_);
    $products{$id} = $product;
  }
  close PD;
}

open (IN, "$inputFile") || die "can not open $inputFile to read\n";
while (<IN>) {
  chomp;
  my ($sourceId, $line) = split (/\t/, $_);
  my $sourceIdType = "transcript";

  my @items = split (/\; GO/, $line) if ($line);

  foreach my $item (@items) {
    my ($aspect, $goid, $product, $evCode, $dbRef);
    $item = "GO".$item if ($item =~ /^\_/);

    if ($item =~ /^GO_(\w+)/) {
      $aspect = getAspectForGo ($item);

      #if ($item =~ /(GO:\d+) - (.*)$/) {  ## this is only for tgonVEG
      #if ($item =~ /(GO:\d+) - (.*?);/) {  ## this is for hhamHH34 only
      if ($item =~ /(GO:\d+);.* - (.*) \[PMID (\d+)\]/) { # for ntetFGSC2508
	$goid = $1;
	$product = $2;
	$dbRef = "PMID:".$3;
      } elsif ($item =~ /(GO:\d+) - (.*)/) {
	$goid = $1;
	$product = $2;
      }

      if ($item =~ /;ev_code=(\w+)/) {
	$evCode = $1;
	$evCode = uc ($evCode);
      }
    } else {
      next;
    }
    $evCode = 'IEA' if (!$evCode);
    $product = $products{$sourceId} if (!$product);

    print "$db\t$sourceId\t$sourceId\t\t$goid\t$dbRef\t$evCode\t\t$aspect\t$product\t$sourceId\t$sourceIdType\t$taxonId\t$date\t$db\n";
    #print "$db\t$sourceId\t$sourceId\t\t$goId\t$dbrefs\t$evidenceCode\t$withOrFrom\t$aspect\t$product\t$synonym\t$sourceIdType\ttaxon:$taxonId\t$date\t$assignedBy";
  }
}
close IN;

#############################

sub getAspectForGo {
	my ($line) = @_;
	my $aspect;

	if ($line eq /[C|F|P]/) {
		$aspect = $line; 
	} elsif (lc($line) =~ /component/) {
		$aspect = 'C';
	} elsif (lc($line) =~ /function/) {
		$aspect = 'F';
	} elsif (lc($line) =~ /process/) {
		$aspect = 'P';
	} else {
		$aspect = '';
	}
	return $aspect;
}

sub trim($){
	my $string = shift;
	$string =~ s/^\s+//;
	$string =~ s/\s+$//;
	return $string;
}

sub trimValue($){
	my $string = shift;
	$string =~ s/^\s+//;
	$string =~ s/\s+$//;
	return $string;
}

sub trimIds($){
	my $string = shift;
	$string =~ s/^\s+//;
	$string =~ s/\s+$//;
	$string =~ s/:pep.*$//g;
	$string =~ s/:mRNA.*$//g;
	$string =~ s/:pseudogenic_transcript.*$//g;
	$string =~ s/;current=false*$//g;
	$string =~ s/\.\d$//;  
	return $string;
}




