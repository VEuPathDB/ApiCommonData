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

my ($inFile, $dataFile, $outFile, $valueMapFile, $help,);

&GetOptions('help|h' => \$help,
            'inFile=s' => \$inFile,
	    'valueMapFile=s' => \$valueMapFile,
            'dataFile=s' => \$dataFile,
            'outFile=s' => \$outFile,
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
my $subjects = [];
my $sourceNames = [];

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
}

open (OUTFILE, ">$outFile") || die "Can't open $outFile for reading\n";
open (INFILE, $inFile) || die "Can't open $inFile for reading : $!\n";
my $rowCount = 0;
foreach my $row (<INFILE>){

  chomp $row;
  my %hash;

  my $charSet;
    if ($isHeader) {
    $ColumnMap = parseHeader($dbh,$row);
    $isHeader=0;
    $charSet = $ColumnMap->{"characteristics"};
	print OUTFILE 'Source Name'."\t";
	my $first = 1;
    foreach my $char (@$charSet) {
	  my $token = $char;
	  if ($char =~ /subject/) {
		$token = "Comment [subject]";
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
  my $origin = " ";
  my $subject = " ";
  foreach my $val ( @$values ) {
    my $charSet = $ColumnMap->{"characteristics"};
	$colCount = scalar @$charSet;
	my $currentChar = $charSet->[$counter];
	$origin = $val if $currentChar =~ /^sample_origin$/;
	$subject = $val if $currentChar =~ /^subject$/;
    my $holder = $val;
	$holder = ' ' unless $holder;
    $holder = $mapHash->{$charSet->[$counter]}->{ $val } if ($mapHash->{$charSet->[$counter]}->{ $val });
    $counter++;
    push ( @$finalValues,  $holder ) if $holder;

  }
  $sourceName = $origin."_".$subject;
  $sourceName =~ s/ /_/;
  push (@$subjects, $subject);
  push (@$sourceNames, $sourceName);
  unshift ( @$finalValues, $sourceName );

  my $line = join ("\t",@$finalValues);
   while ($counter < $colCount) {
	  $line = $line ."\t";
	  $counter++;
	}
  $line =~ s/ \t/\t/g;
  print OUTFILE $line."\n";
}
close OUTFILE;
close INFILE;
validateSampleNames ($dataFile, $subjects, $sourceNames);

sub validateSampleNames {
  my ($dataFile , $subjects, $sourceNames) = @_;
  my $isHeader = 1;
  my $dataSampleNames;
  my $dataOut = [];
  
  
  open (DATAIN, "<$dataFile") || die "Can't open $dataFile for reading\n";
  while (<DATAIN>) {
    my $line = $_;
    chomp $line;
    if ($isHeader) {
      $dataSampleNames = [split ("\t" , $line)];
      $isHeader = 0;
      next;
    }
    else {
      push (@$dataOut, $line);
    }
  }
  my $count = 0;
  foreach my $sample (@$dataSampleNames) {
    if (grep { /^$sample/ } @$sourceNames) {
      $count++;
      next;
    }
    elsif (grep { /^$sample/ } @$subjects) {
      $dataSampleNames->[$count] = $sourceNames->[$count];
      $count++;
    }
  }
  close DATAIN;
  open (DATAOUT, ">$dataFile") || die "Can't open $dataFile for writing\n";
  my $output = join ("\t",@$dataSampleNames);
  print DATAOUT $output."\n";
  $output = join ("\n",@$dataOut);
  print DATAOUT $output."\n";
  my @unmatchedFromMetadata = grep { !($_ ~~ @$dataSampleNames ) } @$sourceNames;
  my @unmatchedFromData = grep { !($_ ~~ @$sourceNames ) } @$dataSampleNames;
  if (scalar (@unmatchedFromMetadata)) {
    print STDERR "WARNING : the following samples in the metadata file has no match in the data file provided. Please verify the sample name in the metadata file.";
    print STDERR Dumper (\@unmatchedFromMetadata);
  }
  if (scalar (@unmatchedFromData)) {
    print STDERR "WARNING : The following samples in the data file has no match in the metadata file provided. Please verify the sample names.";
    print STDERR Dumper (\@unmatchedFromData);
  }
  close DATAOUT;
}

 

sub parseHeader {

	my ($dbh,$header) = @_;
	my @requiredCols = ("Organism","StrainOrLine","BioSourceType","Host");
	my @Header = split ("\t" , $header);


  	my $colMap = {};
        my $chars = [];
        my $unmatched = [];
        foreach my $char (@Header) {
          $char =~ s/^\s+//;
          $char =~ s/\s+$//;
          $char =~ s/\s+/_/g;
          $char = lc($char);
          $char =~ s/^study_subject_unique_id$/subject/;
          $char =~ s/^gender$/sex/;
          $char =~ s/^location$/geographiclocation/;


          if ($char =~ /^subject$/) {
            push (@$chars,$char);
            next;
          }
          my $sql = "select distinct value from STUDY.ONTOLOGYENTRY where replace(lower(value),' ','_') = '$char'";
          my $sh = $dbh->prepare($sql);
          $sh->execute();

          my $temp = $sh->fetchrow_array(); #or push (@$unmatched,$char);
          $sh->finish();

          if ($temp) {
            $char = $temp;
          }
          else {
            push (@$unmatched,$char);
            next;
          }
          push (@$chars,$char);
        }
        if (scalar (@$unmatched)) {
          print STDERR "The following ontology terms have no match in the database.\nPlease verifiy that the characteristics have been loaded into the Study.ontologyEntry\n";
          print STDERR Dumper ( $unmatched );
          die "Please fix the header and rerun this program";
        }
	foreach my $col (@requiredCols) {
	  push (@$chars,$col);
	}

	$colMap->{"characteristics"} = $chars;
        $dbh->disconnect();
        return $colMap;
}
