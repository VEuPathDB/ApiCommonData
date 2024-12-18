package ApiCommonData::Load::RnaSeqCounts;
use base qw(CBIL::StudyAssayResults::DataMunger::ProfileFromSeparateFiles);


use strict;
use Data::Dumper;

# override from superclass since config file will not be in the same location as the input
sub getConfigFilePath {
    return $_[0]->{_config_file_path};
}

sub setConfigFilePath {
    my ($self, $mainDir) =  @_;
    my $configFileBaseName = $self->getConfigFileBaseName();
    my $configFilePath = "$mainDir/$configFileBaseName";
    $self->{_config_file_path} = $configFilePath;
}

### Use the new and munge methods from the superclass!

1;
