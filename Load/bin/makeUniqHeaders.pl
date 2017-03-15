#!/usr/bin/perl

use strict;

use warnings;

use Getopt::Long;

use Data::Dumper;

use lib "$ENV{GUS_HOME}/lib/perl";

use List::MoreUtils qw(uniq);

my ($inDir, $outDir, $configFile, $headerFile, $help,);

&GetOptions('help|h' => \$help,
                      'input_directory=s' => \$inDir,
                      'output_directory=s' => \$outDir,
                      'header_file=s' => \$headerFile,
           );

$outDir = defined $outDir ? $outDir : $inDir."/ProcessedFiles";


$headerFile = defined $headerFile ? $headerFile : $inDir."/UniqHeaders.txt";
$headerFile =~ s/\/+/\//g;

my $headerFileSource = defined $headerFile ? $headerFile."_w_source" : $outDir."/UniqHeaders_w_source.txt";
$headerFileSource =~ s/\/+/\//g;

mkdir $outDir unless ( -d $outDir );

opendir(DH, $inDir) or die "unable to open dir $inDir: $!";
my @inputFiles = readdir(DH);
closedir(DH);

my $uniqHeaders = [];
my $uniqWithSource = [];

foreach my $inFile (@inputFiles) {
  my $inFilePath ="$inDir/$inFile";
  $inFilePath =~ s/\/+/\//g;
  next if ( -d "$inFilePath");

  open (IN, $inFilePath) or die "unable to open file $inFilePath: $!";
  my $oldHeader = (<IN>);
  $oldHeader =~s/\n|\r//g;
  my $inFields = [];
  my $outFields = [];
  @ {$inFields} = (split("\t", $oldHeader));
  my $headerHash = {};

  foreach my $field (@$inFields) {
    $field = lc($field);
    if (exists $headerHash->{$field}) {
      my $occurance = $headerHash->{$field}->{occurance};
      push (@$outFields, $field.".".$occurance);
      $headerHash->{$field}->{occurance} = $occurance + 1;
      push @{$headerHash->{$field}->{source}}, $inFile;
    }
    else {
      $headerHash->{$field}->{occurance}=1;
      $headerHash->{$field}->{source} = [$inFile];
      push (@$outFields, $field);
    }
  }


  push @$uniqHeaders, (keys %$headerHash);
  my $outFile = $outDir."/".$inFile."_processed";
  open (OUT, ">$outFile");
  my $new_header = join ("\t", @$outFields);
  print OUT $new_header."\n";
  foreach my $line (<IN>) {
    $line =~s/\n|\r//g;
    print OUT $line."\n";  
  }
  close IN;
  close OUT;
  @{$uniqHeaders} = sort(uniq(@$uniqHeaders));
  #if ($includeSources) {
  foreach my $header (@{$uniqHeaders}) {
    next unless exists $headerHash->{$header};
    my $sources = join(',',(sort(uniq(@{$headerHash->{$header}->{source}})))) ;
    push (@{$uniqWithSource}, $header."\t".$sources);
  }
  #}
}

#open (HEADERS_W_SOURCE, ">$headerFileSource");
#print HEADERS_W_SOURCE  join ("\n",@$uniqWithSource);

#close HEADERS_W_SOURCE;
@{$uniqHeaders} = sort(uniq(@$uniqHeaders));
$headerFile =~ s/\/+/\//g;

my $headerSet = join ("\n",@$uniqHeaders);
open (HEADERS, ">$headerFile");
print HEADERS $headerSet;



