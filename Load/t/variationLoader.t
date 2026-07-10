use strict;
use warnings;
use lib "$ENV{GUS_HOME}/lib/perl";
use Test::More;
use Test::Exception;
use ApiCommonData::Load::VariationLoader qw/
  variationFeatureColumns transcriptProductColumns variationEffectColumns
  parseHeader buildSourceId
/;

# Canonical column counts match the target tables (incl. added source_id,
# excl. dropped downstream_of_frameshift_strain_ids).
is(scalar @{variationFeatureColumns()},   33, 'VariationFeature has 33 columns');
is(scalar @{transcriptProductColumns()},  12, 'VariationTranscriptProduct has 12 columns');
is(scalar @{variationEffectColumns()},      8, 'VariationEffect has 8 columns');

is(variationFeatureColumns()->[0], 'source_id',          'source_id first');
is(variationFeatureColumns()->[1], 'sequence_source_id', 'sequence_source_id second');

# parseHeader strips a leading # and splits on tab.
is_deeply(parseHeader("#a\tb\tc"), [qw/a b c/], 'parseHeader strips leading #');
is_deeply(parseHeader("a\tb\tc"),  [qw/a b c/], 'parseHeader without #');

is(buildSourceId('LmjF.01', 233), 'Variant_LmjF.01_233', 'buildSourceId format');

use File::Temp qw/tempfile/;
use ApiCommonData::Load::VariationLoader qw/transformVariationFeature/;

{
  my $header = join("\t", qw/location seq_id reference_strain is_coding variant_type
    distinct_strain_count called_strain_count no_call_strain_count call_rate
    total_ploidy_count ref_allele_frequency het_strain_count
    snp_ref_allele snp_major_allele snp_major_allele_frequency snp_major_allele_strain_count
    snp_minor_allele snp_minor_allele_frequency snp_minor_allele_strain_count
    snp_major_genomic_hgvs snp_minor_genomic_hgvs
    indel_ref_allele indel_major_allele indel_major_allele_frequency indel_major_allele_strain_count
    indel_minor_allele indel_minor_allele_frequency indel_minor_allele_strain_count
    indel_major_genomic_hgvs indel_minor_genomic_hgvs indel_frame_effect/);
  # 233 SNV row with empty indel_* fields
  my @vals = (233, 'LmjF.01', 'lmajFriedlin', 0, 'SNV',
    5,4,0,'1.0000',9,'0.7778',0, 'C','G','0.2222',1,'','','', 'LmjF.01:g.233C>G','',
    '','','',  '','','',  '','','', '');
  my $row = join("\t", @vals);

  my ($inFh, $inFile)   = tempfile(UNLINK => 1);
  my ($outFh, $outFile) = tempfile(UNLINK => 1);
  print $inFh "$header\n$row\n"; close $inFh;
  open(my $rh, '<', $inFile) or die $!;

  my $n = transformVariationFeature($rh, $outFh, 42);
  close $outFh; close $rh;
  is($n, 1, 'one data row transformed');

  open(my $oh, '<', $outFile) or die $!;
  my $out = <$oh>; chomp $out; close $oh;
  my @f = split /\t/, $out, -1;
  is(scalar @f, 33, 'output has 33 fields');
  is($f[0], 'Variant_LmjF.01_233', 'source_id prepended');
  is($f[1], 'LmjF.01', 'sequence_source_id = seq_id');
  is($f[2], 233, 'location third');
  is($f[-1], 42, 'external_database_release_id appended');
}

dies_ok {
  my ($rh, $f) = tempfile(UNLINK => 1);
  print $rh "location\tseq_id\n1\t2\t3\n"; close $rh;
  open(my $r, '<', $f); my $junk;
  open(my $w, '>', \$junk);
  ApiCommonData::Load::VariationLoader::transformVariationFeature($r, $w, 1);
} 'dies on wrong field count';

done_testing;
