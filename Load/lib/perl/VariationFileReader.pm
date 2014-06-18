package ApiCommonData::Load::VariationFileReader;
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


