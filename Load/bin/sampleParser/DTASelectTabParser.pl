#!/usr/bin/perl

use strict;

use Getopt::Long;

use File::Basename;

use Data::Dumper;

my ($fn, $outfn, $help);



&GetOptions('help|h' => \$help,
            'file=s' => \$fn,
            'outputfile=s' => \$outfn,
           );

&usage() if($help);
&usage("Tab file is required") unless(-e $fn);
&usage("Output file is required") unless(-e $outfn);
my $expName = basename($fn, ".txt");

#--------------------------------------------------------------------------------
my (@results, @myArray, $result, $count,$uniqueSeq ,%uniqueSeq);

open (TABFILE, "$fn") || die "File not found\n";

<TABFILE>;
<TABFILE>;

while (<TABFILE>){

    chomp;

    @myArray = split(/\t/, $_);

    if (scalar @myArray == 9){

	%uniqueSeq = ();

	$count = $myArray[1];

	my $sequenceKey = $myArray[0];

	my $spectrumCount = $myArray[2];
 
	my $percentCoverage = $myArray[3];

	$percentCoverage =~ s/\%//g;

	my $seqMolWt=$myArray[5];

	my $seqPI=$myArray[6];

	$result = {source_id => $sequenceKey,
		   description => $sequenceKey,
		   percentCoverage => $percentCoverage,
		   seqMolWt => $seqMolWt,
		   seqPI => $seqPI,
		   experiment_name => $expName,
		   sourcefile => $expName,
		   spectrumCount =>$spectrumCount,
	       };

    }else{

	$count--; 

	my $sequence=$myArray[11];

	$sequence =~ s/\*//g;

	my @seqArray= split(/\./,$sequence); 

	$sequence=@seqArray[1];

	#$sequence =~ s/\.(\S+?)\./$1/;

        my $observed=$myArray[6];

	my $delta = $myArray[3];

	my $ions_score="XCross: $myArray[2], SpR: $myArray[7]";

	$uniqueSeq{$sequence}++;

	push(@{$result->{peptides}},{observed => $observed,
				     delta => $delta,
				     sequence => $sequence,				     
				     ions_score => $ions_score,
				 }
	     
	     );
	
    }
    if($count==0){

	my $countK=keys %uniqueSeq;

	$result->{sequenceCount} = $countK;

	push(@results, $result);
    }
}

close(TABFILE);

print STDERR "Finished Reading and Writing Tab file\n";

#print Dumper (\@results);
writeTabFile(\@results);

#--------------------------------------------------------------------------------


sub writeTabFile {

  my ($results) = @_;

  open (TABF, "> $outfn") or die "could not APPEND to $outfn\n";

  for my $h (@$results) {

  print TABF 
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

    print TABF
      $h->{source_id},       "\t",
        $h->{description},     "\t",
          $h->{seqMolWt},        "\t",
            $h->{seqPI},           "\t",
              $h->{score},           "\t",
                $h->{percentCoverage}, "\t",
                  $h->{sequenceCount},   "\t",
                    $h->{spectrumCount},   "\t",
                      $h->{sourcefile},      "\n",
                        ;
    
    
    print TABF
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
    
    for my $pep (@{$h->{peptides}}) {
      print TABF
        $pep->{start},         "\t",
          $pep->{end},           "\t",
            $pep->{observed},      "\t",
              $pep->{mr_expect},     "\t",
                $pep->{mr_calc},       "\t",
                  $pep->{delta},         "\t",
                    $pep->{miss},          "\t",
                      $pep->{sequence},      "\t",
                        $pep->{modification},  "\t",
                          $pep->{query},         "\t",
                            $pep->{hit},           "\t",
                              $pep->{ions_score},    "\n",
                                ;
    }
  }
  close TABF;
}

#--------------------------------------------------------------------------------

sub usage {
  my ($m) = @_;

  print STDERR "ERROR:  $m\n" if($m);

  print STDERR "usage: TabParser.pl --file TAB_FILE -- outputfile OUTPUT_FILE\n";

  exit;
}

#--------------------------------------------------------------------------------


1;

