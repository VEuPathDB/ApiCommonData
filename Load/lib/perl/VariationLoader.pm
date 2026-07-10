package ApiCommonData::Load::VariationLoader;

use strict;
use warnings;

use Exporter 'import';
our @EXPORT_OK = qw/
  variationFeatureColumns transcriptProductColumns variationEffectColumns
  parseHeader buildSourceId
  transformVariationFeature transformTranscriptProduct transformVariationEffect
/;

# Canonical output column order. The transforms below emit values in exactly
# this order; the plugin uses these same lists to build each \copy field list.
# Keep the two in lockstep — the unit tests assert the counts match.

sub variationFeatureColumns {
  return [ qw/
    source_id sequence_source_id location reference_strain is_coding variant_type
    distinct_strain_count called_strain_count no_call_strain_count call_rate
    total_ploidy_count ref_allele_frequency het_strain_count
    snp_ref_allele snp_major_allele snp_major_allele_frequency snp_major_allele_strain_count
    snp_minor_allele snp_minor_allele_frequency snp_minor_allele_strain_count
    snp_major_genomic_hgvs snp_minor_genomic_hgvs
    indel_ref_allele indel_major_allele indel_major_allele_frequency indel_major_allele_strain_count
    indel_minor_allele indel_minor_allele_frequency indel_minor_allele_strain_count
    indel_major_genomic_hgvs indel_minor_genomic_hgvs indel_frame_effect
    external_database_release_id
  / ];
}

sub transcriptProductColumns {
  return [ qw/
    sequence_source_id location na_feature_id pos_in_cds pos_in_protein codon
    pos_in_codon strain_count product matches_ref_codon matches_ref_product hgvs_p
  / ];
}

sub variationEffectColumns {
  return [ qw/
    sequence_source_id location allele na_feature_id impact effect hgvs_c source
  / ];
}

sub parseHeader {
  my ($line) = @_;
  chomp $line;
  $line =~ s/^#//;
  return [ split /\t/, $line, -1 ];
}

sub buildSourceId {
  my ($seq, $loc) = @_;
  return "Variant_${seq}_${loc}";
}

sub transformVariationFeature {
  my ($inFh, $outFh, $extDbRlsId) = @_;
  my $header = <$inFh>;
  die "variationFeature.dat: empty file\n" unless defined $header;
  my $cols = parseHeader($header);
  die "variationFeature.dat: expected 31 columns, got " . scalar(@$cols) . "\n"
    unless @$cols == 31;
  die "variationFeature.dat: unexpected header (want location, seq_id first)\n"
    unless $cols->[0] eq 'location' && $cols->[1] eq 'seq_id';

  my $n = 0;
  while (my $line = <$inFh>) {
    chomp $line;
    my @f = split /\t/, $line, -1;
    die "variationFeature.dat line $.: expected 31 fields, got " . scalar(@f) . "\n"
      unless @f == 31;
    my ($loc, $seq) = @f[0, 1];
    print $outFh join("\t", buildSourceId($seq, $loc), $seq, $loc, @f[2..30], $extDbRlsId), "\n";
    $n++;
  }
  return $n;
}

1;
