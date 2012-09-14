package ApiCommonData::Load::RnaSeqProfilesAndFishersTest;
use base qw(CBIL::TranscriptExpression::DataMunger);

use strict;

use CBIL::TranscriptExpression::Error;
use CBIL::TranscriptExpression::DataMunger::ProfileFromSeparateFiles;
use CBIL::TranscriptExpression::DataMunger::ProfileDifferences;
use CBIL::TranscriptExpression::DataMunger::AllPairwiseRNASeqFishers;

use CBIL::TranscriptExpression::DataMunger::RNASeqFishersTest qw($CONFIG_FILE);
use CBIL::TranscriptExpression::DataMunger::RadAnalysis;

my $outputFileBase = "profiles";
my $fileSuffixBase = "intensity";
my $minSuffix = ".min";
my $maxSuffix = ".max";
my $diffSuffix = ".diff";

#-------------------------------------------------------------------------------

 sub getProfileSetName          { $_[0]->{profileSetName} }
 sub getSamples                 { $_[0]->{samples} }
 sub getIsPairedEnd             { $_[0]->{isPairedEnd} }
 sub getIsTimeSeries            { $_[0]->{isTimeSeries} }
 sub getSkipFishers             { $_[0]->{skipFishers} }

#-------------------------------------------------------------------------------
sub new {
  my ($class, $args) = @_;
    my $requiredParams = ['profileSetName',
                          'samples',
                         ];
  my $self = $class->SUPER::new($args, $requiredParams);

  return $self;
}

sub munge {
  my ($self) = @_;
  my $isTimeSeries = $self->getIsTimeSeries();
  my $profileSetName = $self->getProfileSetName();
  my $samples = $self->getSamples();

  my $minProfile = CBIL::TranscriptExpression::DataMunger::ProfileFromSeparateFiles->
    new({mainDirectory => $self->getMainDirectory,
         outputFile => $outputFileBase.$minSuffix,
         makePercentiles => 1,
         isLogged => 0,
         fileSuffix => $fileSuffixBase.$minSuffix,
         profileSetName => $profileSetName,
         samples => $samples,
         isTimeSeries => $isTimeSeries
        });
  $minProfile->munge();

  my $maxProfile = CBIL::TranscriptExpression::DataMunger::ProfileFromSeparateFiles->
    new({mainDirectory => $self->getMainDirectory,
         outputFile => $outputFileBase.$maxSuffix,
         makePercentiles => 0,
         isLogged => 0,
         fileSuffix => $fileSuffixBase.$maxSuffix,
         profileSetName => $profileSetName,
         samples => $samples,
         doNotLoad => 1
        });
  $maxProfile->munge();

  my $diffProfileSetName = $profileSetName.'-diff';
  my $diffProfile = CBIL::TranscriptExpression::DataMunger::ProfileDifferences->
    new({mainDirectory => $self->getMainDirectory,
         outputFile => $outputFileBase.$diffSuffix,
         isLogged => 0,
         minuendFile => $outputFileBase.$maxSuffix,
         subtrahendFile => $outputFileBase.$minSuffix,
         profileSetName => $diffProfileSetName
        });
  $diffProfile->munge();

  my $skipFishers = ($self->getSkipFishers()) ? 1 : undef;

  unless($skipFishers || scalar @$samples < 2 ) {
    my $isPairedEnd = $self->getIsPairedEnd();

    my $fishers = CBIL::TranscriptExpression::DataMunger::AllPairwiseRNASeqFishers->
      new({mainDirectory => $self->getMainDirectory,
           profileSetName => $profileSetName,
           conditions => $samples,
           isPairedEnd => $isPairedEnd
          });
    $fishers->munge();
  }
  else {
    my $dummy = CBIL::TranscriptExpression::DataMunger::RadAnalysis->
      new({mainDirectory => $self->getMainDirectory });
    $dummy->setConfigFile($CONFIG_FILE);
    $dummy->createConfigFile(1);
  }
}
1;
