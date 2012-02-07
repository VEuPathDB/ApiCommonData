package ApiCommonData::Load::RnaSeqProfilesAndFishersTest;
use base qw(CBIL::TranscriptExpression::DataMunger);

use strict;

use CBIL::TranscriptExpression::Error;
use CBIL::TranscriptExpression::DataMunger::ProfileFromSeparateFiles;
use CBIL::TranscriptExpression::DataMunger::ProfileDifferences;
use CBIL::TranscriptExpression::DataMunger::AllPairwiseRNASeqFishers;

use Data::Dumper;

my $outputFileBase = "profiles";
my $fileSuffixBase = "intensity";
my $minSuffix = ".min";
my $maxSuffix = ".max";
my $diffSuffix = ".diff";

#-------------------------------------------------------------------------------

 sub getProfileSetName          { $_[0]->{profileSetName} }
 sub getSamples                 { $_[0]->{samples} }
 sub getIsPairedEnd             { $_[0]->{isPairedEnd} }

#-------------------------------------------------------------------------------
sub new {
  my ($class, $args) = @_;
    my $requiredParams = ['profileSetName',
                          'samples',
                         ];
  print Dumper $args;
  #get samples and cout, if more then one, require isPairedEnd
  my $self = $class->SUPER::new($args, $requiredParams);
  return $self;
}

sub munge {
  my ($self) = @_;
  my $profileSetName = $self->getProfileSetName();
  my $samples = $self->getSamples();
  my $minProfileHash = {mainDirectory => $self->getMainDirectory,
                        outputFile => $outputFileBase.$minSuffix,
                        makePercentiles => 1,
                        fileSuffix => $fileSuffixBasemin.$minSuffix,
                        profileSetName => $profileSetName,
                        samples => $samples
                       };
  my $minProfile = CBIL::TranscriptExpression::DataMunger::ProfileFromSeparateFiles->new($minProfileHash);
  $minProfile->munge();
  my $maxProfileHash ={mainDirectory => $self->getMainDirectory,
                       outputFile => $outputFileBase.$maxSuffix,
                       makePercentiles => 0,
                       fileSuffix => $fileSuffixBase.$maxSuffix,
                       profileSetName => $profileSetName,
                       samples => $samples,
                       doNotLoad => 1
                      };
  my $maxProfile = CBIL::TranscriptExpression::DataMunger::ProfileFromSeparateFiles->new($maxProfileHash);
  $maxProfile->munge();
  my $diffProfileSetName = $profileSetName.'-diff';
  my $diffProfileHash ={mainDirectory => $self->getMainDirectory,
                        outputFile => $outputFileBase.$diffSuffix,
                        minuendFile => $outputFileBase.$maxSuffix,
                        subtrahendFile => $outputFileBase.$minSuffix,
                        profileSetName => $diffProfileSetName
                       };

  my $diffProfile = CBIL::TranscriptExpression::DataMunger::ProfileDifferences->new($diffProfileHash);
  $diffProfile->munge();
  my $isPairedEnd = $self->getIsPairedEnd();
  unless (scalar @$samples == 1 ) {
    my $fishersHash = {mainDirectory => $self->getMainDirectory,
                       profileSetName => $profileSetName,
                       conditions => $samples,
                       isPairedEnd => $isPairedEnd
                      };
    my $fishers = CBIL::TranscriptExpression::DataMunger::AllPairwiseRNASeqFishers->new($fishersHash);
$fishers->munge();

  }
}
1;
