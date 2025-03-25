package ApiCommonData::Load::SpliceSiteAnalysis;
use base qw(CBIL::StudyAssayResults::DataMunger);

use strict;

use CBIL::StudyAssayResults::Error;
use CBIL::StudyAssayResults::DataMunger::ProfileFromSeparateFiles;

use ApiCommonData::Load::SpliceSiteFeatures;
use ApiCommonData::Load::SpliceSiteProfiles;

sub getProfileSetName          { $_[0]->{profileSetName} }
sub getSamples                 { $_[0]->{samples} }

sub getSpliceSiteType                 { $_[0]->{spliceSiteType} }

sub new {
  my ($class, $args) = @_;
    my $requiredParams = [
                          'samples',
                          'profileSetName',
      'spliceSiteType'
                         ];
  my $self = $class->SUPER::new($args, $requiredParams);

  my $sst = $self->getSpliceSiteType();

  unless($sst eq 'Poly A' || $sst eq 'Splice Site') {
    CBIL::StudyAssayResults::Error->new("spliceSiteType must be [Poly A] or [Splice Site]")->throw();
  }

  return $self;
}

sub munge {
  my ($self) = @_;

  my $profileSetName = $self->getProfileSetName();
  my $samplesHash = $self->groupListHashRef($self->getSamples());

  foreach my $sampleName (keys %$samplesHash) {
    if(scalar @{$samplesHash->{$sampleName}} > 1) {
      CBIL::StudyAssayResults::Error->new("Multiple Inputs found for splice site feature $sampleName")->throw();
    }

    my $ssFeatures = ApiCommonData::Load::SpliceSiteFeatures->new({sampleName => $sampleName,
                                                                   inputs => $samplesHash->{$sampleName},
                                                                   mainDirectory => $self->getMainDirectory,
                                                                   profileSetName => $profileSetName,
                                                                   samplesHash => $samplesHash,
                                                                   spliceSiteType => $self->getSpliceSiteType(),
                                                                   suffix => '_features.txt'});

    $ssFeatures->setTechnologyType($self->getTechnologyType());
    $ssFeatures->munge();
  }


  # this bit makes the config file for the Study Loader.  (the actual profile files are made by a separate script)
  #     the table which associates transcripts to ssFeatures has not been populated at the time of this script running
  foreach my $sampleName (keys %$samplesHash) {
    my $ssProfiles = ApiCommonData::Load::SpliceSiteProfiles->new({sampleName => $sampleName,
                                                                   inputs => $samplesHash->{$sampleName},
                                                                   mainDirectory => $self->getMainDirectory,
                                                                   profileSetName => $profileSetName,
                                                                   samplesHash => $samplesHash,
                                                                   suffix => '_profiles.txt'});

    $ssProfiles->setTechnologyType($self->getTechnologyType());
    $ssProfiles->munge();
  }
  
}


1;
