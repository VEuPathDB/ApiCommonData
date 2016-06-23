 package ApiCommonData::Load::DeseqAnalysis;
use base qw(CBIL::TranscriptExpression::DataMunger::Loadable);
use CBIL::Util::Utils;
use strict;
#uses DESeq.r 

sub getSampleName {$_[0]->{sampleName}}
sub getSamplesHash {$_[0]->{samplesHash}}
sub getSuffix {$_[0]->{suffix}}
sub getMainDirectory {$_[0]->{mainDirectory}}
sub getReference {$_[0]->{reference}}
sub getComparator {$_[0]->{comparator}}


sub new {
#print  "gets into deseqanalysis sub new\n\n"; 
    my ($class, $args) = @_;
    
    my $requiredParams = [
	'sampleName',
	'samplesHash',
	'mainDirectory'
	];
    my $self = $class->SUPER::new($args, $requiredParams);
    
    
    my $cleanSampleName = $self->getSampleName();
    
    $self->setOutputFile($cleanSampleName .'_DESeq2Analysis');
    
    
    return $self;
}

sub munge {
    
#    print  "gets into deseqanalysis sub munge\n";
    my ($self) = @_;
    
    my $samplesHashref = $self->getSamplesHash();
    my $suffix = $self->getSuffix();
    my $sampleName = $self->getSampleName();
    my $mainDirectory=$self->getMainDirectory();
    my $outputFile = $self->getOutputFile();
    my $reference = $self->getReference();
    my $comparator = $self->getComparator();
    $self->setNames([$sampleName]);
    my $fileName = $outputFile."_formatted";
    $self->setFileNames([$fileName]);
    
    my @inputs;
    
#  print "$reference\n";
    # print "$comparator\n\n";
    # print "\\n main dir is $mainDirectory\n sample name is $sampleName\n\n\n\n ";
    my %samplesHash = %{$samplesHashref};
    # foreach my $keys (keys %samplesHash) { 
#      print "sample hash: key is  $keys \t sample is $samplesHash{$keys}\n\n\n";
    # }
    
#  open(OUT, "> $outputFile") or die "Cannot open output file $outputFile for writing:$!";
    
#ok so here I need to make my dataframes and pass this to the R code. 
    
#and then pull back the results from R inorder to create the configFile etc. 
    
########################################################### below ive simply copied my script this all needs editing. 
    opendir(DIR, $mainDirectory);
    my @ds = readdir(DIR);
    my %ref;
    my %comp;
    my $dataframeFile = $sampleName."_dataframe.txt";
    $dataframeFile =~ s/ /_/g;
    open(my $dataframe, ">$mainDirectory/$dataframeFile");
    print $dataframe "sample\tfile\tcondition\n";
    foreach my $d (sort @ds) {
	next unless $d =~ /(\S+)\.genes\.htseq-union.+counts/;
	next unless $d !~ /combined/;
#       print "directory: $d\n";
	my $sample = $1;
#	print  "sample (deseqanalysis.pm) is $sample\n\n\n";
	my $refKey = $reference;
	$refKey =~ s/ /_/g;
#	print "ref to check is $refKey";
	my $compKey = $comparator;
	$compKey =~ s/ /_/g;
#	print "comp to check is $compKey";
	if ($sample =~ /$refKey/) {
	    $ref{$sample} = $d;
	    push @inputs, $sample;
	}
	elsif ($sample =~ /$compKey/) {
	    $comp{$sample} = $d;
	    push @inputs, $sample;
	}
	else {
	    print "sample:: $sample ::  in deseqanalysis.pm sub munge creating ref and comp hashes doesnt match the reference or the comparator\n";
	}
    }
	foreach my $rep (keys %ref) {
#	    print "REF $rep\t\t\t\t$ref{$rep}\n\n\n";
	    print $dataframe $rep."\t".$ref{$rep}."\treference\n";
	}
	foreach my $rep (keys %comp) {
#	    print "COMP $rep\t\t\t\t$comp{$rep}\n\n\n";
	    print $dataframe $rep."\t".$comp{$rep}."\tcomparator\n";
	}
    
    
    

  close($dataframe);

 # my $cmd = "echo \'inputDir = \"$mainDirectory\";dataFrame=\"$dataframeFile\";outputDir=\"$mainDirectory\"\' \|cat - DESeq.r \| R --no-save";
#print "command is $cmd\n";
#    my $cmd= "awk \'\{ FS\ = \"\,\" \} \;\{print \$1\"\\t\"\$3\"\\t\"\$6\"\\t\"\$7\}\' $mainDirectory$outputFile ";
 # system ($cmd);
    $outputFile =~ s/ /_/g;
 &runCmd("DESeq.r $dataframeFile $mainDirectory $mainDirectory $outputFile");
    $fileName =~ s/ /_/g;
    open(my $OUT, ">$mainDirectory$fileName");
    print $OUT "ID\tfold_change\tp_value\tadj_p_value\n";
    open( my $IN, "$mainDirectory$outputFile");
    while (my $line = <$IN>) {
	chomp $line;
	if ($line =~/baseMean/) {
	    #skip header
	    next;
	}
	else {
	    my @temps = split ",", $line;
	    my $reportedFC;
	    my $id = $temps[0];
	    my $log2fc = $temps[2];
	    my $foldchange = 2**$log2fc;
	    if ($foldchange >1 ) {
		#its ok leave it alone
	        $reportedFC = $foldchange;
	    }
	    else {
		$reportedFC = (1/$foldchange)*(-1);
	    }
	    my $pval = $temps[5];
	    my $adjp = $temps[6];
	    print $OUT $id."\t".$reportedFC."\t".$pval."\t".$adjp."\n";
	}
    }
    
    close ($IN);
    close($OUT);

####################################################################################################
#  close OUT;
my $input_list = \@inputs;
  $self->setSourceIdType('gene');
  $self->setInputProtocolAppNodesHash({$sampleName => $input_list});
$self->getProtocolParamsHash();
$self->addProtocolParamValue('reference',$reference);
$self->addProtocolParamValue('comparator',$comparator);
 $self->createConfigFile();
}


1;
