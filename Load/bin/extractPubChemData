#!/usr/bin/perl

## Retrieves XML-formatted PubChem data (substance or compound) from NCBI based on a file of IDs

use strict;
use LWP::Simple;
use Getopt::Long;

my ($idFile, $outFile, $db_type);
&GetOptions( "idFile=s" => \$idFile,
	     "outFile=s" => \$outFile,
	     "type=s" => \$db_type,
	   );

if (!$idFile || !$outFile || !$db_type) {
  die ' USAGE: extractPubChemData.pl -idFile <idFile>  -outFile <outFile>  -type <pcsubstance | pccompound>';
}
unless(-e $idFile) {
  print STDERR "$idFile file not found! \n";
  exit;
}
unless($db_type eq 'pcsubstance' || $db_type eq 'pccompound') {
  print STDERR "type must be 'pcsubstance' or 'pccompound' \n";
  exit;
}

my $num =100;  # max number of records to download at a time
my $ct = 0;

my $base_url = 'http://eutils.ncbi.nlm.nih.gov/entrez/eutils/esummary.fcgi?db=' . $db_type . '&id=';
my @idArr;
my $resultString;

open (FILE, "$idFile");
while(<FILE>){
   chomp;
   $ct++;
   push @idArr, $_;
   if ($ct % $num == 0) {
     $resultString .= extractData(@idArr);
     @idArr =();
   }
 }
$resultString .= extractData(@idArr);
close(FILE);
processResult($resultString);



sub extractData {
  my (@ids) = @_;
  my $idList = join( ',', @ids );
  my $efetch_url = $base_url . $idList;
  my $efetch_out = get($efetch_url);

  return $efetch_out;
}

sub processResult { 
  my ($result) = @_;
  my @lines = split /\n/, $result;
  my $bool = 0;

  open (OUT, ">$outFile");
  foreach my $line (@lines) {
    if ($line =~ /\<\?xml/ && ($bool)) {
    } elsif  ($line =~ /\<\!DOCTYPE/ && ($bool)) {
    } elsif ($line =~ m/\<\/eSummaryResult\>/ && !($bool)) {
      $bool=1;
    } elsif ($line =~ m/\<eSummaryResult\>/ && ($bool)) {
    }
    else {
      print OUT $line ."\n";
    }
  }
  print OUT "</eSummaryResult\>\n";
}
