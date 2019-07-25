package ApiCommonData::Load::MetaboliteProfiles;
#use base qw(CBIL::TranscriptExpression::DataMunger::Profiles);
use base qw(CBIL::TranscriptExpression::DataMunger::NoSampleConfigurationProfiles);

use strict;


sub getProtocolName {
  return "compoundMassSpec";
}

sub getTechnologyType {
  return "compound_MassSpec";
}

sub getSourceIdType{
  return "compound_MassSpec"
}


sub new {
	my ($class, $args) = @_;
	my $requiredParams = [];
	my $self = $class->SUPER::new($args, $requiredParams);
	return $self;
}


1;
