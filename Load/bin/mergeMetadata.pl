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

use List::MoreUtils qw(uniq first_index indexes);

my ($inDir, $outFile, $allowNonUnique, $delimiter, $uniqRegex, $masterFiles, $parentFile, $help,);

$delimiter = "\t";
$uniqRegex = '.\d+';

&GetOptions('help|h' => \$help,
                      'input_directory=s' => \$inDir,
                      'output_file=s' => \$outFile,
                      'expect_multiple_values=s' => \$allowNonUnique,
                      'uniquifying_regexp=s' => \$uniqRegex,
                      'delimiter=s' => \$delimiter,
                      'parent_file=s' => \$parentFile,
                      'master_files=s' => \$masterFiles,
           );

my $idFieldName ='OUTPUT';
my $parentIdFieldName = 'INPUT';
my $dateFieldName = 'Parameter Values [Date]';

opendir(DH, $inDir) or die "unable to open to open dir $inDir: $!";
my @inputFiles = readdir(DH);
closedir(DH);

my $dataMap = {};
my $skipIds ={};
my $parentIdMap = {};
my $allDataHash = {};
my $allIds = {};
my $confilctedCharacteristics = {};
my ($lower_idFieldName,$lower_parentIdFieldName,$lower_dateFieldName);
$lower_idFieldName = lc($idFieldName);
$lower_parentIdFieldName = lc($parentIdFieldName) if defined $parentIdFieldName;
$lower_dateFieldName = lc($dateFieldName) if defined $dateFieldName;

foreach my $inFile (@inputFiles) {
  my $isHeader = 1;
  
  open (INFILE, "$inDir/$inFile") || die "Can't open $inFile for reading : $!\n";
  next if (-d $inFile);
  my ($idColumnIdx,$parentIdColumnIdx,$dateColumnIdx);
  my $row_number = 0;
  foreach my $row (<INFILE>){
    chomp $row;
    $row=~s/\r//g;
    my %hash;
    if (!$row || $row=~m/^\s$/ ) {
      ++$row_number;
      next;
    }
    if ($isHeader) {
      my $columns = parseHeader($row,$delimiter,$uniqRegex);
      foreach my $key (keys %$columns) {
        push (@{$dataMap->{$key}->{$inFile}},  @{$columns->{$key}}) ;
      }
      $lower_idFieldName = lc($idFieldName);
      $lower_parentIdFieldName = lc($parentIdFieldName) if defined $parentIdFieldName;
      $lower_dateFieldName = lc($dateFieldName) if defined $dateFieldName;
      $idColumnIdx = $dataMap->{$lower_idFieldName}->{$inFile}->[0];
      $parentIdColumnIdx = $dataMap->{$parentIdFieldName}->{$inFile} if exists  $dataMap->{$parentIdFieldName} ;
      $dateColumnIdx = $dataMap->{$dateFieldName}->{$inFile} if exists  $dataMap->{$dateFieldName} ;;
      $isHeader=0;
      ++$row_number;
      next;
    }

    
    my $rowDataHash = parseRow($row,$delimiter,$dataMap, $inFile, $idColumnIdx,);
    next unless defined $rowDataHash;
    my ($id) = keys %$rowDataHash;
    if (defined $parentFile){
      my $parentId = $rowDataHash->{$id}->{$lower_parentIdFieldName}->[0];
      unless (exists ($parentIdMap->{$id} )) {
        $parentIdMap->{$id}->{parent} = $parentId if defined $parentId;
      }
      elsif (ref $parentIdMap->{$id}->{parent} eq 'ARRAY') {
        if (scalar(uniq (grep {defined} @{$parentIdMap->{$id}->{parent}})) > 1) {
          #print STDERR Dumper $parentIdMap->{$id}->{parent};
          push (@{$parentIdMap->{$id}->{parent}}, $parentId) if (defined $parentId && !(grep { /$parentId/ } @{$parentIdMap->{$id}->{parent}}) ) ;
          $parentIdMap->{$id}->{invalid} = 1; 
          $skipIds->{$id}->{Multiple_Parents} = $parentIdMap->{$id}->{parent};
          $allDataHash->{$id}->{_exclude_flag_} = 1;
        }
      }
      elsif (defined $parentId && !( $parentIdMap->{$id}->{parent} =~ $parentId) ) {
        $parentIdMap->{$id}->{parent} = [ $parentIdMap->{$id}->{parent} , $parentId ] ;
        $parentIdMap->{$id}->{invalid} = 1;
        $skipIds->{$id}->{Multiple_Parents} = $parentIdMap->{$id}->{parent};
        $allDataHash->{$id}->{_exclude_flag_} = 1;

      }
    }
    if ($id eq 'none') {
      unless (exists $skipIds->{$id}->{Blank} ) {
        $skipIds->{$id}->{Blank} = [ "$inFile:$row_number" ];
      }
      else {
        push @{$skipIds->{$id}->{Blank}}, "$inFile:$row_number";
      }
      $allDataHash->{$id}->{_exclude_flag_} = 1;
      next;
    }
    elsif (exists $allIds->{$inFile}->{$id}) {
      unless (exists $skipIds->{$id}->{Dupe} ) {
        my $otherLocation = $allIds->{$inFile}->{$id};
        $skipIds->{$id}->{Dupe} = [ $otherLocation, "$inFile:$row_number" ];
      }
      else {
        push @{$skipIds->{$id}->{Dupe}}, "$inFile:$row_number";
      }
      $allDataHash->{$id}->{_exclude_flag_} = 1;
    }
    else {
      $allIds->{$inFile}->{$id} =  "$inFile:$row_number";
      foreach my $characteristic ( keys %{$rowDataHash->{$id}} ) {
        unless (exists $allDataHash->{$id}->{$characteristic}) {
          $allDataHash->{$id}->{$characteristic} = $rowDataHash->{$id}->{$characteristic};
        }
        else {
          push @{$allDataHash->{$id}->{$characteristic}}, @{$rowDataHash->{$id}->{$characteristic}};
        }
      }
    }
    ++$row_number
  }
}
my $uniqIds;

foreach my $key (keys %$allIds) {
  push (@$uniqIds,keys %{$allIds->{$key}});
}

@{$uniqIds} = sort(uniq(split (";",(join ';' , @$uniqIds))));

$skipIds =validateParentIds($uniqIds,$parentIdMap,$skipIds,$parentFile,$delimiter ) if defined $parentFile;

foreach my $skipId (keys %{$skipIds}) {
  $allDataHash->{$skipId}->{_exclude_flag_}=1;
}
my ($outputLines,$conflictedCharacteristics,);
($outputLines,$conflictedCharacteristics,$skipIds) = mergeFiles($allDataHash,$dataMap,$uniqIds,$skipIds,$lower_idFieldName,$lower_parentIdFieldName,$lower_dateFieldName);
my $mergedFileText = join("\n",@$outputLines);
open (OUTPUT, ">$outFile") or die "Unable to open file for writing :$!";
print OUTPUT $mergedFileText;
close OUTPUT;



my $reportLines = prepareReport ($uniqIds,$skipIds,$confilctedCharacteristics,);
my $reportFile = $outFile."_Report";
if (scalar @$reportLines > 1 ) {
  print STDERR "Issues were found with you input files, please consult the report file $reportFile for details";
  my $reportFileText = join("\n",@$reportLines);
  open (REPORT, ">$reportFile") or die "Unable to open file for writing :$!";
  print REPORT $reportFileText;
  close REPORT;
}


sub parseHeader {
  my ($row, $delimiter,$uniqRegex) = @_;
  my @Row = split ($delimiter , $row);
  my $columnCount = scalar(@Row);
  my $columns;
  for (my $i = 0; $i < $columnCount; $i++) {
    
    my $characteristic = $Row[$i];
    $characteristic =~ s/^\s+|\s+$//g if defined ($characteristic);
    $characteristic =~ s/^"|"$//g if defined ($characteristic);
    $characteristic =~ s/$uniqRegex$//gi;
    $characteristic = lc($characteristic);
    unless (exists ($columns->{$characteristic})) {
      $columns->{$characteristic} = [$i];
    }
    else {
      push  (@{$columns->{$characteristic}}, $i);
    }
  }
  return $columns;
}

sub parseRow {
  my ($row,$delimiter,$dataMap, $fn, $idColumnIdx,) = @_;
  my @Row = split ($delimiter , $row);
  my $id = $Row[$idColumnIdx];

  $id = 'none' unless (defined $id && $id=~/\w/);
  my $rowDataHash;  

  foreach my $characteristic (keys %$dataMap){
    foreach my $location (@{ $dataMap->{$characteristic}->{$fn}  }){
      if (exists $rowDataHash->{$id}->{$characteristic}) {
        push (@{$rowDataHash->{$id}->{$characteristic}}, $Row[$location]) if (defined  $Row[$location]);
      }
      else {
        $rowDataHash->{$id}->{$characteristic}= [$Row[$location]] if (defined  $Row[$location]);
      }
    }
  }

  return $rowDataHash;
}

sub validateParentIds {
  my ( $uniqIds,$parentIdMap,$skipIds,$parentFile,$delimiter ) = @_;
  
  my $validParentIds = {};
  
  open (PARENT, $parentFile) or die "unable to open the file $parentFile to look up parent id: $!";
  
  my $parentHeader =  <PARENT>;
  $parentHeader =~ s/\n|\r//g;
  my @parentHeaderFields = split ($delimiter, $parentHeader);
  my $parentFieIdIdx = first_index { /^OUTPUT$/i } @parentHeaderFields ;

  foreach my $row (<PARENT>) {
    my @parentFileFields = split ($delimiter, $row);
    my $idHolder = $parentFileFields[$parentFieIdIdx ];
    $validParentIds->{$idHolder} = 1;
  }
  foreach my $id (@$uniqIds) {
    next if exists $skipIds->{$id};
    unless (exists ($parentIdMap->{$id})) {
      $skipIds->{$id}->{Orphan} = "TRUE" ;
      next;
    }
    my $parentId = $parentIdMap->{$id}->{parent} ;
    if ($parentIdMap->{$id}->{invalid}) {
      $skipIds->{$id}->{Invalid_Parent} = $parentId ;
      next;
    }
    unless (exists $validParentIds->{$parentId}) {
      $skipIds->{$id}->{Invalid_Parent} = $parentId unless exists $validParentIds->{$parentId};
    }
  }
  return ($skipIds);
}

sub mergeFiles {
  my ($allDataHash,$dataMap,$uniqIds,$skipIds,$idFieldName,$parentIdFieldName,$dateFieldName) = @_;
  my @sortedCharacteristics = sort(keys(%{$dataMap}));
  my $dateFieldIdx = first_index { $_ =~ /^$dateFieldName$/ } @sortedCharacteristics;
  unless ( $dateFieldIdx == -1 ) {
    splice (@sortedCharacteristics,$dateFieldIdx,1);
    unshift (@sortedCharacteristics, $dateFieldName);
    
  }
  if (defined $parentIdFieldName) {
     my $parentIdFieldIdx = first_index { $_ =~ /^$parentIdFieldName$/ } @sortedCharacteristics;
     unless ( $parentIdFieldIdx == -1 ) {
       splice (@sortedCharacteristics,$parentIdFieldIdx,1);
       unshift (@sortedCharacteristics, $parentIdFieldName);
     }
   }
  my $idFieldIdx = first_index { $_ =~ /^$idFieldName$/ } @sortedCharacteristics;

  splice (@sortedCharacteristics,$idFieldIdx,1);
  unshift (@sortedCharacteristics, $idFieldName);

  my $outputLines = [join("\t",@sortedCharacteristics)];
  foreach my $id (@$uniqIds){
    next if $allDataHash->{$id}->{_exclude_flag_};
    my $line = [];
    foreach my $characteristic (@sortedCharacteristics) {
      my $valueString = '';
      $valueString = join ("|", uniq(@{$allDataHash->{$id}->{$characteristic}}) ) if exists ($allDataHash->{$id}->{$characteristic}); 
       if ($valueString=~/\|/) {
         $valueString =~s/\|\s*\|/\|/;
         $valueString =~s/^\|//;
         $valueString =~s/\|$//;
         

         if ($characteristic =~ /^$dateFieldName$/ ){
           $skipIds->{$id}->{DATE_CONFLICT} = $valueString;
           next;
         }
         unless (exists $conflictedCharacteristics->{$characteristic} ) {
           $conflictedCharacteristics->{$characteristic} = [$id];
         }
         else {
           push (@{$conflictedCharacteristics->{$characteristic}},$id);
         }
       }
       push (@$line, $valueString);
     }
     push (@$outputLines, join("\t",@$line));
   }
   return ($outputLines, $conflictedCharacteristics, $skipIds);
}

sub prepareReport {
  my ($uniqIds,$skipIds,$conflictedIds) = @_;
  my $duplicateIdLines = [];
  my $blankIdLines = [];
  my $orphanLines =  [];
  my $multipleParentLines = [];
  my $invalidParentLines = [];
  my $reportLines = [];

  foreach my $id (keys %$skipIds) {
    if (exists $skipIds->{$id}->{Dupe}) {
      my $fileNames = [];
      my $locations = [];
      push @$duplicateIdLines, "$id :";
        foreach my $location (@{$skipIds->{$id}->{Dupe}}) {
          my ($fileName,$line) = split (":",$location);
          push (@$fileNames,$fileName);
          push (@$locations,"\t\t$line");
      }
      my $fn = $fileNames->[0];
      push @$duplicateIdLines, "\t$fn :";
      push @$duplicateIdLines, @$locations;
    }
    if (exists $skipIds->{$id}->{Blank}) {
      my $fileNames = [];
      my $locations = [];
      foreach my $location (@{$skipIds->{$id}->{Blank}}) {
        my ($fileName,$line) = split (":",$location);
        push (@$fileNames,$fileName);
        push (@$locations,"\t\t$line");
      }
      my $fn = $fileNames->[0];
      push @$blankIdLines, "/t$fn :";
      push @$blankIdLines, @$locations;
    }
    if (exists $skipIds->{$id}->{Orphan}) {
      push @$orphanLines, $id;
    }
    if (exists $skipIds->{$id}->{Multiple_Parents}) {
      my $parentIds = [];
      push @$multipleParentLines, "id :$id";
        foreach my $parentId (@{$skipIds->{$id}->{Multiple_Parents}}) {
          push @$parentIds, $parentId;
        }
      my $parent_id_set = join(",",@$parentIds);
      push @$multipleParentLines, "parent ids : $parent_id_set";
    }
    if (exists $skipIds->{$id}->{Invalid_Parents}) {
      my $parentId = $skipIds->{$id}->{Invalid_Parents};
      push @$invalidParentLines, "id :$id\t\t parent id : $parentId"
    }
  }
  push @$reportLines, "Your file contains data which could not be merged for the following reasons.
Any data associated with these ids and rows will not appear in your merged file. 
Please correct these errors and rerun the merge script";
  if (scalar @$duplicateIdLines){
    push @$reportLines, "The following non-unique ids were found in your files. All Id's must be unique";
    push @$reportLines, @$duplicateIdLines;
  }
  if (scalar @$blankIdLines){
    push @$reportLines, "The following rows with no id were found in your files. Rows must have an id";
    push @$reportLines, @$blankIdLines;
  }
   if (scalar @$orphanLines){
     push @$reportLines, "The following id(s) with no associated parent id were found in your files. if you provide a parent file, all rows must have a parent_id, ";
     push @$reportLines, @$orphanLines;
   }
  if (scalar @$multipleParentLines ){
    push @$reportLines, "The following ids were found with multiple associated parent id were found in your files. only parent id is allowed for each id, ";
      push @$reportLines, @$multipleParentLines;
  }
  if (scalar @$invalidParentLines){
    push @$reportLines, "The following ids were found an associated parent id that is not present  were found in your files. only parent id is allowed for each id, ";
    push @$reportLines, @$invalidParentLines;
  }

  return $reportLines;
}
