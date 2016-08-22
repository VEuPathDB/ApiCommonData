package ApiCommonData::Load::BioperlFeatMapper;
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

