package ApiCommonData::Load::BioperlMapParser;
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

use strict 'vars'; # TODO-AJM: Why just 'vars'?? Do we have
                   # strict-breaking 'subs' or 'refs' somewhere?

######CPAN Perl Libraries
use XML::Simple;

#############################################################
# Main Routine
# read xml file of BioPerl object to GUS object mapping rule
# and create object for plugin(s) to use to make GUS objects
##############################################################
sub new {
  my $class = shift;
  $class = ref($class) || $class;

  my $self = {};
  bless($self, $class);

  return $self;
}

sub parseMap {
  my ($self, $mapXml) = @_;

  my $simple = XML::Simple->new();
  my $mapping = $simple->XMLin($mapXml, forcearray => 1);

  my $mapper = $mapping->{'feature'};
  return $mapper;
}

1;
