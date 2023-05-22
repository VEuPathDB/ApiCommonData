package ApiCommonData::Load::DEGseqAnalysis;
use base qw(CBIL::StudyAssayResults::DataMunger::Loadable);
use CBIL::Util::Utils;
use strict;
#uses DEGseq.r script 
use Data::Dumper;
sub getSampleName {$_[0]->{sampleName}}
sub getSamplesHash {$_[0]->{samplesHash}}
sub getSuffix {$_[0]->{suffix}}
sub getMainDirectory {$_[0]->{mainDirectory}}
sub getReference {$_[0]->{reference}}
sub getComparator {$_[0]->{comparator}}
#sub getRefCheck {$_[0]->{referenceCheck}}
#sub getCompCheck {$_[0]->{comparatorCheck}}

sub new {
    my ($class, $args) = @_;
    
    my $requiredParams = [
	'sampleName',
	'samplesHash',
	'mainDirectory'
	];
    my $self = $class->SUPER::new($args, $requiredParams);
    
    
    my $cleanSampleName = $self->getSampleName();
    $cleanSampleName =~ s/ /_/g;
    $self->setOutputFile($cleanSampleName .'_DEGseqAnalysis');
    
    
    return $self;
}

sub munge {
    my ($self) = @_;
    my $samplesHashref = $self->getSamplesHash();
    my $suffix = $self->getSuffix();
    my $sampleName = $self->getSampleName();
    $sampleName =~ s/_vs_/ vs /;
    my $mainDirectory=$self->getMainDirectory();
    my $outputFile = $self->getOutputFile();
    my $reference = $self->getReference();
    my $comparator = $self->getComparator();
    #   my $refCheck = $self->getRefCheck();
    #   my $compCheck = $self->getCompCheck();
#    $self->setNames([$sampleName]);
    my $fileName = $outputFile."_formatted";
    $fileName =~ s/ /_/g;
#    $self->setFileNames([$fileName]);    
    my @inputs;
    my @inputs2;
    my %samplesHash = %{$samplesHashref};
    
    
    opendir(DIR, $mainDirectory);
    
    
    my @ds = readdir(DIR);
    my $ref;
    my $comp;
    my $ref_sample_name;
    my $comp_sample_name;
    my $refSecondStrand;
    my $compSecondStrand;

    foreach my $d (sort @ds) {
	next unless $d =~ /(\S+)\.genes\.htseq-union(.+)counts/;
	my $sample = $1;
	my $strand = $2;
#	print Dumper "sample (deseqanalysis.pm) is $sample\n\n\n";
	if ($sample =~ /^$reference$/) { 
	    if ($strand =~ /secondstrand/) {
		$refSecondStrand = $d;
		my $sample2 = $sample."SecondStrand";
		    push @inputs2, $sample2;
	    }
	    else {
		$ref = $d;
		push @inputs, $sample;
	    }
	    
	    $ref_sample_name = $sample;
	    print Dumper "sample is $sample ref_sample_name is $ref_sample_name\n";
#	    push @inputs, $sample;
	}
	elsif ($sample =~ /^$comparator$/) {
	    if ($strand =~ /secondstrand/) {
		$compSecondStrand = $d;
		my $sample2 = $sample."SecondStrand";
		    push @inputs2, $sample2;

	    }
	    else {
		$comp = $d;
	    push @inputs, $sample;
	    }
	    
	    $comp_sample_name = $sample;
	    print Dumper "sample is $sample comp_sample_name is $comp_sample_name\n";
#	    push @inputs, $sample;
	}
	else {
	    
	    print Dumper "sample:: $sample ::  in deseqanalysis.pm sub munge creating ref and comp hashes doesnt match the reference or the comparator\n";
	}
    }
#    print Dumper "samples hash ref = $samplesHash{$reference}\n";
#    print Dumper "samples hash comp = $samplesHash{$comparator}\n";
    my $secondSampleName;
    &runDegseq($mainDirectory,$ref,$comp,$reference,$comparator, $fileName, $self, $sampleName);
#make file name in here now 
####################################################################################################
my $input_list = \@inputs;
    print Dumper "INPUT";
    print Dumper $input_list;
  $self->setSourceIdType('gene');
 $self->setInputProtocolAppNodesHash({$sampleName => $input_list});
$self->getProtocolParamsHash();
$self->addProtocolParamValue('reference',$reference);
$self->addProtocolParamValue('comparator',$comparator);
 $self->createConfigFile();

    if((defined $refSecondStrand) && (defined $compSecondStrand)) {
	my $secondOutputFile = $fileName;
	$secondOutputFile =~ s/_formatted/SecondStrand_formatted/;
	 $secondSampleName = $sampleName."SecondStrand";
	&runDegseq($mainDirectory,$refSecondStrand,$compSecondStrand, $reference, $comparator,$secondOutputFile, $self, $secondSampleName);
    }

    if (defined $secondSampleName) {
my $input_list = \@inputs2;
    print Dumper "INPUT2";
    print Dumper $input_list;
  $self->setSourceIdType('gene');
 $self->setInputProtocolAppNodesHash({$secondSampleName => $input_list});
$self->getProtocolParamsHash();
$self->addProtocolParamValue('reference',$reference);
$self->addProtocolParamValue('comparator',$comparator);
 $self->createConfigFile();
    }

    
#	my $input_list = \@inputs;
#	print Dumper "INPUT";
#	print Dumper $input_list;
#	$self->setSourceIdType('gene');
#	$self->setInputProtocolAppNodesHash({$secondSampleName => $input_list});
#	$self->getProtocolParamsHash();
#	$self->addProtocolParamValue('reference',$reference);
#	$self->addProtocolParamValue('comparator',$comparator);
#	$self->createConfigFile();
    
   
}


sub runDegseq {
    my ($mainDirectory,$ref,$comp,$reference,$comparator,$fileName,$self,$sampleName) = @_;
   $fileName =~ s/ /_/g;
    $self->setFileNames([$fileName]);    
    $self->setNames([$sampleName]);
    my $tempOut = $mainDirectory."\/DegOut";
    &runCmd("mkdir $tempOut");
    &runCmd("DEGseq.r $ref $comp $tempOut $reference $comparator");
    print Dumper 'command is ';
    print Dumper "DEGseq.r $ref $comp $tempOut $reference $comparator\n\n\n";
    print Dumpler $ref;
    print Dumper $comp;
    print Dumper $tempOut;
    print Dumper $reference;
    print Dumper $comparator;
#here I need to go into the output folder and format the output file correctly and rename it and remove all the other output files 
# JB suggested I rename the re formatted file and move it to the doTrans folder and then I can just delete the other folder. 
    
    open(my $OUT, ">$mainDirectory\/$fileName");
    print $OUT "ID\tfold_change\tp_value\tz_score\tis_significant\n";
    open( my $IN, "$tempOut\/output_score.txt");
    
   while (my $line = <$IN>) {
	chomp $line;
#	print "gettting to the printing of the formatted file\n\n\n\n\n ";
	if (($line =~/GeneNames/) || ($line=~ /^_/)) {
    #skip header
	    next;
	}
	else {
	    my @temps = split "\t", $line;
	    my $reportedFC;
	    my $id = $temps[0];
#	    $id =~ s/"//g;
	    my $foldchange = $temps[3];
#	    my $foldchange = 2**$log2fc;
#	    if ($foldchange >1 ) {
#		#its ok leave it alone
#	        $reportedFC = $foldchange;
#	    }
#	    else {
#		$reportedFC = (1/$foldchange)*(-1);
#	    }
	    my $pval = $temps[6];
	    my $z_score = $temps[5];
	    my $sig = $temps[9];
	    my $boolsig;
	    if ($sig eq 'TRUE') {
		 $boolsig = 1;
	    }
	    elsif ($sig eq 'FALSE') {
		$boolsig = 0;
	    }
	    print $OUT $id."\t".$foldchange."\t".$pval."\t".$z_score."\t".$boolsig."\n";
	}
   }
    
    close ($IN);
    close($OUT);

    &runCmd("rm -r $tempOut Rplots.pdf");
}


1;
