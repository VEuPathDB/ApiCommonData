#!/usr/bin/perl

use strict;

use GUS::Community::FileTranslator;

use File::Basename;

use Getopt::Long;

use Data::Dumper;

use lib "$ENV{GUS_HOME}/lib/perl";

use List::MoreUtils qw(uniq first_index indexes);

my ($inDir, $outDir, $cfgDir, $mapFile, $help,);

&GetOptions('help|h' => \$help,
                      'input_directory=s' => \$inDir,
                      'header_cfg_directory=s' => \$cfgDir,
                      'output_directory=s' => \$outDir,
                      'value_mapping_file=s' =>\$mapFile,
           );
my $functionArgs = {};

mkdir $outDir unless -d $outDir;

if (defined $mapFile){
  open (MAP, $mapFile);
  my $trashHeader = <MAP>;
  my $mapHash = {};
  foreach my $line (<MAP>) {
    $line =~s/[\n|\r]+//g;
    my ($header,$old_value,$new_value) = split("\t",$line);
    $mapHash->{$header}->{$old_value}=$new_value;
  }
  $functionArgs->{map_hash}=$mapHash;
}

opendir(INDIR, $inDir);
my @files = readdir(INDIR);
closedir(INDIR);

foreach my $dataFile (@files) {
  next if (-d "$inDir/$dataFile");


  my $xmlFile = $cfgDir."/".$dataFile.".cfg";
  $xmlFile =~s/\/+/\//g;
  my $logFile = $outDir."/".$dataFile.".log";

  $logFile =~s/\/+/\//;
  
  my $resultFile = fileparse($dataFile);
  $resultFile = $outDir."/".$resultFile;
  $resultFile =~s/processed$/translated/;
  $resultFile =~s/\/+/\//g;

  my $logFile = $resultFile.".log";

  $dataFile = "$inDir/$dataFile";
  $dataFile =~ s/\/+/\//;
  my $fileTranslator = GUS::Community::FileTranslator->new($xmlFile, $logFile);
  $fileTranslator->translate($functionArgs, $dataFile, $resultFile);
}

