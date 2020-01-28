package ApiCommonData::Load::RnaSeqAnalysisEbi;
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
#use ApiCommonData::Load::DEGseqAnalysis;
use Data::Dumper;


my $OUTPUT_FILE_BASE = "profiles";

#-------------------------------------------------------------------------------

#print Dumper "editing right file\n";
sub getProfileSetName          { $_[0]->{profileSetName} }
sub getSamples                 { $_[0]->{samples} }

sub getIsStrandSpecific        { $_[0]->{isStrandSpecific} }
#sub getDoDegSeq                { $_[0]->{doDegSeq} }
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
    #my $valueType = 'fpkm';
    my $valueType = 'tpm';
    my $makePercentiles = 1;
    my $isStrandSpecific = $self->getIsStrandSpecific();
    #my $doDegSeq = $self->getDoDegSeq();
#    print Dumper "doDegSeq is $doDegSeq";
    my $samplesHash = $self->groupListHashRef($self->getSamples());
    my $profileSetName = $self->getProfileSetName();

    print Dumper $featureType;
    print Dumper $valueType;
    print Dumper $makePercentiles;
    print Dumper $isStrandSpecific;
    print Dumper $samplesHash;
    print Dumper $profileSetName;
    
    foreach my $sampleName (keys %$samplesHash) {
	my $intronJunctions = ApiCommonData::Load::IntronJunctions->new({sampleName => $sampleName,
									 inputs => $samplesHash->{$sampleName},
									 mainDirectory => $self->getMainDirectory,
									 profileSetName => $profileSetName,
									 samplesHash => $samplesHash,
									 suffix => 'junctions.tab'});
	$intronJunctions->setProtocolName("GSNAP/Junctions");
	$intronJunctions->setDisplaySuffix(" [junctions]");
	$intronJunctions->setTechnologyType($self->getTechnologyType());
	
	$intronJunctions->munge();
       }
    
    foreach my $quantificationType ('htseq-union') {    
    
	    if($isStrandSpecific) {
		$self->makeProfiles('firststrand', $featureType, $quantificationType, $valueType, $makePercentiles, 1);
		$self->makeProfiles('secondstrand', $featureType, $quantificationType, $valueType, $makePercentiles, 1);

		$self->makeProfiles('firststrand', $featureType, $quantificationType, $valueType, $makePercentiles, 0);
		$self->makeProfiles('secondstrand', $featureType, $quantificationType, $valueType, $makePercentiles, 0);

	    }
	    else {
		$self->makeProfiles('unstranded', $featureType, $quantificationType, $valueType, $makePercentiles, 1);
		$self->makeProfiles('unstranded', $featureType, $quantificationType, $valueType, $makePercentiles, 0);
	    }
    
    }
    
#DESeq2 Analysis starts here  
#    print Dumper "SamplesHash is\n";
    print Dumper %{$samplesHash};    
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
	    my $degRef = $Rrep1;
	   
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
	    my $degComp = $Crep1;
#
#	    print Dumper "degref $degRef compref $degComp\n";
   
#	    print Dumper "refcheck is\n";
#	    print Dumper $refCheck;
#	    print Dumper "compcheck is \n";
#	    print Dumper $compCheck;
	    
	    
	    if((@{$dataframeHash{$reference}} < 2) || (@{$dataframeHash{$comparator}} < 2 )) {
            continue;
		#if($doDegSeq) {
		#    print Dumper "$reference or $comparator do not have enough replicates to be anaylsed via DESeq2....so will be analysed via DEGseq\n";
#	#		my $suffix = 'differentialExpressionDEGseq';
		#    my $dataframeHashref = \%dataframeHash;
		#    
		#    if ($isStrandSpecific) {
	#		die, "TO DO - DEGSeq is not currently set to work on strand specific datasets. Please contact dataDev";
#		    }
	#	    else {
	#		my $DEGseqAnalysis = ApiCommonData::Load::DEGseqAnalysis->new({sampleName => $sampleNameClean,
#										       mainDirectory => $self->getMainDirectory,
#										       samplesHash => $dataframeHashref,
#										       reference => $degRef,
#										       comparator => $degComp,
#										       suffix => 'UnstrandedDEGseqAnalysis',
#										       profileSetName => $profileSetName});
#			$DEGseqAnalysis->setProtocolName("GSNAP/DEGseqAnalysis");
#			$DEGseqAnalysis->setDisplaySuffix( ' [DEGseqAnalysis - unstranded - unique]');
#			$DEGseqAnalysis->setTechnologyType($self->getTechnologyType());
#			$DEGseqAnalysis->munge();
#		    }
#		}
#		else {
#		    print Dumper "skipping those that we dont want to run DEGSeq analysis for";
#		}
	    }
	    else { # do it here isntead - run twice change suffix. 
		my $suffix = 'differentialExpression';
		my $dataframeHashref = \%dataframeHash;
#making new DESeq object
		if($isStrandSpecific) {
		    my $DeseqAnalysis = ApiCommonData::Load::DeseqAnalysis->new({sampleName => $sampleNameClean,
										 mainDirectory => $self->getMainDirectory,
										 samplesHash => $dataframeHashref,
										 reference => $ref,
										 referenceCheck => $refCheck,
										 comparator => $comp,
										 comparatorCheck => $compCheck,
										 suffix => 'FirststrandDESeq2Analysis',
										 #						     isStrandSpecific => $isStrandSpecific,
										 profileSetName => $profileSetName});
		    $DeseqAnalysis->setProtocolName("GSNAP/DESeq2Analysis");
		    $DeseqAnalysis->setDisplaySuffix( ' [DESeq2Analysis - firststrand - unique]');
		    $DeseqAnalysis->setTechnologyType($self->getTechnologyType());
		    $DeseqAnalysis->munge();
		    
		    
		    my $DeseqAnalysis = ApiCommonData::Load::DeseqAnalysis->new({sampleName => $sampleNameClean,
										 mainDirectory => $self->getMainDirectory,
										 samplesHash => $dataframeHashref,
										 reference => $ref,
										 referenceCheck => $refCheck,
										 comparator => $comp,
										 comparatorCheck => $compCheck,
										 suffix => 'SecondstrandDESeq2Analysis',
										 #						     isStrandSpecific => $isStrandSpecific,
										 profileSetName => $profileSetName});
		    $DeseqAnalysis->setProtocolName("GSNAP/DESeq2Analysis");
		    $DeseqAnalysis->setDisplaySuffix( ' [DESeq2Analysis - secondstrand - unique]');
		    $DeseqAnalysis->setTechnologyType($self->getTechnologyType());
		    $DeseqAnalysis->munge();
		    
		}
		else {
		    my $DeseqAnalysis = ApiCommonData::Load::DeseqAnalysis->new({sampleName => $sampleNameClean,
										 mainDirectory => $self->getMainDirectory,
										 samplesHash => $dataframeHashref,
										 reference => $ref,
										 referenceCheck => $refCheck,
										 comparator => $comp,
										 comparatorCheck => $compCheck,
										 suffix => 'UnstrandedDESeq2Analysis',
										 #						     isStrandSpecific => $isStrandSpecific,
										 profileSetName => $profileSetName});
		    $DeseqAnalysis->setProtocolName("GSNAP/DESeq2Analysis");
		    $DeseqAnalysis->setDisplaySuffix( ' [DESeq2Analysis - unstranded - unique]');
		    $DeseqAnalysis->setTechnologyType($self->getTechnologyType());
		    $DeseqAnalysis->munge();
		    
		}
	    }
	}
    }
}

sub makeProfiles {
    my ($self, $strand, $featureType, $quantificationType, $valueType, $makePercentiles, $isUnique) = @_;
    
    my $samples = $self->getSamples();
    
    my $profileSetName = $self->getProfileSetName();
    
    my $isStrandSpecific = $self->getIsStrandSpecific() ? $self->getIsStrandSpecific() : 'FALSE';
    
    #my $strandSuffix = ".$strand";
    #my $featureTypeSuffix = "$featureType";
    #my $quantificationTypeSuffix = ".$quantificationType";

    #my $valueTypeSuffix = ".$valueType";


    # cleanup for non unique
    if(!$isUnique) {
      $valueType = "nonunique.$valueType";
      $makePercentiles = 0;
    }
    
    #my $outputFile = $OUTPUT_FILE_BASE.$featureTypeSuffix.$quantificationTypeSuffix.$strandSuffix.$valueTypeSuffix;
    my $outputFile = "$OUTPUT_FILE_BASE.$featureType.$quantificationType.$strand.$valueType";
    
    my $profile = CBIL::TranscriptExpression::DataMunger::ProfileFromSeparateFiles->
	new({mainDirectory => $self->getMainDirectory,
	     outputFile => $outputFile,
	     makePercentiles => $makePercentiles,
	     isLogged => 0,
	     #fileSuffix => $featureTypeSuffix.$quantificationTypeSuffix.$strandSuffix.$valueTypeSuffix,
	     fileSuffix => "$featureType.$quantificationType.$strand.$valueType",
	     samples => $samples,
	     profileSetName => $profileSetName,
         sampleNameAsDir => 1,
	    });
    
    my $header = $quantificationType eq 'cuff' ? 1 : 0;
    my $header = 0;
    
    $profile->setHasHeader($header);
    
    #my $protocolName = $quantificationType eq 'cuff' ? 'Cufflinks' : 'HTSeq';
    my $protocolName = 'HTSeq';
    
    $profile->setProtocolName("GSNAP/$protocolName");
    
    $profile->addProtocolParamValue('Strand', $strand);
    $profile->addProtocolParamValue('FeatureType', $featureType);
    $profile->addProtocolParamValue('QuantificationType', $protocolName);
    
    if ($protocolName eq 'HTSeq') {
	$quantificationType =~ /^htseq-(.+)$/;
	my $mode = $1;
	$profile->addProtocolParamValue('Mode', $mode);
    }

    if($isUnique) {
      $profile->setDisplaySuffix(" [$quantificationType - $strand - $valueType - unique]");
    }
    else {
      $profile->setDisplaySuffix(" [$quantificationType - $strand - $valueType - nonunique]");
    }
    
    $profile->setTechnologyType($self->getTechnologyType());
    
    $profile->munge();
    
    return($outputFile);
}

1;
