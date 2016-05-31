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
#    foreach my $quantificationType ('cuff', 'htseq-union', 'htseq-intersection-nonempty', 'htseq-intersection-strict') {
	if($isStrandSpecific) {
	    $self->makeProfiles('firststrand', $featureType, $quantificationType, $valueType, $makePercentiles);
	    $self->makeProfiles('secondstrand', $featureType, $quantificationType, $valueType, $makePercentiles);
	}
	else {
	    $self->makeProfiles('unstranded', $featureType, $quantificationType, $valueType, $makePercentiles);
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
  $profile->addProtocolParamValue('IsStrandSpecific', $isStrandSpecific);

  $profile->setDisplaySuffix(" [$quantificationType - $strand - $valueType]");

  $profile->setTechnologyType($self->getTechnologyType());

  $profile->munge();

  return($outputFile);
}

1;
