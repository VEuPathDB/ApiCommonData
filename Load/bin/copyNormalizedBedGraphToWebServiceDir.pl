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

    ## datasetXml: dataset xml in order to keep the order of samples e.g. EuPathDatasets/Datasets/lib/xml/datasets/PlasmoDB/pfal3D7/Su_strand_specific.xml. In this case, samples are in the order of lateTroph, schizont, gametocyteII, gametocyteV
endOfUsage

die $usage unless -e $inputDir;
die $usage unless -e $outputDir;

opendir(DIR, $inputDir);
my @ds = readdir(DIR);

my %subOrder = ( 'unique_results_sorted.firststrand.bw'  => 1,
                 'non_unique_results_sorted.firststrand.bw'      => 2, 
                 'unique_results_sorted.secondstrand.bw' => 3, 
                 'non_unique_results_sorted.secondstrand.bw'     => 4,
                 'unique_results_sorted.bw'       => 1,
                 'non_unique_results_sorted.bw'           => 2,
                 'unique_results_sorted.firststrand_unlogged.bw'  => 1,
                 'non_unique_results_sorted.firststrand_unlogged.bw'      => 2, 
                 'unique_results_sorted.secondstrand_unlogged.bw' => 3, 
                 'non_unique_results_sorted.secondstrand_unlogged.bw'     => 4,
                 'unique_results_sorted_unlogged.bw'       => 1,
                 'non_unique_results_unlogged.bw'           => 2
                );

my %altSubOrder = ( 'unique_results_sorted.secondstrand.bw'  => 1,
		    'non_unique_results_sorted.secondstrand.bw'      => 2, 
		    'unique_results_sorted.firststrand.bw' => 3, 
		    'non_unique_results_sorted.firststrand.bw'     => 4,
		    'unique_results_sorted.secondstrand_unlogged.bw'  => 1,
		    'non_unique_results_sorted.secondstrand_unlogged.bw'      => 2, 
		    'unique_results_sorted.firststrand_unlogged.bw' => 3, 
		    'non_unique_results_sorted.firststrand_unlogged.bw'     => 4
                  );

my %sampleOrder;
my %sampleDisplayName;
my %sampleHash;
my %acRepCheck;

if(-e $analysisConfig) {
    %sampleHash = displayAndBaseName($analysisConfig);
#    foreach my $test (keys %sampleHash) {
#	print "$test"."la\n\n\n\n\n";
#    }
    open(F, $analysisConfig);
    my $count = 1;
    
    while(<F>) {
	chomp;
	next if /^\s+$/;
	#if( $_ =~ /<prop name="sampleName">(.*)<\/prop>/) {
	if(  /<property name="samples">/i .. /<\/property>/i  ) {
	    next unless /<value>/i;
	    $_ =~ /<value>(.*)<\/value>/ ;
	    my($sample_display_name, $sample_internal_name) = split /\|/, $1;

	    if (exists $sampleHash{$sample_display_name} ) {

		$sample_internal_name = $sampleHash{$sample_display_name}."_combined";
		if (exists $acRepCheck{$sample_display_name} ) {
		    next;
		}
		else {

		    $sampleOrder{$sample_internal_name} = $count;
		    $sampleDisplayName{$sample_internal_name} = $sample_display_name;
		    $count++;
		    $acRepCheck{$sample_display_name} = 1;
		}
	    }
	    else {
		$sampleOrder{$sample_internal_name} = $count;
		$sampleDisplayName{$sample_internal_name} = $sample_display_name;
		$count++;
	    }
	}
    }
}
    my %reps;
foreach my $exp (keys %sampleDisplayName) {
#    print "$exp\n";
    if ($exp =~ /(.+)_combined/) {
	my $base_name = $1;
#	print $base_name."\n\n\n\n";
	$reps{$base_name}= 1;
    }
    else {
#	"print $exp has no combined data\n\n\n\n";
    }

}



# sort directory name by the number in the string, e.g. hour2, hour10, hour20...
OUTER: foreach my $d (sort @ds) {
#foreach my $d (map  { $_->[0] }
#               sort { $a->[1] <=> $b->[1] }
#               map  { [$_, $_=~/(\d+)/] } @ds) {
    
    next unless $d =~ /^analyze_(\S+)/;
#    print "directory: $d\n";
    my $sample = $1;
    
    foreach my $keys (keys %reps) {
	
	if (($d =~ $keys) && ($d !~ /combined/)) {

	    next OUTER;
	}
	else {
	    next;
	}
    }
    $inputDir =~ s/\/$//;
    my $exp_dir = "$inputDir/$d/master/mainresult/normalized/final";
    my $output = $outputDir."/$sample"; 
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
	    $selected = 1 if $f =~ /^unique/;
	    $selected = 0 if $f =~ /^non_unique/;
	    $selected = 0 if $count > 15;
	    $isStrandSpecific = 1 if $f =~ /firststrand/;
	    $strand = 'reverse' if $f =~ /secondstrand/;
	    $strand = 'forward' if $f =~ /firststrand/;
	    
	    my $order = $subOrder{$f} % 5;
	    
	    my $display_order_sample = "";
	    
	    if(-e $analysisConfig) {
		$display_order_sample = "$sampleOrder{$sample}.$order - ".  $sampleDisplayName{$sample};
	    } else {
		$display_order_sample = $sample; 
	    }
	    
	    
	    if($f =~ /firststrand/ || $f =~ /secondstrand/) {
$meta =<<EOL;
[$sample/$f]
:selected    = $selected
display_name = $display_order_sample ($expt $strand)
sample       = $sample
alignment    = $expt
strand       = $strand
type         = Coverage
		    
EOL
	    } 
	    else {
$meta =<<EOL;
[$sample/$f]
:selected    = $selected
display_name = $display_order_sample ($expt)
sample       = $sample
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
	    $selected = 1 if $f =~ /^unique/;
	    $selected = 0 if $f =~ /^non_unique/;
	    $selected = 0 if $count > 15;
	    $strand = 'reverse' if $f =~ /firststrand/;
	    $strand = 'forward' if $f =~ /secondstrand/;
	    
	    my $order = $altSubOrder{$f} % 5;
	    
	    my $display_order_sample = "";
	    
	    if(-e $analysisConfig) {
		$display_order_sample = "$sampleOrder{$sample}.$order - ".  $sampleDisplayName{$sample};
	    } else {
		$display_order_sample = $sample; 
	    }
	    
$meta =<<EOL;
[$sample/$f]
:selected    = $selected
display_name = $display_order_sample ($expt $strand)
sample       = $sample
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

