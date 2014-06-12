package ApiCommonData::Load::SnpUtils;
use Exporter;
@ISA = qw(Exporter);
@EXPORT = qw(sequenceIndex locationIndex strainIndex variationFileColumnNames isSameSNP allelePercentIndex);

use strict;

sub sequenceIndex { return 0 }
sub locationIndex { return 1 }
sub strainIndex { return 2 }
sub allelePercentIndex { return 5 }

sub variationFileColumnNames {
  my @columnNames = 
      ('sequence_source_id',
       'location',
       'strain',
       'base',
       'coverage',
       'percent',
       'quality',
       'pvalue',
       'external_database_release_id',
       'matches_reference',
       'product',
       'position_in_cds',
       'position_in_protein',
       'na_sequence_id',
       'ref_na_sequence_id',
       'snp_external_database_release_id'
      );

  return \@columnNames;
}

sub isSameSNP {
  my ($a, $b) = @_;

  my $sequenceIndex = &sequenceIndex();
  my $locationIndex = &locationIndex();

    my $sequenceId = $a->[$sequenceIndex];
    my $peekSequenceId = $b->[$sequenceIndex];

    my $location = $a->[$locationIndex];
    my $peekLocation = $b->[$locationIndex];
  
  return $sequenceId eq $peekSequenceId && $peekLocation == $location;

}
