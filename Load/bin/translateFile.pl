#!/usr/bin/perl

use strict;

use lib "$ENV{GUS_HOME}/lib/perl";

use GUS::Community::FileTranslator;

use File::Basename;

use Getopt::Long;

use Data::Dumper;


use List::MoreUtils qw(uniq first_index indexes);

my ($inputDirectory, $outputDirectory, $headerConfigDirectory, $mapFile,$externalDatabaseName, $obfuscationFactorFile, $help,);

&GetOptions('help|h' => \$help,
                      'input_directory=s' => \$inputDirectory,
                      'header_cfg_directory=s' => \$headerConfigDirectory,
                      'output_directory=s' => \$outputDirectory,
                      'value_mapping_file=s' =>\$mapFile,
                      'obfuscation_factor_file=s' => \$obfuscationFactorFile,
           );
my $functionArgs = {};

mkdir $outputDirectory unless -d $outputDirectory;
my $logDirectory = $outputDirectory."/logs";
mkdir $logDirectory;

unless (defined $obfuscationFactorFile) {
  die "obfuscation_factor_file or external_database_name must be provided" unless defined $externalDatabaseName;
}

die "Obfuscation factor file $obfuscationFactorFile does not exists, or cannot be found. Please check you file path
or run the generateObfuscationFile.pl script to create this file" unless -e $obfuscationFactorFile;

open (OFF, $obfuscationFactorFile) or die "unable to open file $obfuscationFactorFile";

my $obfuscationFactorHash = {};
foreach my $line (<OFF>) {
  $line =~s/[\n|\r]+//g;
  my ($id,$value) = split("\t",$line);
  $obfuscationFactorHash->{$id} = $value;
}
$functionArgs->{obfuscation_factors}=$obfuscationFactorHash;

if (defined $mapFile){
  open (MAP, $mapFile);
  my $trashHeader = <MAP>;
  my $mapHash = {};
  foreach my $line (<MAP>) {
    $line =~s/[\n|\r]+//g;
    my ($header,$old_value,$new_value) = split("\t",$line);
    $header= lc($header);
    $old_value = lc($old_value);
    $mapHash->{$header}->{$old_value}=$new_value;
  }
  $functionArgs->{map_hash}=$mapHash;
}

opendir(INDIR, $inputDirectory);
my @files = readdir(INDIR);
closedir(INDIR);

foreach my $dataFile (@files) {
  next if (-d "$inputDirectory/$dataFile");

  my $xmlFile = $headerConfigDirectory."/".$dataFile.".cfg";
  $xmlFile =~s/\/+/\//g;
  
  my $resultFile = fileparse($dataFile);
  $resultFile =~s/processed$/translated/;

  my $logFile = $logDirectory."/".$resultFile.".log";
  $logFile =~s/\/+/\//g;

  $resultFile = $outputDirectory."/".$resultFile;
  $resultFile =~s/\/+/\//g;
  
  $dataFile = "$inputDirectory/$dataFile";
  $dataFile =~ s/\/+/\//;
  my $fileTranslator = GUS::Community::FileTranslator->new($xmlFile, $logFile);
  $fileTranslator->translate($functionArgs, $dataFile, $resultFile);
}

