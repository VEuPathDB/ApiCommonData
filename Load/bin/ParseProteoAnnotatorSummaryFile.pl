#!/usr/bin/perl

use strict;

use Getopt::Long;

use File::Basename;

use Data::Dumper;

my ($fn, $outputFile, $decoyTag, $help);



&GetOptions('help|h' => \$help,
            'inputFile=s' => \$fn,
			'outputFile=s' => \$outputFile
            'decoyTag=s' => \$decoyTag,
           );
		   
&usage() if($help);
&usage("inputFile is required") unless(-e $fn);
&usage("decoyTag must be provided") unless $decoyTag;
my ($sampleName,$path,$suffix) = fileparse($outputFile, ".txt"); 

#--------------------------------------------------------------------------------
my (@results, @myArray, $result);

open (INPUT, "$fn") || die "File not found\n";

my $currentAccession;
my $junk;
my $rows ={};
while (<INPUT>){
	chomp;
	my @myArray = split(/\t/,$_);
	($myArray[0], $junk) = split(/ /,$myArray[0]);
	if ($myArray[0]) {
		$currentAccession = $myArray[0]; 
	}
	else {
		$myArray[0] = $currentAccession;
	}
	my $accession = $myArray[0];
	my $row = join("\t", @myArray);
	my $sequence = $myArray[3];
	unless($accession=~m/^$decoyTag.*/) {
			push(@{ $rows->{$accession}->{'resultLine'} }, $row);
			push(@{ $rows->{$accession}->{'uniqueSequence'} }, $sequence) unless grep(/^$sequence$/, @{ $rows->{$accession}->{'uniqueSequence'} });

	}
}
 $outputFile=~s/\/+/\//g;
open (OUTPUT, ">$outputFile") || die "could not APPEND to $outputFile\n";
foreach my $key (keys %$rows) {
	my $source_id = $key;
	my $description = '';
	my $seqMolWt = '';
	my $seqPI = '';
	my $score = '';
	my $percentCoverage = '';
	my $sequenceCount = scalar(@{ $rows->{$key}->{'uniqueSequence'} });
	my $spectrumCount = scalar(@{ $rows->{$key}->{'resultLine'} });
	my $sourcefile = $sampleName;
	
	print OUTPUT 
      '# source_id',      "\t",
        'description',      "\t",
          'seqMolWt',         "\t",
            'seqPI',            "\t",
              'score',            "\t",
                'percentCoverage',  "\t",
                  'sequenceCount',    "\t",
                    'spectrumCount',    "\t",
                      'sourcefile',       "\n",
                        ;

	print OUTPUT 
	  $source_id,       "\t",
        $description,     "\t",
          $seqMolWt,        "\t",
            $seqPI,           "\t",
              $score,           "\t",
                $percentCoverage, "\t",
                  $sequenceCount,   "\t",
                    $spectrumCount,   "\t",
                      $sourcefile,      "\n",
                        ;
	
	print OUTPUT
      '## start',      "\t",
        'end',           "\t",
          'observed',      "\t",
            'mr_expect',     "\t",
              'mr_calc',       "\t",
                'delta',         "\t",
                  'miss',          "\t",
                    'sequence',      "\t",
                      'modification',  "\t",
                        'query',         "\t",
                          'hit',           "\t",
                            'ions_score',    "\n",
                              ;
							  
	foreach my $peptide ( @{ $rows->{$key}->{'resultLine'} }) {
		chomp;
		my @fields = split(/\t/, $peptide);
		my $start = $fields[7];
		my $end = $fields[8];
		my $observed = '';
		my $mr_expect = '';
		my $mr_calc = '';
		my $delta = '';
		my $miss = '';
		my $sequence = $fields[3];
		my $modification = $fields[10];
		my $query = '';
		my $hit = '';
		my $ions_score = "protein_score: $fields[1], simple_FDR: $fields[9], estimated_FDR_for_peptide: $fields[4]";
		
	    print OUTPUT
        $start,         "\t",
          $end,           "\t",
            $observed,      "\t",
              $mr_expect,     "\t",
                $mr_calc,       "\t",
                  $delta,         "\t",
                    $miss,          "\t",
                      $sequence,      "\t",
                        $modification,  "\t",
                          $query,         "\t",
                            $hit,           "\t",
                              $ions_score,    "\n",
                                ;
    }
}
close OUTPUT;

#--------------------------------------------------------------------------------

sub usage {
  my ($m) = @_;

  print STDERR "ERROR:  $m\n" if($m);

  print STDERR "usage: SummaryFileParser.pl --inputFile TAB_FILE --decoyTag DECOY_TAG --outputFile OUTPUT_FILE\n";

  exit;
}

1;