#!/usr/bin/perl

# DEPENDENCIES:
# Homer: homer/bin directory added to executable path (see http://homer.salk.edu/homer/introduction/install.html). 

use strict;
use Getopt::Long;
use CBIL::Util::PropertySet;

my ($experimentType, $experimentDataDir);
&GetOptions("experimentType=s" => \$experimentType,
	    "experimentDataDir=s" => \$experimentDataDir,
    ); 

die "USAGE: $0 --experimentType <experimentType> --experimentDataDir <experiment_data_dir>\n"
    if (!$experimentType || !$experimentDataDir);

# Currently peak calls are only made for histone modification data with input/control.
if ($experimentType eq 'histonemod') {

    my $mkDirCmd = "mkdir $experimentDataDir/peaks";
    print STDERR "\n$mkDirCmd\n\n";
    system($mkDirCmd) == 0 or die "system $mkDirCmd failed: $?";

    foreach my $file (glob "$experimentDataDir/analyze_*/samplePropFile.txt") {
	my @properties = (["sampleName"],
			  ["inputName"],
			  ["fragLength"]);
	my $prop = CBIL::Util::PropertySet->new($file, \@properties, 1);

	my $sampleName = $prop->{props}->{sampleName};
	my $inputName = $prop->{props}->{inputName};
	my $fragLength = $prop->{props}->{fragLength};

	if ($inputName && $sampleName ne $inputName) {
	    print STDERR "\nWorking on $sampleName\n\n";
	    my $homerCmd = "findPeaks $experimentDataDir/analyze_$sampleName/master/mainresult/downstream/ -style histone -o auto -i $experimentDataDir/analyze_$inputName/master/mainresult/downstream/";
	    if ($fragLength) {
		$homerCmd .=  " -fragLength $fragLength";
	    }
	    print STDERR $homerCmd . "\n";
	    system($homerCmd) == 0 or die "system $homerCmd failed: $?";
	    
	    my $peakFile =  "$experimentDataDir/peaks/peaks_$sampleName.txt";
	    open (WFH, ">$peakFile") || die "Cannot open $peakFile for writing\n";
	    print WFH "sequence_source_id\tsegment_start\tsegment_end\tscore1\tscore2\tp_value\n";
	    open (RFH, "<$experimentDataDir/analyze_$sampleName/master/mainresult/downstream/regions.txt") || die "Cannot open $experimentDataDir/analyze_$sampleName/master/mainresult/downstream/regions.txt for reading.\n";
	    while (my $line=<RFH>) {
		if ($line=~/^#/) {
		    next;
		}
		chomp($line);
		my @arr = split(/\t/, $line);
		# Storing Normalized Tag Count in score1 and Fold Change vs Control in score 2.
		print WFH "$arr[1]\t$arr[2]\t$arr[3]\t$arr[5]\t$arr[10]\t$arr[11]\n";
	    }
	    close(WFH);
	    close(RFH);
	}
    }
}
