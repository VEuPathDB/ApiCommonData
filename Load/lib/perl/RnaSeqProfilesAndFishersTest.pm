package ApiCommonData::Load::RnaSeqProfilesAndFishersTest;
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
  # GUS4_STATUS | dots.gene                      | manual | unreviewed
die 'This file has broken or unreviewed GUS4_STATUS rules.  Please remove this line when all are fixed or absent';
#^^^^^^^^^^^^^^^^^^^^^^^^^ End GUS4_STATUS ^^^^^^^^^^^^^^^^^^^^
use base qw(CBIL::TranscriptExpression::DataMunger);

use strict;

use CBIL::TranscriptExpression::Error;
use CBIL::TranscriptExpression::DataMunger::ProfileFromSeparateFiles;
use CBIL::TranscriptExpression::DataMunger::ProfileDifferences;
use CBIL::TranscriptExpression::DataMunger::AllPairwiseRNASeqFishers;
use CBIL::TranscriptExpression::DataMunger::ConcatenateProfiles;

use CBIL::TranscriptExpression::DataMunger::RNASeqFishersTest qw($CONFIG_FILE);
use CBIL::TranscriptExpression::DataMunger::RadAnalysis;

my $outputFileBase = "profiles";
my $fileSuffixBase = ".intensity";
my $minSuffix = ".min";
my $maxSuffix = ".max";
my $diffSuffix = ".diff";
my $antisenseSuffix = ".antisense";

#-------------------------------------------------------------------------------

 sub getProfileSetName          { $_[0]->{profileSetName} }
 sub getSamples                 { $_[0]->{samples} }
 sub getIsPairedEnd             { $_[0]->{isPairedEnd} }
 sub getIsTimeSeries            { $_[0]->{isTimeSeries} }
 sub getSkipFishers             { $_[0]->{skipFishers} }
 sub getIsStrandSpecific        { $_[0]->{isStrandSpecific} }

#-------------------------------------------------------------------------------
sub new {
  my ($class, $args) = @_;
    my $requiredParams = ['profileSetName',
                          'samples',
                         ];
  my $self = $class->SUPER::new($args, $requiredParams);

  if(my $outputPrefix = $self->getOutputFile()) {
    $outputFileBase = $outputPrefix . $outputFileBase;
  }

  return $self;
}

sub munge {
  my ($self) = @_;

  my $isStrandSpecific = $self->getIsStrandSpecific();

  $self->processStandardProfiles();

  if($isStrandSpecific) {
    my ($minPlusOutFile, $maxPlusOutFile) = $self->makeMinMaxDiffProfiles(undef, 'plus', 'sense');
    my ($minMinusOutFile, $maxMinusOutFile) = $self->makeMinMaxDiffProfiles(undef, 'minus', 'sense');

    $self->makeStrandSpecificProfiles($minPlusOutFile, $minMinusOutFile, $maxPlusOutFile, $maxMinusOutFile, 'sense');

    my ($minAntiPlusOutFile, $maxAntiPlusOutFile) = $self->makeMinMaxDiffProfiles(undef, 'plus', 'antisense');
    my ($minAntiMinusOutFile, $maxAntiMinusOutFile) = $self->makeMinMaxDiffProfiles(undef, 'minus', 'antisense');

    $self->makeStrandSpecificProfiles($minAntiPlusOutFile, $minAntiMinusOutFile, $maxAntiPlusOutFile, $maxAntiMinusOutFile, 'antisense');
  }

}

sub makeStrandSpecificProfiles {
  my ($self, $minPlusOutFile, $minMinusOutFile, $maxPlusOutFile, $maxMinusOutFile, $strand) = @_;

  my $profileSetName = $self->getProfileSetName();
  my $isTimeSeries = $self->getIsTimeSeries();

  my $strandProfileSetName = $profileSetName . " - $strand strand";
  my $strandSuffix = ".$strand";

  my $strandMinProfileOutputFile = $outputFileBase.$minSuffix.$strandSuffix;
  my $strandMaxProfileOutputFile = $outputFileBase.$maxSuffix.$strandSuffix;

  my $strandProfileMin = CBIL::TranscriptExpression::DataMunger::ConcatenateProfiles->
      new({fileOne => $minPlusOutFile,
           fileTwo => $minMinusOutFile,
           outputFile => $strandMinProfileOutputFile,
           profileSetName => $strandProfileSetName,
           mainDirectory => $self->getMainDirectory,
           isLogged => 0,
           makePercentiles => 1,
           isTimeSeries => $isTimeSeries,
         });

  $strandProfileMin->munge();

  my $strandProfileMax = CBIL::TranscriptExpression::DataMunger::ConcatenateProfiles->
      new({fileOne => $maxPlusOutFile,
           fileTwo => $maxMinusOutFile,
           outputFile => $strandMaxProfileOutputFile,
           doNotLoad => 1,
           mainDirectory => $self->getMainDirectory,
           profileSetName => 'PLACEHOLDER', #shouldn't be needed here
           isLogged => 0,
           makePercentiles => 0,
           isTimeSeries => $isTimeSeries,
         });

  $strandProfileMax->munge();

  my $diffSenseProfileSetName = $strandProfileSetName. " - diff";
  my $diffOutputFile = $outputFileBase.$diffSuffix.$strandSuffix;

  $self->makeDiffProfile($diffOutputFile, $strandMaxProfileOutputFile, $strandMinProfileOutputFile, $diffSenseProfileSetName);
}


sub makeDiffProfile {
  my ($self, $outFile, $minuendFile, $subtrahendFile, $profileSetName) = @_;

  my $diffProfile = CBIL::TranscriptExpression::DataMunger::ProfileDifferences->
      new({mainDirectory => $self->getMainDirectory,
           outputFile => $outFile,
           isLogged => 0,
           minuendFile => $minuendFile,
           subtrahendFile => $subtrahendFile,
           profileSetName => $profileSetName,
             });
  
  $diffProfile->munge();
}



sub makeMinMaxDiffProfiles {
  my ($self, $profileSetName, $geneStrand, $readRelativeStrand) = @_;

  my $samples = $self->getSamples();
  my $isTimeSeries = $self->getIsTimeSeries();

  my $doNotLoadMinProfile = 0;
  my $strandSuffix;
  if($geneStrand) {
    $strandSuffix = ".$geneStrand";
    $profileSetName = $profileSetName . " - $geneStrand";
    $doNotLoadMinProfile = 1;
  }

  my $antisenseSuffix;
  if($readRelativeStrand eq 'antisense') {
    $antisenseSuffix = ".antisense";
    $profileSetName = $profileSetName . " - $readRelativeStrand";
  }

  my $minOutFile = $outputFileBase.$minSuffix.$strandSuffix.$antisenseSuffix;
  my $maxOutFile = $outputFileBase.$maxSuffix.$strandSuffix.$antisenseSuffix;

  my $minProfile = CBIL::TranscriptExpression::DataMunger::ProfileFromSeparateFiles->
      new({mainDirectory => $self->getMainDirectory,
           outputFile => $minOutFile,
           makePercentiles => 1,
           isLogged => 0,
           fileSuffix => $antisenseSuffix.$strandSuffix.$fileSuffixBase.$minSuffix,
           profileSetName => $profileSetName,
           samples => $samples,
           isTimeSeries => $isTimeSeries,
           doNotLoad => $doNotLoadMinProfile
             });
  $minProfile->munge();
  
  my $maxProfile = CBIL::TranscriptExpression::DataMunger::ProfileFromSeparateFiles->
      new({mainDirectory => $self->getMainDirectory,
           outputFile => $maxOutFile,
           makePercentiles => 0,
           isLogged => 0,
           fileSuffix => $antisenseSuffix.$strandSuffix.$fileSuffixBase.$maxSuffix,
           profileSetName => $profileSetName, # this really isn't needed here??
           samples => $samples,
           doNotLoad => 1
             });
  $maxProfile->munge();

  unless($geneStrand) {
    my $diffProfileSetName = $profileSetName . " - diff";
    my $diffOutputFile = $outputFileBase.$diffSuffix.$strandSuffix.$antisenseSuffix;

    $self->makeDiffProfile($diffOutputFile, $maxOutFile, $minOutFile, $diffProfileSetName);
  }

  return($minOutFile, $maxOutFile);
}



sub processStandardProfiles {
  my ($self) = @_;

  my $profileSetName = $self->getProfileSetName();
  my $samples = $self->getSamples();
  my $isTimeSeries = $self->getIsTimeSeries();

  my ($minOutFn, $maxOutfn) = $self->makeMinMaxDiffProfiles($profileSetName, undef, 'sense');

  my $skipFishers = ($self->getSkipFishers()) ? 1 : undef;

  unless($skipFishers || scalar @$samples < 2 ) {
    my $isPairedEnd = $self->getIsPairedEnd();

    my $fishers = CBIL::TranscriptExpression::DataMunger::AllPairwiseRNASeqFishers->
        new({mainDirectory => $self->getMainDirectory,
             profileSetName => $profileSetName,
             conditions => $samples,
             isPairedEnd => $isPairedEnd,
          });
    $fishers->munge();
  }
  else {
    my $dummy = CBIL::TranscriptExpression::DataMunger::RadAnalysis->
      new({mainDirectory => $self->getMainDirectory });
    $dummy->setConfigFile($CONFIG_FILE);
    $dummy->createConfigFile(1); # Only write dummy config once ... not for each strand
  }
}
1;
