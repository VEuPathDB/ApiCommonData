package ApiCommonData::Load::VariationFileReader;
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
  # GUS4_STATUS | dots.gene                      | manual | absent
#^^^^^^^^^^^^^^^^^^^^^^^^^ End GUS4_STATUS ^^^^^^^^^^^^^^^^^^^^
use base qw(ApiCommonData::Load::FileReader);

use strict;

use ApiCommonData::Load::SnpUtils  qw(variationFileColumnNames isSameSNP allelePercentIndex );

# Set the Dictionary after making the Reader
sub new {
  my $class = shift;

  my $self = $class->SUPER::new(@_);

  my $columnNames = &variationFileColumnNames();
  $self->setDictionaryNames($columnNames);

  return $self;
}

# better name for use w/ Variations/SNPs
sub nextSNP {
  my ($self) = @_;
  return $self->readNextGroupOfLines();
}

# @OVERRIDE
sub isSameGroup {
  my ($self, $a, $b) = @_;

  return &isSameSNP($a, $b);
}

# @OVERRIDE
sub skipLine {
  my ($self, $line, $a, $fh) = @_;

  my $filters = $self->getFilters();
  my $allelePercentCutoff = $filters->[0];

  my $i = &allelePercentIndex();

  if($a->[$i] && $a->[$i]  < $allelePercentCutoff) {
    return 1;
  }
  return 0;
}


1;


