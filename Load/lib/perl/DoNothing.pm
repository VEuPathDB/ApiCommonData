package ApiCommonData::Load::DoNothing;
use base qw(CBIL::StudyAssayResults::DataMunger::Loadable);

sub munge {
  my ($self) = @_;

  my $configFilePath = $self->getConfigFilePath();

  if(-e $configFilePath) {
    open(CONFIG, ">> $configFilePath") or die "Cannot open config file for writing: $!";
  }
  else {
    open(CONFIG, "> $configFilePath") or die "Cannot open config file for writing: $!";
    $self->printConfigHeader(\*CONFIG);
  }

  close CONFIG;
}



1;
