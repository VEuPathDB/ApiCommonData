 package ApiCommonData::Load::DEGseqAnalysis;
use base qw(CBIL::TranscriptExpression::DataMunger::Loadable);
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
    $self->setNames([$sampleName]);
    my $fileName = $outputFile."_formatted";
    $fileName =~ s/ /_/g;
    $self->setFileNames([$fileName]);    
    my @inputs;
    
    my %samplesHash = %{$samplesHashref};
    
    
    opendir(DIR, $mainDirectory);
    
    
    my @ds = readdir(DIR);
    my $ref;
    my $comp;
    foreach my $d (sort @ds) {
	next unless $d =~ /(\S+)\.genes\.htseq-union.+counts/;
	my $sample = $1;
#	print Dumper "sample (deseqanalysis.pm) is $sample\n\n\n";
	if ($sample =~ /$reference/) { 
	    $ref = $d;
	    push @inputs, $sample;
	}
	elsif ($sample =~ /$comparator/) {
	    $comp = $d;
	    push @inputs, $sample;
	}
	else {
	    
	    #print Dumper "sample:: $sample ::  in deseqanalysis.pm sub munge creating ref and comp hashes doesnt match the reference or the comparator\n";
	}
    }

    $outputFile =~ s/ /_/g;
    my $tempOut = "$mainDirectory/DegOut";
    &runCmd("mkdir $tempOut");
    &runCmd("DEGseq.r $ref $comp $tempOut $reference $comparator");
        
    
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
####################################################################################################
my $input_list = \@inputs;
  $self->setSourceIdType('gene');
  $self->setInputProtocolAppNodesHash({$sampleName => $input_list});
$self->getProtocolParamsHash();
$self->addProtocolParamValue('reference',$reference);
$self->addProtocolParamValue('comparator',$comparator);
 $self->createConfigFile();
   
}


1;
