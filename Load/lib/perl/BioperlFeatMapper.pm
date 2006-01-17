package ApiComplexa::DataLoad::BioperlFeatMapper;

use strict 'vars';
use CBIL::Util::Disp;
######CPAN Perl Libraries

sub new{
  my ($class, $bioperlFeatureName, $featureMapHashFromXmlSimple, $mapXmlFile) = @_;
  my $self = $featureMapHashFromXmlSimple;
  $self->{'bioperlFeatureName'} = $bioperlFeatureName;
  $self->{'mapXmlFile'} = $mapXmlFile;
  bless($self, $class);
  return $self;
}

sub getBioperlFeatureName {
  my ($self) = @_;
  return $self->{'bioperlFeatureName'};
}

sub getGusColumn{
  my ($self, $tag) = @_;
  
  $self->_checkTagExists($tag);
  my $gusColumnName = $self->{'qualifier'}->{$tag}->{'column'};
  if ($gusColumnName eq '') {return $tag;}
  else {return $gusColumnName;}
}

sub getGusTable {
  my ($self) = @_;

  return $self->{'table'}; 
}

sub getGusObjectName {
  my ($self) = @_;

  my $objectName = $self->{'table'};

#  $objectName =~ s/\./::/;

  return "GUS::Model::$objectName";
}

sub getSoTerm {
  my ($self) = @_;

  return $self->{'so'};
}

sub isSpecialCase {
  my ($self, $tag) = @_;

  $self->_checkTagExists($tag);
  return $self->{'qualifier'}->{$tag}->{'specialcase'}; 
}

sub isLost {
  my ($self, $tag) = @_;

  $self->_checkTagExists($tag);
  return $self->{'qualifier'}->{$tag}->{'lost'}; 
}

sub _checkTagExists {
  my ($self, $tag) = @_;
  
  if (!$self->{'qualifier'}->{$tag}) {
    die "In feature map XML file '$self->{mapXmlFile}' <feature name=\"$self->{bioperlFeatureName}\"> does not have a <qualifier> for '$tag', which is found in the input";
  }
}


1;

