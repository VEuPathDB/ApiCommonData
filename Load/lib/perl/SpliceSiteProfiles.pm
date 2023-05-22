package ApiCommonData::Load::SpliceSiteProfiles;
use base qw(CBIL::StudyAssayResults::DataMunger::Loadable);

use strict;

# this modules purpose is to write a config file for insertstudyresults.  
# the data files are written in another workflow step

# important to give this a distinct name from the standard one
my $CONFIG_FILE_NAME = "insert_study_results_ss_config.txt";

sub getSampleName {$_[0]->{sampleName}}

sub getInputs {$_[0]->{inputs}}
sub getSuffix {$_[0]->{suffix}}

sub new {
  my ($class, $args) = @_;

  my $requiredParams = [
                          'sampleName',
                          'inputs',
                          'suffix'
                         ];
  my $self = $class->SUPER::new($args, $requiredParams);


  my $cleanSampleName = $self->getSampleName();
  $cleanSampleName =~ s/\s/_/g; 
  $cleanSampleName=~ s/[\(\)]//g;

  my $outputFile = $cleanSampleName . $self->getSuffix();
  $self->setOutputFile($outputFile);

  $self->setConfigFileBaseName($CONFIG_FILE_NAME);

  $self->setProtocolName("Splice Site Counts");
  $self->setDisplaySuffix(" [counts]");

  $self->setSourceIdType('gene');

  my $sampleName = $self->getSampleName();
  my $inputs = $self->getInputs();

  $self->setNames([$sampleName]);
  $self->setFileNames([$outputFile]);

  $self->setInputProtocolAppNodesHash({$sampleName => $inputs});


  return $self;
}


sub munge {
  my ($self) = @_;

  $self->createConfigFile();
}

1;
