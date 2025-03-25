#!/usr/bin/perl

use strict;
use Getopt::Long;
use lib "$ENV{GUS_HOME}/lib/perl";
use CBIL::Util::Utils;


# this script loops through each sample output directory and copies (normalized) bedgraph files to webService Dir. 

my ($inputDir, $outputDir, $experimentType); 

&GetOptions("inputDir=s"       => \$inputDir,
            "outputDir=s"      => \$outputDir,
	    "experimentType=s" => \$experimentType
           );

my $usage =<<endOfUsage;
Usage:
  copyChipSeqBedGraphToWebServiceDir.pl --inputDir input_directory --outputDir output_directory --experimentType experiment_type

    intpuDir:top level directory, e.g. /eupath/data/EuPathDB/workflows/PlasmoDB/CURRENT/data/pfal3D7/organismSpecificTopLevel/Su_strand_specific

    outputDir: webservice directory, e.g. /eupath/data/apiSiteFilesStaging/PlasmoDB/18/real/webServices/PlasmoDB/release-CURRENT/Pfalciparum3D7/bigwig/pfal3D7_Su_strand_specific_rnaSeq_RSRC

    # Currently coverage plots are being generated only for histonemode and mnase
   experimentType: the type of ChipSeq experiment, one of: histonemod, mnase, tfbinding, faire

    ## datasetXml: dataset xml in order to keep the order of samples e.g. ApiCommonDatasets/Datasets/lib/xml/datasets/PlasmoDB/pfal3D7/Su_strand_specific.xml. In this case, samples are in the order of lateTroph, schizont, gametocyteII, gametocyteV
endOfUsage

die $usage unless -e $inputDir;
die $usage unless -e $outputDir;

opendir(DIR, $inputDir);
my @ds = readdir(DIR);

# sort directory name by the number in the string, e.g. hour2, hour10, hour20...
foreach my $d (sort @ds) {
    next unless $d =~ /^analyze_(\S+)/;
    my $sample = $1;
    $inputDir =~ s/\/$//;
    my $exp_dir = "$inputDir/$d/master/downstream/";
    
    my $output = $outputDir."/$sample"; 
    system ("mkdir $output");
    my $status = $? >>8;
    die "Error.  Failed making $outputDir with status '$status': $!\n\n" if ($status);
    my $cmd = "cp $exp_dir/results.bw $output";
    system ($cmd); 
    $status = $? >>8;
    die "Error.  Failed $cmd with status '$status': $!\n\n" if ($status);
    
    # create a metadata text file for better organizing gbrowse subtracks
    open(METAUNLOGGED, ">>$outputDir/metadata_unlogged");
    my $meta = "";
    my $expt = "";
    $expt = 'unique' if $experimentType eq 'histonemod';
    
    $meta =<<EOL;
[$sample/results.bw]
:selected    = 1
display_name = $sample ($expt)
sample       = $sample
alignment    = $expt
type         = Coverage
	
EOL
	
    print METAUNLOGGED $meta;
    close(METAUNLOGGED);
}
