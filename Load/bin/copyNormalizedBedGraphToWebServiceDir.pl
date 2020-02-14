#!/usr/bin/perl
#vvvvvvvvvvvvvvvvvvvvvvvvv GUS4_STATUS vvvvvvvvvvvvvvvvvvvvvvvvv
  # GUS4_STATUS | SRes.OntologyTerm              | auto   | absent
  # GUS4_STATUS | SRes.SequenceOntology          | auto   | absent
  # GUS4_STATUS | Study.OntologyEntry            | auto   | absent
  # GUS4_STATUS | SRes.GOTerm                    | auto   | absent
  # GUS4_STATUS | Dots.RNAFeatureExon            | auto   | absent
  # GUS4_STATUS | RAD.SageTag                    | auto   | absent
  # GUS4_STATUS | RAD.Analysis                   | auto   | absent
  # GUS4_STATUS | ApiDB.Profile                  | auto   | absent
  # GUS4_STATUS | Study.Study                    | auto   | absent
  # GUS4_STATUS | Dots.Isolate                   | auto   | absent
  # GUS4_STATUS | DeprecatedTables               | auto   | absent
  # GUS4_STATUS | Pathway                        | auto   | absent
  # GUS4_STATUS | DoTS.SequenceVariation         | auto   | absent
  # GUS4_STATUS | RNASeq Junctions               | auto   | absent
  # GUS4_STATUS | Simple Rename                  | auto   | absent
  # GUS4_STATUS | ApiDB Tuning Gene              | auto   | absent
  # GUS4_STATUS | Rethink                        | auto   | absent
  # GUS4_STATUS | dots.gene                      | manual | reviewed
#^^^^^^^^^^^^^^^^^^^^^^^^^ End GUS4_STATUS ^^^^^^^^^^^^^^^^^^^^

use strict;
use Getopt::Long;
use lib "$ENV{GUS_HOME}/lib/perl";
use CBIL::Util::Utils;
use ApiCommonData::Load::AnalysisConfigRepeatFinder qw(displayAndBaseName);

use Data::Dumper;

# this script loops through each sample output directory and copy normalized bedgraph files to webService Dir. 

#  ... Su_strand_specific/analyze_lateTroph/master/mainresult/normalized
#  ... Su_strand_specific/analyze_schizont/master/mainresult/normalized
#  ... Su_strand_specific/analyze_gametocyteII/master/mainresult/normalized
#  ... Su_strand_specific/analyze_gametocyteV/master/mainresult/normalized

my ($inputDir, $outputDir, $analysisConfig); 

&GetOptions("inputDir=s"       => \$inputDir,
            "outputDir=s"      => \$outputDir,
            "analysisConfig=s" => \$analysisConfig
           );

my $usage =<<endOfUsage;
Usage:

  copyNormalizedBedGraphToWebServiceDir.pl --inputDir input_directory --outputDir output_directory --analysisConfig analysisConfig.xml

    intpuDir:top level directory, e.g. /eupath/data/EuPathDB/workflows/PlasmoDB/CURRENT/data/pfal3D7/organismSpecificTopLevel/Su_strand_specific

    outputDir: webservice directory, e.g. /eupath/data/apiSiteFilesStaging/PlasmoDB/18/real/webServices/PlasmoDB/release-CURRENT/Pfalciparum3D7/bigwig/pfal3D7_Su_strand_specific_rnaSeq_RSRC

    analysisConfig: use to track sample order and display name. Here is a sample analysis config file - 
        /eupath/data/EuPathDB/manualDelivery/PlasmoDB/pfal3D7/rnaSeq/Su_strand_specific/2011-11-16/final/analysisConfig.xml

    ## datasetXml: dataset xml in order to keep the order of samples e.g. ApiCommonDatasets/Datasets/lib/xml/datasets/PlasmoDB/pfal3D7/Su_strand_specific.xml. In this case, samples are in the order of lateTroph, schizont, gametocyteII, gametocyteV
endOfUsage

die $usage unless -e $inputDir;
die $usage unless -e $outputDir;

#opendir(DIR, $inputDir);
#my @ds = readdir(DIR);

my %subOrder = ( 'unique_results.firststrand.bw'  => 1,
                 'non_unique_results.firststrand.bw'      => 2, 
                 'unique_results.secondstrand.bw' => 3, 
                 'non_unique_results.secondstrand.bw'     => 4,
                 'unique_results_sorted.bw'       => 1,
                 'non_unique_results_sorted.bw'           => 2,
                 'unique_results_sortedCombinedReps.bw' => 1,
                 'non_unique_results_sortedCombinedReps.bw' => 2,
                 'unique_results.firststrandCombinedReps.bw' => 1,
                 'non_unique_results.firststrandCombinedReps.bw' => 2,
                 'unique_results.secondstrandCombinedReps.bw' => 3,
                 'non_unique_results.secondstrandCombinedReps.bw' => 4,
      		 'unique_results.firststrand_unlogged.bw'  => 1,
                 'non_unique_results.firststrand_unlogged.bw'      => 2, 
                 'unique_results.secondstrand_unlogged.bw' => 3, 
                 'non_unique_results.secondstrand_unlogged.bw'     => 4,
                 'unique_results_sorted_unlogged.bw'       => 1,
                 'non_unique_results_unlogged.bw'           => 2,
                 'uniqueCombinedReps_unlogged.bw' => 1,
                 'non_uniqueCombinedReps_unlogged.bw' => 2,
                 'unique_results.firststrandCombinedReps_unlogged.bw' => 1,
                 'non_unique_results.firststrandCombinedReps_unlogged.bw' => 2,
                 'unique_results.secondstrandCombinedReps_unlogged.bw' => 3,
                 'non_unique_results.secondstrandCombinedReps_unlogged.bw' => 4
                );

my %altSubOrder = ( 'unique_results.secondstrand.bw'  => 1,
		    'non_unique_results.secondstrand.bw'      => 2, 
		    'unique_results.firststrand.bw' => 3, 
		    'non_unique_results.firststrand.bw'     => 4,
		    'unique_results.secondstrandCombinedReps_unlogged.bw' => 1,
                 'non_unique_results.secondstrandCombinedReps_unlogged.bw' => 2,
                 'unique_results.firststrandCombinedReps_unlogged.bw' => 3,
                 'non_unique_results.firststrandCombinedReps_unlogged.bw' => 4,
		    'unique_results.secondstrand_unlogged.bw'  => 1,
		    'non_unique_results.secondstrand_unlogged.bw'      => 2, 
		    'unique_results.firststrand_unlogged.bw' => 3, 
		    'non_unique_results.firststrand_unlogged.bw'     => 4,
                 'unique_results.secondstrandCombinedReps_unlogged.bw' => 1,
                 'non_unique_results.secondstrandCombinedReps_unlogged.bw' => 2,
                 'unique_results.firststrandCombinedReps_unlogged.bw' => 3,
                 'non_unique_results.firststrandCombinedReps_unlogged.bw' => 4
                  );

my $sampleHash;

if(-e $analysisConfig) {
    $sampleHash = displayAndBaseName($analysisConfig);
}



foreach my $key (keys %$sampleHash) {
  my $samples = $sampleHash->{$key}->{samples};
  my $dbid = $key;
  $dbid =~ s/[\.-]//g;
  my $sampleDirName;
  if(scalar @$samples > 1) {
    $sampleDirName = $key . "_combined";
  }
  elsif(scalar @$samples == 1) {
    $sampleDirName = $samples->[0];
  }
  else {
    die "no samples found for key $key";
  }


  my $d = -e "$inputDir/analyze_$sampleDirName/master/mainresult" ? "$inputDir/analyze_$sampleDirName/master/mainresult" : "$inputDir/analyze_$sampleDirName/";

    $inputDir =~ s/\/$//;
    my $exp_dir = "$d/normalized/final";
    my $output = $outputDir."/$key"; 
    system ("mkdir $output");
    my $status = $? >>8;
    die "Error.  Failed making $outputDir with status '$status': $!\n\n" if ($status);
    my $cmd = "cp $exp_dir/unique*.bw $output";
    system ($cmd); 
    $status = $? >>8;
    die "Error.  Failed $cmd with status '$status': $!\n\n" if ($status);
    my $cmd = "cp $exp_dir/non_unique*.bw $output";
    system ($cmd);
    $status = $? >>8;
    die "Error.  Failed $cmd with status '$status': $!\n\n" if ($status);


    # create a metadata text file for better organizing gbrowse subtracks
    open(META, ">>$outputDir/metadata");
    open(METAUNLOGGED, ">>$outputDir/metadata_unlogged");
    my $meta = "";
    my $expt = "unique";
    my $exptInternal = $expt;
    my $strand = "forward";
    my $selected = 1;
    my $count = 0;
    my $isStrandSpecific = 0;
    
    opendir(D, $exp_dir);
    my @fs = readdir(D);
    # sort files in the order of RUM_Unique_plus.bw RUM_nu_plus.bw RUM_Unique_minus.bw RUM_nu_minus.bw
    # redmine refs #15678
    foreach my $f(sort { $subOrder{$a} <=> $subOrder{$b} } @fs) {
	next if $f !~ /\.bw$/;
	if (($f =~ /^unique/) || ($f =~ /^non_unique/)) {
	    $count++;
	    $expt = 'non-unique' if $f =~ /^non_unique/;
	    $expt = 'unique' if $f =~ /^unique/;
	    $exptInternal = $expt;
	    $exptInternal =~ s/[\.-]//g;
	    $selected = 1 if $f =~ /^unique/;
	    $selected = 0 if $f =~ /^non_unique/;
	    $selected = 0 if $count > 15;
	    $isStrandSpecific = 1 if $f =~ /firststrand/;
	    $strand = 'reverse' if $f =~ /secondstrand/;
	    $strand = 'forward' if $f =~ /firststrand/;
	    
	    my $order = $subOrder{$f} % 5;
	    
	    my $display_order_sample = "";
	    
	    if(-e $analysisConfig) {
		$display_order_sample = $sampleHash->{$key}->{orderNum} .  ".$order - ".  $sampleHash->{$key}->{displayName};
	    } else {
		$display_order_sample = $key; 
	    }
	    
	    
	    if($f =~ /firststrand/ || $f =~ /secondstrand/) {
$meta =<<EOL;
[$key/$f]
:selected    = $selected
:dbid	     = ${dbid}_${exptInternal}_${strand}
display_name = $display_order_sample ($expt $strand)
sample       = $key
alignment    = $expt
strand       = $strand
type         = Coverage
		    
EOL
	    } 
	    else {
$meta =<<EOL;
[$key/$f]
:selected    = $selected
:dbid        = ${dbid}_${exptInternal}
display_name = $display_order_sample ($expt)
sample       = $key
alignment    = $expt
type         = Coverage
		    
EOL
	    }
	    
	    if($f !~ /unlogged/) {
		print META $meta;
	    }
	    else {
		print METAUNLOGGED $meta;
	    }
	}
	else {
	    next;
	}
   } # end foreach loop
    
    closedir(D);
    close(META);
    close(METAUNLOGGED);
    
    
    next unless $isStrandSpecific;
    # For strand specific data, create alternate tracks in case first and second strands need to be swapped
    open(ALTMETA, ">>$outputDir/metadata_alt");
    open(ALTMETAUNLOGGED, ">>$outputDir/metadata_unlogged_alt");
    my $meta = "";
    my $expt = "unique";
    my $exptInternal = $expt;
    my $strand = "forward";
    my $selected = 1;
    my $count = 0;
    
    opendir(D, $exp_dir);
    my @fs = readdir(D);
    
    foreach my $f(sort { $altSubOrder{$a} <=> $altSubOrder{$b} } @fs) {
	next if $f !~ /\.bw$/ || $f =~ /unstranded/;
	if ($f =~ /^unique/ || $f =~ /^non_unique/) {
	    $count++;
	    $expt = 'non-unique' if $f =~ /^non_unique/;
	    $expt = 'unique' if $f =~ /^unique/;
	    $exptInternal = $expt;
	    $exptInternal =~ s/[\.-]//g;
	    $selected = 1 if $f =~ /^unique/;
	    $selected = 0 if $f =~ /^non_unique/;
	    $selected = 0 if $count > 15;
	    $strand = 'reverse' if $f =~ /firststrand/;
	    $strand = 'forward' if $f =~ /secondstrand/;
	    
	    my $order = $altSubOrder{$f} % 5;
	    
	    my $display_order_sample = "";
	    
	    if(-e $analysisConfig) {
		$display_order_sample = $sampleHash->{$key}->{orderNum} .  ".$order - ".  $sampleHash->{$key}->{displayName};
	    } else {
		$display_order_sample = $key; 
	    }
	    
$meta =<<EOL;
[$key/$f]
:selected    = $selected
:dbid        = ${dbid}_${exptInternal}_${strand}
display_name = $display_order_sample ($expt $strand)
sample       = $key
alignment    = $expt
strand       = $strand
type         = Coverage
		
EOL
		
		if($f !~ /unlogged/) {
		    print ALTMETA $meta;
	    } 
	    else {
		print ALTMETAUNLOGGED $meta;
	    }
	}
	else {
	    next;
	}
   } # end foreach loop
    
    closedir(D);
    close(ALTMETA);
    close(ALTMETAUNLOGGED);
}

