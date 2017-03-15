#!/usr/bin/perl

use strict;


use Getopt::Long;

use Data::Dumper;

use lib "$ENV{GUS_HOME}/lib/perl";


my ($inFile, $outDir, $help,);

&GetOptions('help|h' => \$help,
                      'input_file=s' => \$inFile,
                      'output_directory=s' => \$outDir,
           );

die "input_file is required" unless $inFile;
die "input_file $inFile does not exist" unless -e $inFile;

$outDir = "./" unless $outDir;

mkdir $outDir unless -d $outDir;

open (INFILE, $inFile);
my $isHeader = 1;
my $col = 0; 
my $splitFiles = {};
my $genCols = [];
my $type_col;
  
foreach my $line (<INFILE>) {
	$line =~s/[\n|\r]+//g;
	my @fields = split("\t",$line);
	if ($isHeader) {
		foreach my $field (@fields) {
			if ($field =~m/barcode/) {
				my $sampleType = $field;
				$sampleType =~ s/\_barcode//;
				$splitFiles->{$sampleType}->{col} = $col;
				$splitFiles->{$sampleType}->{output_file_name} = $sampleType."_Sample.txt";
			} else {
				push (@$genCols, $col);
			}
		$col++;
		}
	$isHeader = undef;
	}

	my $generic_text = join("\t",@fields[@$genCols]);
	foreach my $sampleType (keys %$splitFiles) {
		unless ( exists $splitFiles->{$sampleType}->{output_text} ) {

			push (@{$splitFiles->{$sampleType}->{output_text}} , $generic_text."\trandomnumber\tsample_type");
			
		} else {
			push (@{$splitFiles->{$sampleType}->{output_text}} , $generic_text."\t".@fields[$splitFiles->{$sampleType}->{col}]."\t".$sampleType)
				if @fields[$splitFiles->{$sampleType}->{col}] =~ /\w/ ;
		}
	}
  }


foreach my $sampleType (keys %$splitFiles) {
  my $sampleFile = $outDir."/".$splitFiles->{$sampleType}->{output_file_name};
  $sampleFile =~s/\/+/\//;
  open (SAMPLE_FILE, ">$sampleFile");
  my $output = join("\n",@{$splitFiles->{$sampleType}->{output_text}});
  print SAMPLE_FILE $output;
  close SAMPLE_FILE;
}

