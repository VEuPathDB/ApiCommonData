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
use Data::Dumper;


my $OUTPUT_FILE_BASE = "profiles";

#-------------------------------------------------------------------------------

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
#    print Dumper $samplesHash;
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
#print Dumper "intronJunctions is\n";
#print Dumper $intronJunctions;    
    }
    
    foreach my $quantificationType ('htseq-union') {    
	foreach my $quantificationType ('cuff', 'htseq-union', 'htseq-intersection-nonempty', 'htseq-intersection-strict') {
	    if($isStrandSpecific) {
		$self->makeProfiles('firststrand', $featureType, $quantificationType, $valueType, $makePercentiles);
		$self->makeProfiles('secondstrand', $featureType, $quantificationType, $valueType, $makePercentiles);
	    }
	    else {
		$self->makeProfiles('unstranded', $featureType, $quantificationType, $valueType, $makePercentiles);
	    }
	}
    }


    
#print Dumper "gets to start\n";
    
    if (keys %{$samplesHash} <2) {
	print Dumper  "note: there are less than two conditions DESeq2 analysis can not be done\n";
	next;
    }
    else { 
	my @array1;
	my @array2;
	my %pairHash;
# here i need to add a check on the number of reps 
	foreach my $key (keys %{$samplesHash}) {
		push @array1 , $key;
		push @array2, $key;
	}
       
#	print Dumper "arrays";
#	print Dumper @array1;
#	print Dumper @array2;
	
	foreach my $element (@array1) {
	    foreach my $second (@array2) {  
		if ($element eq $second) {
		    
		}
		else {
#		    print Dumper "gets to creating pairs\n";
		    my $pair = $element."_vs_".$second;
		    $pair =~ s/ /_/g;
		    $pairHash{$pair} =1;
		}
	    }
	}
#	print Dumper "pair hash is\n";
#	print Dumper %pairHash;
	foreach my $key (keys %pairHash) {

	    my @temps = split "_vs_" , $key;
	    my $sampleNameClean = $key;
	    $sampleNameClean =~ s/_/ /g;
	    my $reference = $temps[0];
	    my $comparator = $temps[1];
	    my %dataframeHash;
	    my $ref = $reference; 
	    $ref =~ s/_/ /g;
	    my $comp = $comparator;
	    $comp =~ s/_/ /g;
	    $dataframeHash{$reference} = $samplesHash->{$ref};
	    $dataframeHash{$comparator} = $samplesHash->{$comp};
	    if((@{$dataframeHash{$reference}} < 2) || (@{$dataframeHash{$comparator}} < 2 )) {

		print Dumper "$reference or $comparator do not have enough replicates to be anaylsed....skipping\n";
	    }
	    else {
		my $suffix = 'differentialExpression';
		my $dataframeHashref = \%dataframeHash;
#	    print Dumper "reference is";
#	    print Dumper $ref;
#	    print Dumper "comparator is";
#	    print Dumper $comp;
#	    print Dumper "\n dataframe hash\n";
#	    print Dumper %dataframeHash;

		my $DeseqAnalysis = ApiCommonData::Load::DeseqAnalysis->new({sampleName => $sampleNameClean,
									     mainDirectory => $self->getMainDirectory,
									     samplesHash => $dataframeHashref,
									     reference => $ref,
									     comparator => $comp,
									     suffix => 'DESeq2Analysis',
									     profileSetName => $profileSetName});
		$DeseqAnalysis->setProtocolName("GSNAP/DESeq2Analysis");
		$DeseqAnalysis->setDisplaySuffix( ' [DESeq2Analysis]');
		$DeseqAnalysis->setTechnologyType($self->getTechnologyType());
		$DeseqAnalysis->munge();
#	    print Dumper "deseqanalysis object is";
#	    print Dumper $DeseqAnalysis;
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

#    if($protocolName eq 'DESeq2Analysis') {
#	$profile->addProtocolParamValue('reference' , $DeseqAnalysis->{reference});
#	$profile ->addProtocolParamValue('comparator', $DeseqAnalysis->{comparator});
 #   $profile->addProtocolParamValue('IsStrandSpecific', $isStrandSpecific);
 #   }

    $profile->setDisplaySuffix(" [$quantificationType - $strand - $valueType]");
    
    $profile->setTechnologyType($self->getTechnologyType());
    
    $profile->munge();
    
    return($outputFile);
}

1;
