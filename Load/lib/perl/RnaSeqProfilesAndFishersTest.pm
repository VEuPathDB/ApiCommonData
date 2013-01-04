package ApiCommonData::Load::RnaSeqProfilesAndFishersTest;
use base qw(CBIL::TranscriptExpression::DataMunger);

use strict;

use CBIL::TranscriptExpression::Error;
use CBIL::TranscriptExpression::DataMunger::ProfileFromSeparateFiles;
use CBIL::TranscriptExpression::DataMunger::ProfileDifferences;
use CBIL::TranscriptExpression::DataMunger::AllPairwiseRNASeqFishers;

use Data::Dumper;

use strict;

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
  my $self = $class->SUPER::new($args, $requiredParams);

  if(my $outputPrefix = $self->getOutputFile()) {
    $outputFileBase = $outputPrefix . $outputFileBase;
  }

  if(scalar @{$args->{samples}} > 1 ) {
    my $isPairedEnd = $self->getIsPairedEnd();
    unless($isPairedEnd eq 'yes' || $isPairedEnd eq 'no') {
      CBIL::TranscriptExpression::Error->new("isPairedEnd param must equal [yes] or [no]")->throw();
    }
  }


  return $self;
}

sub munge {
  my ($self) = @_;
  my $profileSetName = $self->getProfileSetName();
  my $samples = $self->getSamples();

  my $minProfile = CBIL::TranscriptExpression::DataMunger::ProfileFromSeparateFiles->
    new({mainDirectory => $self->getMainDirectory,
         outputFile => $outputFileBase.$minSuffix,
         makePercentiles => 1,
         fileSuffix => $fileSuffixBase.$minSuffix,
         profileSetName => $profileSetName,
         samples => $samples
        });
  $minProfile->munge();

  my $maxProfile = CBIL::TranscriptExpression::DataMunger::ProfileFromSeparateFiles->
    new({mainDirectory => $self->getMainDirectory,
         outputFile => $outputFileBase.$maxSuffix,
         makePercentiles => 0,
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
         minuendFile => $outputFileBase.$maxSuffix,
         subtrahendFile => $outputFileBase.$minSuffix,
         profileSetName => $diffProfileSetName
        });
  $diffProfile->munge();

  if(scalar @$samples > 1) {
    my $isPairedEnd = $self->getIsPairedEnd();

    my $fishers = CBIL::TranscriptExpression::DataMunger::AllPairwiseRNASeqFishers->
      new({mainDirectory => $self->getMainDirectory,
           profileSetName => $profileSetName,
           conditions => $samples,
           isPairedEnd => $isPairedEnd
          });
    $fishers->munge();
  }
}
1;
