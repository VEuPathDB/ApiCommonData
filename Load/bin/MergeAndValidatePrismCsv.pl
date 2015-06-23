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

my ($inDir, $idColumnName, $dateColumnName, $inputColumnName, $outFile, $parentFile, $parentFileIdColumn, $help,);

&GetOptions('help|h' => \$help,
                      'inDir=s' => \$inDir,
                      'outFile=s' =>\$outFile,
                      'idColumn=s' => \$idColumnName,
                      'dateColumn=s' => \$dateColumnName,
                      'parentIdColumn=s' => \$inputColumnName,
                      'parentFile=s' => \$parentFile,
                      'parentFileIdColumn=s' => \$parentFileIdColumn,
           );
$idColumnName ='id' unless $idColumnName;
$dateColumnName = 'date' unless $dateColumnName;

my $parentIdsHash = {};

if (defined $inputColumnName || defined $parentFile || defined $parentFileIdColumn) {
  die "To validate parent ids, the parentIdColumn, parentFileName and parentFileIdColumn must all be provided.". 
         "if you do not wish to validate these ids, or if there is no parent entity type, these values should be null" 
           unless (defined $inputColumnName && defined $parentFile && defined $parentFileIdColumn);
  open (PARENT_ID_FILE, $parentFile) or die "unable to open parent file $parentFile: $!"  ;
  my $isHeader = 1;
  my $parentIdIndex;
  foreach my $row (<PARENT_ID_FILE>) {
    my $values = split("\t" , $row);
    if ($isHeader) {
      my %index;
      @index{@$values} = (0..$#$values);
      $parentIdIndex = $index{$parentFileIdColumn};
      die "ParentFileIdColumn  $parentFileIdColumn not found in $parentFile" unless defined $parentIdIndex;
      $isHeader = 0;
      next;
    }
    my $parentId = $values->[$parentIdIndex];
    $parentIdsHash->{$parentId} = 1;
  }
}
my $headerSize = 0;
my @Header;
my $idToParentIdMap = {};
opendir(DH, $inDir) or die "unable to open to open dir $inDir: $!";
my @inputFiles = readdir(DH);
closedir(DH);

my $columns = {};
my $values = {};
my $allIds = {};
my $duplicateIds = {};
my $invalidParentIds = {};

foreach my $inFile (@inputFiles) {
  my $isHeader = 1;
  my $parentIdIndex;
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
      $parentIdIndex = $columns->{characteristic}->{$inputColumnName}->{location}->[0]->{$inFile};
      $isHeader=0;
      next;
    }

    my $ValueMap = parseRow($row);
    my $id = $ValueMap->{$idColumn};
    my $parentId;
    $parentId = $ValueMap->{$parentIdIndex};
    next unless (defined $id && $id =~/\w/);
    
    if (exists $parentIdsHash->{$parentId}) {
      $idToParentIdMap->{$id} = $parentId;
    }
    elsif (exists $invalidParentIds->{$inFile}->{$parentId}) {
      push (@{$invalidParentIds->{$inFile}->{$parentId}}, $id);
    }
    else {
      $invalidParentIds->{$inFile}->{$parentId} = [$id];
    }

    unless (exists ($values->{$inFile}->{$id})) {
      $values->{$inFile}->{$id} = $ValueMap unless exists $invalidParentIds->{$inFile}->{$parentId} ;
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

my $mergedFile = mergeFiles($columns,$values,\@uniqueIds,$invalidParentIds,$confilctedCharacteristics,$dateColumnName,$inputColumnName);
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
  die "Id column named $idColumnName not found, please provide the correct IdColumnName" unless exists $columns->{output}->{$fn}->{idColumn};
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
  my ($allIds,$duplicateIds,$uniqueIds,$invalidParentIds,$absentIds,$conflictedCharacteristics,$reportFile) = @_;
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
  print Report "ids with invalid parent Ids\n";
  print Report Dumper ($invalidParentIds);
  print Report "Characteristics with conflicting values:\n";
  print Report Dumper ($conflictedCharacteristics);
  print Report "Duplicate Ids in each file, these values are removed from final file: \n";
  print Report Dumper ($duplicateIds);
  print Report "Ids  which do not appear in one of the premerged files: \n";
  print Report Dumper ($absentIds);
  close Report;
}
