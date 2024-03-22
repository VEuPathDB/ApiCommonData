#!/usr/bin/env perl

use strict;
use warnings;
use Getopt::Long;


my ($inputPepFasta, $peptideTab, $peptideProtein, $workDir);
&GetOptions("inputPepFasta=s"=> \$inputPepFasta,
            "peptideTab=s"=> \$peptideTab,
            "peptideProtein=s"=> \$peptideProtein,
	    "workDir=s"=> \$workDir,
    ) ;

unless (-e $inputPepFasta && $peptideTab && $peptideProtein && $workDir) {
    &usage("Both input files must exist;  output file must be declared")
}

sub usage {
    my ($e) = @_;

    print STDERR "runNextflow.pl --inputPepFasta <FILE> --peptideTab OUT --peptideProtein OUT --workDir WorkDirectory\n";
    die $e if($e);
}


my $nfConfigFile='iedbNextflow.config';
  unless (-e $nfConfigFile){

 my $nfConfig = <<CONFIG;
params {
    pepFasta = "$inputPepFasta";
    pepTab = "$peptideTab";
    peptideProteinFasta = "$peptideProtein";
    results = "$workDir"
 }
 process {
  executor = local
  
 }
docker {
  enabled = true
}
CONFIG
open(FH, ">$nfConfigFile") or die "Cannot write config file $nfConfigFile: $!\n";
print FH  $nfConfig;
close(FH);

}

my $executable = join("/", $ENV{'GUS_HOME'}, 'bin', 'processIedb');

my $logFile = join("/", $workDir, "nextflow.log");

my $cmd = "export NXF_WORK=$workDir/work && nextflow -bg -C $nfConfigFile -log $logFile run $executable";      
