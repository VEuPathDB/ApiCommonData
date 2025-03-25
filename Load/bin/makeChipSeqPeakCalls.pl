#!/usr/bin/perl

# DEPENDENCIES:
# Homer: homer/bin directory added to executable path (see http://homer.salk.edu/homer/introduction/install.html). 

use strict;
use Getopt::Long;
use lib "$ENV{GUS_HOME}/lib/perl";
use CBIL::Util::PropertySet;

my ($workflowDir, $experimentType, $experimentName, $experimentDataDir);
&GetOptions("workflowDir=s" => \$workflowDir,
            "experimentType=s" => \$experimentType,
	    "experimentName=s" => \$experimentName,
	    "experimentDataDir=s" => \$experimentDataDir
    ); 

die "USAGE: $0 --workflowDir < workflow_dir> --experimentType <experimentType> --experimentName <experimentName> --experimentDataDir <experiment_data_dir>\n"
    if (!$workflowDir || !$experimentType || !$experimentName || !$experimentDataDir);

# Currently peak calls are only made for histone modification data with input/control.
# If in the future this will be extended to peak calls for TF binding, the value passed to the -style argument of the homerCmd (stored in $style) needs to be set appropriately. Moreover the name of the output file from HOMER is different, so $homerOutput has to be defined accordingly (see documnetation at http://homer.salk.edu/homer/ngs/peaks.html).

my $style;
my $homerOutput;

if ($experimentType eq 'histonemod') {
    $style ='histone';
    $homerOutput = 'regions.txt';
    
    my $mkDirCmd = "mkdir $workflowDir/$experimentDataDir/peaks";;
    print STDERR "\n$mkDirCmd\n\n";
    system($mkDirCmd) == 0 or die "system $mkDirCmd failed: $?";
    
    my $configFile =  "$workflowDir/$experimentDataDir/peaks/peaksConfig.txt";
    open (WFH1, ">$configFile") || die "Cannot open $configFile for writing\n";
    
    my @columns = ('Name', 'File Name', 'Source Id Type', 'Input ProtocolAppNodes', 'Protocol', 'ProtocolParams', 'ProfileSet');
    print WFH1 join("\t", @columns) . "\n";
    
    foreach my $file (glob "$workflowDir/$experimentDataDir/analyze_*/samplePropFile.txt") {
	my @properties = (["sampleName"],
			  ["inputName"],
			  ["fragLength"]);
	my $prop = CBIL::Util::PropertySet->new($file, \@properties, 1);
	
	my $sampleName = $prop->{props}->{sampleName};
	my $inputName = $prop->{props}->{inputName};
	my $fragLength = $prop->{props}->{fragLength};
	
	if ($inputName && $sampleName ne $inputName) {
	    print STDERR "\nWorking on $sampleName\n\n";
	    
	    my $homerCmd = "findPeaks $workflowDir/$experimentDataDir/analyze_$sampleName/master/downstream/ -style $style -o auto -i $workflowDir/$experimentDataDir/analyze_$inputName/master/downstream/";
	    if ($fragLength) {
		$homerCmd .=  " -fragLength $fragLength";
	    }
	    print STDERR $homerCmd . "\n";
	    system($homerCmd) == 0 or die "system $homerCmd failed: $?";

            my $peaksFileBasename = "peaks_$sampleName.txt";
	    my $peaksFile =  "$workflowDir/$experimentDataDir/peaks/$peaksFileBasename";


	    open (WFH2, ">$peaksFile") || die "Cannot open $peaksFile for writing\n";
	    print WFH2 "sequence_source_id\tsegment_start\tsegment_end\tscore1\tscore2\tp_value\n";
	    open (RFH, "<$workflowDir/$experimentDataDir/analyze_$sampleName/master/downstream/$homerOutput") || die "Cannot open $workflowDir/$experimentDataDir/analyze_$sampleName/master/downstream/$homerOutput for reading.\n";
	    while (my $line=<RFH>) {
		if ($line=~/^#/) {
		    next;
		}
		chomp($line);
		my @arr = split(/\t/, $line);
		# Storing Normalized Tag Count in score1 and Fold Change vs Control in score 2.
		print WFH2 "$arr[1]\t$arr[2]\t$arr[3]\t$arr[5]\t$arr[10]\t$arr[11]\n";
	    }
	    close(WFH2);
	    close(RFH);
	    
	    print WFH1 $sampleName. "_peaks (ChIP-Seq)\t$peaksFileBasename\tsegment\t\tHOMER peak calls\tstyle|histone;fdr|0.001\t$experimentName\n";
	}
    }
    close(WFH1);
}
