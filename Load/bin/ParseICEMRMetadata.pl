#!/usr/bin/perl

use strict;

use warnings;

use XML::Simple;

use Getopt::Long;

use File::Basename;

use lib "$ENV{GUS_HOME}/lib/perl";

use DBI;

use Data::Dumper;

use CBIL::Util::PropertySet;

my ($inFile, $dataFile, $outFile, $valueMapFile, $headerMapFile, $help, $force);
my $delimiter = "\t";

&GetOptions('help|h' => \$help,
            'metadataFile=s' => \$inFile,
	    'valueMapFile=s' => \$valueMapFile,
            'headerMapFile=s'=> \$headerMapFile,
            'dataFile=s' => \$dataFile,
            'outFile=s' => \$outFile,
            'delimiter=s' => \$delimiter,
            'force|f' =>\$force,
           );

#&usage() if($help);
#&usage("Input dir containing csv files is required") unless(-e $inDir);
#&usage("Output file name is required") unless($outFile);


my @printHshArr = ();
my %canonTerms;

my $isHeader = 1;
my $headerSize = 0;
my @Header;
my @Samples;
my $mapHash = {};
my $ColumnMap = {};
my $sample_ids = [];
my $sourceNames = [];
my $origin = " ";

my $gusConfigFile = $ENV{GUS_HOME} . "/config/gus.config";

my @properties = ();
my $gusconfig = CBIL::Util::PropertySet->new($gusConfigFile, \@properties, 1);

my $u = $gusconfig->{props}->{databaseLogin};
my $pw = $gusconfig->{props}->{databasePassword};
my $dsn = $gusconfig->{props}->{dbiDsn};
my $dbh = DBI->connect($dsn, $u, $pw) or die DBI::errstr;

open (MAP, $valueMapFile) || die "Can't open $valueMapFile for reading : $!\n";
foreach my $line (<MAP>){
  chomp $line;
  my @row = split(/\t/,$line);
  my $characteristic = $row[0];
  my $skipCol = 1;

  foreach my $col (@row) {
    if ($skipCol) {
      $skipCol = 0;
      next;
    }
    my ($key,$value) = split (/:/,$col);
    $mapHash->{$characteristic}->{$key} = $value;
  }
  close MAP;
}

my $headerMapHash = {};
if (defined ($headerMapFile)) {
  open (MAP, $headerMapFile) || die "Can't open $headerMapFile for reading : $!\n";
  foreach my $line (<MAP>){
    chomp $line;

    my ($inputValue,$correctedValue) = split (/:/,$line);
    $inputValue = lc($inputValue);
    $headerMapHash->{$inputValue} = $correctedValue;
  }
}


open (OUTFILE, ">$outFile") || die "Can't open $outFile for writing\n";
open (INFILE, $inFile) || die "Can't open $inFile for reading : $!\n";
my $rowCount = 0;
my $lines = {};
my $charSet;
foreach my $row (<INFILE>){

  chomp $row;
  my %hash;
  if ($isHeader) {
    $ColumnMap = parseHeader($dbh,$row,$headerMapHash);
    $isHeader=0;
    $charSet = $ColumnMap->{"characteristics"};
    print OUTFILE 'Source Name'."\t";
    my $first = 1;
    foreach my $char (@$charSet) {
      my $token = $char;
      # if ($char =~ /subject/) {
      #   $token = "Comment [subject]";
      # }
      if ($char =~ /sample.?id/i) {
        print $char;
        $token = "Comment [sample_id]";
      }
      else {
        $token = "Characteristics [".$char."]";
      }
      unless ($first) {
        $token = "\t$token";
      }
      $first = 0;
      print OUTFILE $token;
    }
    print OUTFILE "\n";
    next;
  }
  my $values = [split ("\t" , $row)];
  my $counter = 0;
  my $colCount;
  my $finalValues = [];
  my $sourceName="";
  my $sample_id = " ";
  foreach my $val ( @$values ) {
    $colCount = scalar @$charSet;
    my $currentChar = $charSet->[$counter];
    next unless (defined $currentChar);
    $origin = $val if (defined $currentChar && $currentChar =~ /^sample.?origin$/i);
    $sample_id = $val if $currentChar =~ /sample_id/i;
    my $holder = $val;
    $holder = ' ' unless $holder;
    $holder = $mapHash->{$charSet->[$counter]}->{ $val } if ($mapHash->{$charSet->[$counter]}->{ $val });
    $counter++;
    push ( @$finalValues,  $holder );
  }
  $sourceName = $origin."_".$sample_id;
  $sourceName =~ s/ /_/;
  push (@$sample_ids, $sample_id);
  push (@$sourceNames, $sourceName);
  unshift ( @$finalValues, $sourceName );

  my $line = join ("\t",@$finalValues);
   while ($counter < $colCount) {
	  $line = $line ."\t";
	  $counter++;
	}
  $line =~ s/ \t/\t/g;
  $lines->{$sourceName}=$line;
}

close INFILE;
my $matchedIds =  validateSampleNames ($dataFile, $sample_ids, $sourceNames, $origin);
while (my ($id,$outline) = each %$lines) {
  if (grep { ($_ ~~ $id ) } @$matchedIds) {
    print OUTFILE $outline."\n";
  }
}
close OUTFILE;

sub validateSampleNames {
  my ($dataFile , $sample_ids, $sourceNames, $origin) = @_;
  my $isHeader = 1;
  my $dataSampleNames;
  my $dataOut = [];
  my $discardOut = [];
  my $lineHolder = [];
  my $index = 0;
  my $validIndices = [];
  my $invalidIndices = [];
  my $validSampleNames = [];
  my $invalidSampleNames = [];
  my $filteredLine = [];
  open (DATAIN, "<$dataFile") || die "Can't open $dataFile for reading\n";
  while (<DATAIN>) {
    my $line = $_;
    chomp $line;
    $line=~s/\r//g;
    if ($isHeader) {
      my $tempSampleNames = [];
      $dataSampleNames = [split ("$delimiter" , $line)];
      splice(@$dataSampleNames, 0, 1);
      $isHeader = 0;
      foreach my $sample (@$dataSampleNames) {
        $sample=~s/"//g;
        my $sample_id_string = $origin."_".$sample unless grep { /^$sample$/ } @$sourceNames;
        $sample_id_string =~ s/ +/_/g unless $sample_id_string =~ /^\s+$/;
        if (grep { /^$sample_id_string$/ } @$sourceNames) {
          push (@$validIndices, $index);
          push (@$validSampleNames, $sample_id_string) unless grep { /^$sample_id_string$/ } @$validSampleNames;
         }
        else {
          push (@$invalidIndices, $index);
          push (@$invalidSampleNames, $sample);
        }
        push (@$tempSampleNames, $sample_id_string);
        $index++;
      }
      $dataSampleNames=$tempSampleNames;
    }
    else {
      $line=~s/$delimiter/\t/g;
      my @splitLine = split(/\t/, $line);
      for my $validIndex (@$validIndices) {
#        $line=$line."\t".$splitLine[@$validIndex];
      }
      push (@$dataOut, $line);
    }
  }
  my $count = 0;

  close DATAIN;
  open (DATAOUT, ">profiles.txt") || die "Can't open profiles.txt for writing\n";
  my $output = "ID\t".join ("\t",@$dataSampleNames);
  print DATAOUT $output."\n";
  $output = join ("\n",@$dataOut);
  print DATAOUT $output;
  my @unmatchedFromMetadata = grep { !($_ ~~ @$validSampleNames ) } @$sourceNames;
  my @unmatchedFromData = grep { !($_ ~~ /^$/ ) } @$invalidSampleNames;
  if (scalar (@unmatchedFromMetadata)) {
    print STDERR "WARNING : the following samples in the metadata file has no match in the data file provided. Please verify the sample name in the metadata file.";
    print STDERR Dumper \@unmatchedFromMetadata;
  }
  if (scalar (@unmatchedFromData)) {
    print STDERR "WARNING : The following samples in the data file has no match in the metadata file provided. Please verify the sample names.";
    print STDERR Dumper \@unmatchedFromData;
  }
  close DATAOUT;
  return ($dataSampleNames);
}

sub swapHeaderValue{
  my ($characteristic, $headerMapHash) =@_;
    if (defined $headerMapHash->{$characteristic}) {
      $characteristic = $headerMapHash->{$characteristic};
    }
  return $characteristic;
}

sub parseHeader {
  my ($dbh,$header,$headerMap) = @_;
  #$dbh->trace($dbh->parse_trace_flags('SQL|1|test'));
  my @requiredCols = ("Organism","StrainOrLine","BioSourceType","Host");
  my @Header = split ("\t" , $header);
        

  	my $colMap = {};
        my $chars = [];
        my $unmatched = [];
        my $sql = "select distinct value from STUDY.ONTOLOGYENTRY where regexp_replace(lower(value),'[^[:alnum:]]+','_') = ?";
        my $sh = $dbh->prepare($sql);
        foreach my $char (@Header) {
          $char =~ s/^\W+//;
          $char =~ s/\s+$//;
          $char =~ s/\W+/_/g;
          $char = lc($char);
          $char = swapHeaderValue($char,$headerMap);

          if ($char =~ /sample_id/i) {
            push (@$chars,$char);
            next;
          }

          $sh->execute($char);

          my $temp = $sh->fetchrow_array(); #or push (@$unmatched,$char);
          if ($temp) {
            $char = $temp;
          }
          else {
            push (@$unmatched,$char);
          }
          push (@$chars,$char);
        }
        if (scalar (@$unmatched)) {
          print STDERR "The following ontology terms have no match in the database.\nPlease verifiy that the characteristics have been loaded into the Study.ontologyEntry\n";
          print STDERR Dumper ( $unmatched );
          die "Please fix the header and rerun this program" unless $force;
        }
	foreach my $col (@requiredCols) {
	  push (@$chars,$col);
	}

	$colMap->{"characteristics"} = $chars;
        $sh->finish();
        $dbh->disconnect();
        return $colMap;
}
