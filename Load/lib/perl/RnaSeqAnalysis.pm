package ApiCommonData::Load::RnaSeqAnalysis;
#vvvvvvvvvvvvvvvvvvvvvvvvv GUS4_STATUS vvvvvvvvvvvvvvvvvvvvvvvvv
# GUS4_STATUS | SRes.OntologyTerm              | auto   | absent
# GUS4_STATUS | SRes.SequenceOntology          | auto   | absent
# GUS4_STATUS | Study.OntologyEntry            | auto   | absent
# GUS4_STATUS | SRes.GOTerm                    | auto   | absent
# GUS4_STATUS | Dots.RNAFeatureExon            | auto   | absent
# GUS4_STATUS | RAD.SageTag                    | auto   | absent
# GUS4_STATUS | RAD.Analysis                   | auto   | absent
# GUS4_STATUS | ApiDB.Profile                  | auto   | fixed
# GUS4_STATUS | Study.Study                    | auto   | absent
# GUS4_STATUS | Dots.Isolate                   | auto   | absent
# GUS4_STATUS | DeprecatedTables               | auto   | absent
# GUS4_STATUS | Pathway                        | auto   | absent
# GUS4_STATUS | DoTS.SequenceVariation         | auto   | absent
# GUS4_STATUS | RNASeq Junctions               | auto   | absent
# GUS4_STATUS | Simple Rename                  | auto   | absent
# GUS4_STATUS | ApiDB Tuning Gene              | auto   | absent
# GUS4_STATUS | Rethink                        | auto   | absent
# GUS4_STATUS | dots.gene                      | manual | absent
#^^^^^^^^^^^^^^^^^^^^^^^^^ End GUS4_STATUS ^^^^^^^^^^^^^^^^^^^^
use base qw(CBIL::TranscriptExpression::DataMunger);

use strict;

use CBIL::TranscriptExpression::Error;
use CBIL::TranscriptExpression::DataMunger::ProfileFromSeparateFiles;




use ApiCommonData::Load::IntronJunctions;
use ApiCommonData::Load::DeseqAnalysis;
use ApiCommonData::Load::DEGseqAnalysis;
use Data::Dumper;


my $OUTPUT_FILE_BASE = "profiles";

#-------------------------------------------------------------------------------

#print Dumper "editing right file\n";
sub getProfileSetName          { $_[0]->{profileSetName} }
sub getSamples                 { $_[0]->{samples} }

sub getIsStrandSpecific        { $_[0]->{isStrandSpecific} }

#-------------------------------------------------------------------------------
sub new {
    my ($class, $args) = @_;
    my $requiredParams = [
	'samples',
	'profileSetName',
	];
    my $self = $class->SUPER::new($args, $requiredParams);
    
    if(my $outputPrefix = $self->getOutputFile()) {
	$OUTPUT_FILE_BASE = $outputPrefix . $OUTPUT_FILE_BASE;
    }
    
    return $self;
}

sub munge {
    my ($self) = @_;
    
    my $featureType = 'genes';
    my $valueType = 'fpkm';
    my $makePercentiles = 1;
    my $isStrandSpecific = $self->getIsStrandSpecific();
    
    my $samplesHash = $self->groupListHashRef($self->getSamples());
    my $profileSetName = $self->getProfileSetName();

    foreach my $sampleName (keys %$samplesHash) {
	my $intronJunctions = ApiCommonData::Load::IntronJunctions->new({sampleName => $sampleName,
									 inputs => $samplesHash->{$sampleName},
									 mainDirectory => $self->getMainDirectory,
									 profileSetName => $profileSetName,
									 samplesHash => $samplesHash,
									 suffix => '_junctions.tab'});
	$intronJunctions->setProtocolName("GSNAP/Junctions");
	$intronJunctions->setDisplaySuffix(" [junctions]");
	$intronJunctions->setTechnologyType($self->getTechnologyType());
	
	$intronJunctions->munge();
    }
    
    foreach my $quantificationType ('htseq-union') {    
	
	    if($isStrandSpecific) {
		$self->makeProfiles('firststrand', $featureType, $quantificationType, $valueType, $makePercentiles);
		$self->makeProfiles('secondstrand', $featureType, $quantificationType, $valueType, $makePercentiles);
	    }
	    else {
		$self->makeProfiles('unstranded', $featureType, $quantificationType, $valueType, $makePercentiles);
	    }
	
    }
    
#DESeq2 Analysis starts here  
#print Dumper "SamplesHash is\n";
#print Dumper %{$samplesHash};    
    if (keys %{$samplesHash} <2) {
	print Dumper  "note: there are less than two conditions DESeq2 analysis  and or DEGseq analysis can not be done\n";
	next;
    }
    else { 
	my @array1;
	my @array2;
	my %pairHash;
# check on the number of reps 
	foreach my $key (keys %{$samplesHash}) {
		push @array1 , $key;
		push @array2, $key;
	}
       
	foreach my $element (@array1) {
	    foreach my $second (@array2) {  
		if ($element eq $second) {
		    
		}
		else {
		    my $pair = $element."_vs_".$second;
		    $pairHash{$pair} =1;
		}
	    }
	}

#	print Dumper "\n\npairHash is \n\n\n\n\n";
#	print Dumper %pairHash;
	foreach my $key (keys %pairHash) {

	    my @temps = split "_vs_" , $key;
	    my $sampleNameClean = $key;
	    my $reference = $temps[1];
	    my $comparator = $temps[0];
	    my %dataframeHash;
	    my $ref = $reference; 
	    my $comp = $comparator;
#	    print Dumper "\n\nREF is \n";
#	    print Dumper $ref;
#	    print Dumper "\n\n COMP is \n";
#	    print Dumper $comp;
	    $dataframeHash{$reference} = $samplesHash->{$ref};
	    $dataframeHash{$comparator} = $samplesHash->{$comp};
#	    print Dumper "\n\ndataframeHash is \n";
#	    print Dumper %dataframeHash;

##### trying to workout ref checks etc to deal with display names not matching sample names 
	    my $Rrep1 = $dataframeHash{$reference}[0];
	    my $Rrep2 = $dataframeHash{$reference}[1];
	    my @Rbase1 = split "", $Rrep1;
	    my @Rbase2 = split"", $Rrep2;
	    my $RrepBaseName;
	    my $CrepBaseName;
	    for (my $i=0; $i <= @Rbase1; $i++) {
		if ($Rbase1[$i] eq $Rbase2[$i]) {
		    $RrepBaseName.= $Rbase1[$i];
		}
		else {
		    last;
		}
	    }
	    my $refCheck = $RrepBaseName;

	    my $Crep1 = $dataframeHash{$comparator}[0];
	    my $Crep2 = $dataframeHash{$comparator}[1];
	    my @Cbase1 = split "", $Crep1;
	    my @Cbase2 = split"", $Crep2;
	    for (my $i=0; $i <= @Cbase1; $i++) {
		if ($Cbase1[$i] eq $Cbase2[$i]) {
		    $CrepBaseName.= $Cbase1[$i];
		}
		else {
		    last;
		}
	    }
	    my $compCheck = $CrepBaseName;
#	    print Dumper "refcheck is\n";
#	    print Dumper $refCheck;
#	    print Dumper "compcheck is \n";
#	    print Dumper $compCheck;


	    if((@{$dataframeHash{$reference}} < 2) || (@{$dataframeHash{$comparator}} < 2 )) {

		print Dumper "$reference or $comparator do not have enough replicates to be anaylsed via DESeq2....so will be analysed via DEGseq\n";
		my $suffix = 'differentialExpressionDEGseq';
		my $dataframeHashref = \%dataframeHash;
#making new DEGseq object
		my $DEGseqAnalysis = ApiCommonData::Load::DEGseqAnalysis->new({sampleName => $sampleNameClean,
									     mainDirectory => $self->getMainDirectory,
									     samplesHash => $dataframeHashref,
									     reference => $ref,
									     comparator => $comp,
									     suffix => 'DEGseqAnalysis',
									     profileSetName => $profileSetName});
		$DEGseqAnalysis->setProtocolName("GSNAP/DEGseqAnalysis");
		$DEGseqAnalysis->setDisplaySuffix( ' [DEGseqAnalysis]');
		$DEGseqAnalysis->setTechnologyType($self->getTechnologyType());
		$DEGseqAnalysis->munge();

	    }
	    else {
		my $suffix = 'differentialExpression';
		my $dataframeHashref = \%dataframeHash;
#making new DESeq object
		my $DeseqAnalysis = ApiCommonData::Load::DeseqAnalysis->new({sampleName => $sampleNameClean,
									     mainDirectory => $self->getMainDirectory,
									     samplesHash => $dataframeHashref,
									     reference => $ref,
									     referenceCheck => $refCheck,
									     comparator => $comp,
									     comparatorCheck => $compCheck,
									     suffix => 'DESeq2Analysis',
									     profileSetName => $profileSetName});
		$DeseqAnalysis->setProtocolName("GSNAP/DESeq2Analysis");
		$DeseqAnalysis->setDisplaySuffix( ' [DESeq2Analysis]');
		$DeseqAnalysis->setTechnologyType($self->getTechnologyType());
		$DeseqAnalysis->munge();
	    }
	}
    }
}

sub makeProfiles {
    my ($self, $strand, $featureType, $quantificationType, $valueType, $makePercentiles) = @_;
    
    my $samples = $self->getSamples();
    
    my $profileSetName = $self->getProfileSetName();
    
    my $isStrandSpecific = $self->getIsStrandSpecific() ? $self->getIsStrandSpecific() : 'FALSE';
    
    my $strandSuffix = ".$strand";
    my $featureTypeSuffix = ".$featureType";
    my $quantificationTypeSuffix = ".$quantificationType";
    my $valueTypeSuffix = ".$valueType";
    
    
    
    my $outputFile = $OUTPUT_FILE_BASE.$featureTypeSuffix.$quantificationTypeSuffix.$strandSuffix.$valueTypeSuffix;
    
    my $profile = CBIL::TranscriptExpression::DataMunger::ProfileFromSeparateFiles->
	new({mainDirectory => $self->getMainDirectory,
	     outputFile => $outputFile,
	     makePercentiles => $makePercentiles,
	     isLogged => 0,
	     fileSuffix => $featureTypeSuffix.$quantificationTypeSuffix.$strandSuffix.$valueTypeSuffix,
	     samples => $samples,
	     profileSetName => $profileSetName,
	    });
    
    my $header = $quantificationType eq 'cuff' ? 1 : 0;
    
    $profile->setHasHeader($header);
    
    my $protocolName = $quantificationType eq 'cuff' ? 'Cufflinks' : 'HTSeq';
    
    $profile->setProtocolName("GSNAP/$protocolName");
    
    $profile->addProtocolParamValue('Strand', $strand);
    $profile->addProtocolParamValue('FeatureType', $featureType);
    $profile->addProtocolParamValue('QuantificationType', $protocolName);
    
    if ($protocolName eq 'HTSeq') {
	$quantificationType =~ /^htseq-(.+)$/;
	my $mode = $1;
	$profile->addProtocolParamValue('Mode', $mode);
    }

    $profile->setDisplaySuffix(" [$quantificationType - $strand - $valueType]");
    
    $profile->setTechnologyType($self->getTechnologyType());
    
    $profile->munge();
    
    return($outputFile);
}

1;
