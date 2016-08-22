package ApiCommonData::Load::BioperlFeatureMapper;
#vvvvvvvvvvvvvvvvvvvvvvvvv GUS4_STATUS vvvvvvvvvvvvvvvvvvvvvvvvv
  # GUS4_STATUS | SRes.OntologyTerm              | auto   | absent
  # GUS4_STATUS | SRes.SequenceOntology          | auto   | absent
  # GUS4_STATUS | Study.OntologyEntry            | auto   | absent
  # GUS4_STATUS | SRes.GOTerm                    | auto   | absent
  # GUS4_STATUS | Dots.RNAFeatureExon            | auto   | absent
  # GUS4_STATUS | RAD.SageTag                    | auto   | absent
  # GUS4_STATUS | RAD.Analysis                   | auto   | absent
  # GUS4_STATUS | ApiDB.Profile                  | auto   | absent
  # GUS4_STATUS | Study.Study                    | auto   | absent
  # GUS4_STATUS | Dots.Isolate                   | auto   | absent
  # GUS4_STATUS | DeprecatedTables               | auto   | absent
  # GUS4_STATUS | Pathway                        | auto   | absent
  # GUS4_STATUS | DoTS.SequenceVariation         | auto   | absent
  # GUS4_STATUS | RNASeq Junctions               | auto   | absent
  # GUS4_STATUS | Simple Rename                  | auto   | absent
  # GUS4_STATUS | ApiDB Tuning Gene              | auto   | absent
  # GUS4_STATUS | Rethink                        | auto   | absent
  # GUS4_STATUS | dots.gene                      | manual | unreviewed
die 'This file has broken or unreviewed GUS4_STATUS rules.  Please remove this line when all are fixed or absent';
#^^^^^^^^^^^^^^^^^^^^^^^^^ End GUS4_STATUS ^^^^^^^^^^^^^^^^^^^^

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

