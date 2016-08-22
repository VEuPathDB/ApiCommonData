package ApiCommonData::Load::BioperlFeatMapperSet;
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

use strict;
use ApiCommonData::Load::BioperlFeatMapper;

use XML::Simple;

sub new {
  my ($class, $mapXmlFile) = @_;
  $class = ref($class) || $class;

  my $self = {};
  bless($self, $class);

  $self->{mapXmlFile} = $mapXmlFile;
  $self->{mappersByName} = $self->_parseMapFile($mapXmlFile);

  return $self;
}

# return a list of all SO terms used in feature maps
sub getAllSoTerms {
  my ($self) = @_;
  my @terms;
  foreach my $mapper (values %{$self->{mappersByName}}) {
    push(@terms, $mapper->getSoTerm()) if ($mapper->getSoTerm());
  }
  return @terms
}

# Static method
# return the BioperlFeatMapper set in a hash keyed on feature name
sub _parseMapFile {
  my ($self, $mapXml) = @_;

  my $simple = XML::Simple->new();
  my $mapperSet = $simple->XMLin($mapXml, forcearray => 0)->{feature};

  my %featureMappersByName;

  while (my ($name, $feature) = each %{$mapperSet}) {
    $featureMappersByName{$name} = 
      ApiCommonData::Load::BioperlFeatMapper->new($name, $feature, $mapXml);
  }

  return \%featureMappersByName;
}

sub getMapperByFeatureName {
  my ($self, $featureName) = @_;

  if (!$self->{mappersByName}->{$featureName}) {
    die "Map XML file '$self->{mapXmlFile}' does not contain a <feature name=\"${featureName}\">, which is found in the input";
  }

  return $self->{mappersByName}->{$featureName};
}

1;
