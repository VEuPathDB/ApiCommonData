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

sub transformTranscriptProduct {
  my ($inFh, $outFh, $map) = @_;
  my $header = <$inFh>;
  die "transcript_product.dat: empty file\n" unless defined $header;
  my $cols = parseHeader($header);
  die "transcript_product.dat: expected 13 columns, got " . scalar(@$cols) . "\n"
    unless @$cols == 13;
  die "transcript_product.dat: unexpected header (want seq_id first)\n"
    unless $cols->[0] eq 'seq_id';

  my $n = 0;
  while (my $line = <$inFh>) {
    chomp $line;
    my @f = split /\t/, $line, -1;
    die "transcript_product.dat line $.: expected 13 fields, got " . scalar(@f) . "\n"
      unless @f == 13;
    my $tid = $f[2];
    die "transcript_product.dat line $.: empty transcript_id (na_feature_id is NOT NULL)\n"
      if $tid eq '';
    my $nfid = $map->{$tid};
    die "transcript_product.dat line $.: transcript_id '$tid' not found for this organism\n"
      unless defined $nfid;
    # out: seq_id, location, na_feature_id, cols 4..11 (pos_in_cds..matches_ref_product), hgvs_p
    # drop col index 11 (downstream_of_frameshift_strain_ids); hgvs_p is index 12
    print $outFh join("\t", @f[0,1], $nfid, @f[3..10], $f[12]), "\n";
    $n++;
  }
  return $n;
}

sub transformVariationEffect {
  my ($inFh, $outFh, $map) = @_;
  my $header = <$inFh>;
  die "snpeff.dat: empty file\n" unless defined $header;
  my $cols = parseHeader($header);
  die "snpeff.dat: expected 8 columns, got " . scalar(@$cols) . "\n"
    unless @$cols == 8;
  die "snpeff.dat: unexpected header (want location first)\n"
    unless $cols->[0] eq 'location';

  my $n = 0;
  while (my $line = <$inFh>) {
    chomp $line;
    my @f = split /\t/, $line, -1;
    die "snpeff.dat line $.: expected 8 fields, got " . scalar(@f) . "\n"
      unless @f == 8;
    my ($loc, $seq, $allele, $tid, $impact, $effect, $hgvsc, $source) = @f;
    my $nfid = '';                       # empty -> NULL for intergenic
    if ($tid ne '') {
      $nfid = $map->{$tid};
      die "snpeff.dat line $.: transcript_id '$tid' not found for this organism\n"
        unless defined $nfid;
    }
    print $outFh join("\t", $seq, $loc, $allele, $nfid, $impact, $effect, $hgvsc, $source), "\n";
    $n++;
  }
  return $n;
}

1;
