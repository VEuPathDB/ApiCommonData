#!/usr/bin/perl

use strict;

use warnings;

use XML::Simple;

use Getopt::Long;

use File::Basename;

use Tie::IxHash;

use Data::Dumper;

use lib "$ENV{GUS_HOME}/lib/perl";

use DBI;

use List::MoreUtils qw(uniq);

use GUS::PluginMgr::Plugin;

use GUS::Model::SRes::OntologyTerm;

use GUS::Model::Study::Study;

my ($inDir, $idColumnName, $dateColumnName, $inputColumnName, $configFile, $outFile, $help,);

&GetOptions('help|h' => \$help,
            'inDir=s' => \$inDir,
            'outFile=s' =>\$outFile,
            'idColumn=s' => \$idColumnName,
            'dateColumn=s' => \$dateColumnName,
            'inputColumn=s' => \$inputColumnName
           );
$idColumnName ='id' unless $idColumnName;
$dateColumnName = 'date' unless $dateColumnName;
my $headerSize = 0;
my @Header;

opendir(DH, $inDir);
my @inputFiles = readdir(DH);
closedir(DH);

my $columns = {};
my $values = {};
my $allIds = {};
my $duplicateIds = {};
foreach my $inFile (@inputFiles) {
  my $isHeader = 1;
  open (INFILE, "$inDir/$inFile") || die "Can't open $inFile for reading : $!\n";
  next if (-d $inFile);
  my $ids = [];
  my $dupIds = [];
  my $idColumn;
  foreach my $row (<INFILE>){
    chomp $row;
    $row=~s/\r//g;
    my %hash;
    if (!$row || $row=~m/^\W$/ || $row=~m/^\s$/ ) {
      next;
    }

    if ($isHeader) {
      $columns = parseHeader($row,$columns,$inFile,$idColumnName);
      $idColumn = $columns->{output}->{$inFile}->{idColumn};
      $isHeader=0;
      next;
    }

    my $ValueMap = parseRow($row);
    my $id = $ValueMap->{$idColumn};
    next unless (defined $id && $id =~/\w/);
    
    unless (exists ($values->{$inFile}->{$id})) {
      $values->{$inFile}->{$id} = $ValueMap;
      push (@$ids,$id) ;
    }
    else { 
      push(@$dupIds,$id);
    }
  }
  
  $allIds->{$inFile}=$ids;
  ($dupIds) = uniq($dupIds);
  $duplicateIds->{$inFile}=$dupIds if (scalar ($dupIds) != 0);
}
my @id_set= values(%$allIds);
my @uniqueIds; 
foreach my $subArray (@id_set){
  push (@uniqueIds, @$subArray);
}
@uniqueIds = uniq(@uniqueIds);

my $confilctedCharacteristics = {};

my $mergedFile = mergeFiles($columns,$values,\@uniqueIds,$confilctedCharacteristics,$dateColumnName,$inputColumnName);
open (OUTPUT, ">$outFile") or die "Unable to open file for writing :$!";
print OUTPUT $mergedFile;
close OUTPUT;
my $absentIds ={};
my $reportFile = $outFile."_Report";
printReport ($allIds,$duplicateIds,\@uniqueIds,$absentIds,$confilctedCharacteristics,$reportFile);

sub parseHeader {
  my ($row,$columns, $fn,$idColumnName) = @_;
  my @Row = split ("," , $row);
  my $columnCount = scalar(@Row);
  my $chars = [];
  for (my $i = 0; $i < $columnCount; $i++) {
    my $value = $Row[$i];
    $value =~ s/^\s+|\s+$//g if defined ($value);
    $value =~ s/^"|"$//g if defined ($value);
    $value = lc($value);
    if ($value =~/^$idColumnName$/) {
      $columns->{output}->{$fn}->{idColumn}=$i;
      next;
    }
    unless (exists ($columns->{characteristic}->{$value})) {
      $columns->{characteristic}->{$value}->{location} = ([{$fn => $i}]);
      $columns->{characteristic}->{$value}->{unique} = 1;
    }
    else {
      $columns->{characteristic}->{$value}->{unique} = 0;
     push  (@{$columns->{characteristic}->{$value}->{location}}, {$fn=>$i});
    }
  }
  return $columns;
}

sub parseRow {
  
  my ($row) = @_;
  my @Row = split ("," , $row);
  my $columnCount = scalar(@Row);
  my $colMap = {};
  my $chars = [];
#  print STDERR $row if ($row !~ /,/);
  for (my $i = 0; $i < $columnCount; $i++) {
    my $value = $Row[$i];
    $value =~ s/^\s+|\s+$//g if defined ($value);
    $value =~ s/^"|"$//g if defined ($value);
    $colMap-> {$i} =$value;
  }
  
  return $colMap;
}

sub mergeFiles {
  my ($columns,$values,$uniqueIds,$confilctedCharacteristics,$dateColumnName,$inputColumnName) = @_;
  #print Dumper ($columns);
  my @sortedCharacteristics = sort(keys(%{$columns->{characteristic}}));
  my $header = 'OUTPUT';
  foreach my $characteristic (@sortedCharacteristics) {
    $characteristic =~ s/^\s+|\s+$//g if defined ($characteristic);
    if ($characteristic =~ /^$dateColumnName$/) {
      $header = $header."\tParameter Value [DATE]";
    }
    elsif ($characteristic =~ /^$inputColumnName$/) {
      $header = $header."\tINPUT";
    }
    else {
      $header = $header."\tCharacteristics [".$characteristic."]";
    }
  }
  my $output = $header;
  my $firstLine = 0;
  foreach my $id (@$uniqueIds)  {
    my $line =$id;
    foreach my $characteristic (@sortedCharacteristics) {
      my $valueLocation;
      my $value;
      my $isUnique = $columns->{characteristic}->{$characteristic}->{unique};
      unless ($isUnique ) { 
        my $charLocations =  $columns->{characteristic}->{$characteristic}->{location};
        $valueLocation = $charLocations->[0];
        my ($valueFile) = keys(%$valueLocation);
        my ($valueCol) = values(%$valueLocation);
        $value = $values->{$valueFile}->{$id}->{$valueCol};
        $value =~ s/^\s+|\s+$//g if defined ($value);
        foreach my $charLocation (@$charLocations) {
          my ($charFile) = keys(%$charLocation);
          my ($charCol) = values(%$charLocation);
          my $charValue = $values->{$charFile}->{$id}->{$charCol};
          $charValue =~ s/^\s+|\s+$//g if defined ($charValue);
          $value = $charValue unless defined($value);
          unless (!defined ($charValue) || $charValue =~ /^$value$/) {
            $confilctedCharacteristics->{$characteristic} = $charLocations;
            $value = 'CONFLICT';
          }
        }
      }
      else {
        $valueLocation = $columns->{characteristic}->{$characteristic}->{location}->[0];
        my ($valueFile) = keys(%$valueLocation);
        my ($valueCol) = values(%$valueLocation);
        $value = $values->{$valueFile}->{$id}->{$valueCol};
        $value =~ s/^\s+|\s+$//g if defined ($value) ;
      }
      $value = '' unless defined ($value);
      $line = $line."\t".$value;
    }
    $firstLine=1;
    $output = $output."\n".$line;
  }
  return $output;
}

sub printReport {
  my ($allIds,$duplicateIds,$uniqueIds,$absentIds,$conflictedCharacteristics,$reportFile) = @_;
  my @fileNames = keys(%$allIds);
  foreach my $fileName (keys(%$allIds)) {
    my $ids = $allIds->{$fileName} ;
    my $grep_ids = join("|",  @$ids);
    my @missingIds = grep { !(/$grep_ids/) } @$uniqueIds;
    if ($grep_ids =~ /\w/) {
      $absentIds->{$fileName} = \@missingIds;
    }
      else {
        $absentIds->{$fileName} = "No valid ids in file";
      }
  }
  open(Report, ">$reportFile") or die "Unable to open file for writing :$!";
#  while( my( $key, $value ) = each( %$conflictedCharacteristics ) ) {
  print Report "Characteristics with conflicting values:\n";
  print Report Dumper ($conflictedCharacteristics);
  print Report "Duplicate Ids in each file, these values are removed from final file: \n";
  print Report Dumper ($duplicateIds);
  print Report "Ids  which do not appear in one of the premerged files: \n";
  print Report Dumper ($absentIds);
  close Report;
}
