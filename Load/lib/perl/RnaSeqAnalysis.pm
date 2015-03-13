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


my $OUTPUT_FILE_BASE = "profiles";

#-------------------------------------------------------------------------------

 sub getSamples                 { $_[0]->{samples} }
 sub getIsPairedEnd             { $_[0]->{isPairedEnd} }
 sub getIsStrandSpecific        { $_[0]->{isStrandSpecific} }

#-------------------------------------------------------------------------------
sub new {
  my ($class, $args) = @_;
    my $requiredParams = [
                          'samples',
                         ];
  my $self = $class->SUPER::new($args, $requiredParams);

  if(my $outputPrefix = $self->getOutputFile()) {
    $OUTPUT_FILE_BASE = $outputPrefix . $OUTPUT_FILE_BASE;
  }

  return $self;
}

sub munge {
  my ($self) = @_;

  foreach my $featureType ("genes", "isoforms") {
    my $isStrandSpecific = $self->getIsStrandSpecific();

    foreach my $alignmentType ("unique", "nu") {
      my $makePercentiles = $alignmentType eq "unique" ? 1 : 0;

      if($isStrandSpecific) {
        $self->makeProfiles('fr-firststrand', $featureType, $alignmentType, $makePercentiles);
        $self->makeProfiles('fr-secondstrand', $featureType, $alignmentType, $makePercentiles);
      }
      else {
        my ($minOutFn, $maxOutfn) = $self->makeProfiles('fr-unstranded', $featureType, $alignmentType, $makePercentiles);
      }
    }
  }
}


sub makeProfiles {
  my ($self, $strand, $featureType, $alignmentType, $makePercentiles) = @_;

  my $samples = $self->getSamples();

  my $isPairedEnd = $self->getIsPairedEnd() ? $self->getIsPairedEnd() : 'FALSE';
  my $isStrandSpecific = $self->getIsStrandSpecific() ? $self->getIsStrandSpecific() : 'FALSE';

  my $strandSuffix = ".$strand";
  my $featureTypeSuffix = ".$featureType";
  my $alignmentTypeSuffix = ".$alignmentType";


  my $outputFile = $OUTPUT_FILE_BASE.$featureTypeSuffix.$alignmentTypeSuffix.$strandSuffix;

  my $profile = CBIL::TranscriptExpression::DataMunger::ProfileFromSeparateFiles->
      new({mainDirectory => $self->getMainDirectory,
           outputFile => $outputFile,
           makePercentiles => $makePercentiles,
           isLogged => 0,
           fileSuffix => $featureTypeSuffix.$alignmentTypeSuffix.$strandSuffix,
           samples => $samples,
             });


  $profile->setHasHeader(1);

  if($featureType eq 'genes') {
    $profile->setSourceIdType('gene');
  }

  $profile->setProtocolName("GSNAP/Cufflinks");
  
  $profile->addProtocolParamValue('Strand', $strand);
  $profile->addProtocolParamValue('FeatureType', $featureType);
  $profile->addProtocolParamValue('AlignmentType', $alignmentType);
  $profile->addProtocolParamValue('IsPairedEnd', $isPairedEnd);
  $profile->addProtocolParamValue('IsStrandSpecific', $isStrandSpecific);

  $profile->setDisplaySuffix(" - $alignmentType - $strand");

  $profile->munge();

  return($outputFile);
}



1;
