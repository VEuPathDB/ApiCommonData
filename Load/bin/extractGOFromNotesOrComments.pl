#!/usr/bin/perl

use strict;
use Getopt::Long;
use HTTP::Date;

my ($date, ) = split(" ", HTTP::Date::time2iso());
$date = join("",split(/-/,$date));

my ($help, $notesFile, $db, $taxonId, $productFile);

&GetOptions(
	    'help|h' => \$help,
	    'notesFile=s' => \$notesFile,
	    'productFile=s' => \$productFile,
	    'database=s' => \$db,
	    'taxonId=s' => \$taxonId,
           );

&usage() if($help);
&usage("Missing a Required Argument") unless (defined $notesFile && $taxonId && $db);

$taxonId = "taxon:".$taxonId;

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

open (IN, "$notesFile") || die "can not open $notesFile to read\n";
while (<IN>) {
  chomp;
  my ($sourceId, $line) = split (/\t/, $_);
  my $sourceIdType = "transcript";

  my @items = split (/\; GO/, $line) if ($line);
  #my @items = split (/\; /, $line) if ($line);

  foreach my $item (@items) {
    my ($aspect, $goid, $product, $evCode, $dbRef);
    $item = "GO".$item if ($item =~ /^\_function:/ || $item =~ /^\_process:/ || $item =~ /^\_component:/);

    if ($item =~ /^GO_(\w+)/) {
      $aspect = getAspectForGo ($item);

      #if ($item =~ /(GO:\d+) - (.*)$/) {  ## this is only for tgonVEG
      #if ($item =~ /(GO:\d+) - (.*?);/) {  ## this is for hhamHH34 only
      #if ($item =~ /(GO:\d+);.* - (.*) \[PMID (\d+)\]/) { # for ntetFGSC2508
      if ($item =~ /(GO:\d+);.* - (.*)/) { # for alucCBS106.47
	$goid = $1;
	$product = $2;
	$product =~ s/ \[PMID (\d+)\]//;
	$product =~ s/ \[Evidence (\S+?)\]//;
      } elsif ($item =~ /(GO:\d+) - (.*)/) {
	$goid = $1;
	$product = $2;
	$product =~ s/(.+)\;.*/$1/;
	$product =~ s/ \[PMID (\d+)\]//;
	$product =~ s/ \[Evidence (\S+?)\]//;
      }

      if ($item =~ /\[PMID (\d+)\]/) {
	$dbRef = "PMID:".$1;
      }
      if ($item =~ /;ev_code=(\w+)/ || $item =~ /\[Evidence\s+(\S+?)\]/ ) {
	$evCode = $1;
	$evCode = uc ($evCode);
      }
    } else {
      next;
    }
    $evCode = 'IEA' if (!$evCode);
    $product = $products{$sourceId} if (!$product);

    my @evCodes = split (/\,/, $evCode);
    my $preEc;
    foreach my $ec (@evCodes) {
      print "$db\t$sourceId\t$sourceId\t\t$goid\t$dbRef\t$ec\t\t$aspect\t$product\t$sourceId\t$sourceIdType\t$taxonId\t$date\t$db\n" if ($ec ne $preEc);
      $preEc = $ec;
    }
#    print "$db\t$sourceId\t$sourceId\t\t$goid\t$dbRef\t$evCode\t\t$aspect\t$product\t$sourceId\t$sourceIdType\t$taxonId\t$date\t$db\n";

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

sub usage {
  die
"
Extract GO annotation from comment or note file extracted from genbank annotation file

Usage:  extractGOFromNotesOrComments.pl --notesFile --taxonId --database [--productFile]
          note: The regExp for GoId may need to change, double check script and select the correct one

where
  --notesFile:    Required, a tab delimited comment or note file extracted from genbank annotation file
  --taxonId:      Required, NCBI taxon ID
  --database:     Required, GenBank, GeneDB, EupathDB ...
  --productFile:  Optional, give a product.txt file if there is no product info in Note or Comment file

";
}

