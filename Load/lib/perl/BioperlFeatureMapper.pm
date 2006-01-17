package ApiComplexa::DataLoad::BioperlFeatureMapper;

############################################
# Take sub-part of an object returned from FeatureMapper
# Associated with an input feature, and get GUS table
# and columns for that feature.
#
# E.g. Get Gus mappings for GenBank C_region feature
#
############################################
                                                                                                                             
use strict 'vars';

######CPAN Perl Libraries
use XML::Simple;

sub new{
  my $class = shift;
  my $self = {};
  bless($self, $class);
return $self;
}


# ----------------------------------------------------------
# Get GUS field for a tag name
# ----------------------------------------------------------

sub getGusColumn{
  my ($self, $featureMap, $tag) = @_;
    my $gusColumnName = $featureMap->{'qualifier'}->{$tag}->{'column'};
    if ($gusColumnName eq '') {return $tag;}
    else {return $gusColumnName;}
}

# ----------------------------------------------------------
# Gus Table Name 
# ----------------------------------------------------------

sub getGusTable {
  my ($self, $featureMap) = @_;
  my $myGusTable = $featureMap->{'table'}; 
  return $myGusTable;
}

# ----------------------------------------------------------
# SO: ID 
# ----------------------------------------------------------

sub getSOFeature {
  my ($self, $featureMap) = @_;
  my $mySOFeature = $featureMap->{'so'}; 
  return $mySOFeature;
}


# ----------------------------------------------------------
# Test for special cases
# ----------------------------------------------------------

sub isSpecialCase {
  my ($self, $featureMap, $tag) = @_;
  my $specialcase = $featureMap->{'qualifier'}->{$tag}->{'specialcase'}; 
  return $specialcase;
}

# ----------------------------------------------------------
# Test for special cases
# ----------------------------------------------------------

sub isLost {
  my ($self, $featureMap, $tag) = @_;
  my $islost = $featureMap->{'qualifier'}->{$tag}->{'lost'}; 
  return $islost;
}

1;

