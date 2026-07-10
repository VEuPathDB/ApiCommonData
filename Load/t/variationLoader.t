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

use ApiCommonData::Load::VariationLoader qw/transformTranscriptProduct/;

{
  my %map = ('LmjF.01.0010:mRNA' => 9000001);
  my $header = "#" . join("\t", qw/seq_id location transcript_id pos_in_cds
    pos_in_protein codon pos_in_codon count product matches_ref_codon
    matches_ref_product downstream_of_frameshift_strain_ids hgvs_p/);
  my $row = join("\t", 'LmjF.01', 3745, 'LmjF.01.0010:mRNA', 958, 320, 'GAC',
    1, 3, 'D', 1, 1, '{1,3,4}', 'p.Asp320=');

  my ($inFh, $inFile)   = tempfile(UNLINK => 1);
  my ($outFh, $outFile) = tempfile(UNLINK => 1);
  print $inFh "$header\n$row\n"; close $inFh;
  open(my $rh, '<', $inFile) or die $!;

  my $n = transformTranscriptProduct($rh, $outFh, \%map);
  close $outFh; close $rh;
  is($n, 1, 'one row');

  open(my $oh, '<', $outFile); my $out = <$oh>; chomp $out; close $oh;
  my @f = split /\t/, $out, -1;
  is(scalar @f, 12, 'output has 12 fields (dropped column)');
  is($f[2], 9000001, 'transcript_id resolved to na_feature_id');
  is($f[7], 3, 'count value now in strain_count position');
  is($f[-1], 'p.Asp320=', 'hgvs_p last; frameshift ids column dropped');
}

dies_ok {
  my %map = ('LmjF.01.0010:mRNA' => 9000001);
  my $header = "#seq_id\tlocation\ttranscript_id\tpos_in_cds\tpos_in_protein\tcodon\tpos_in_codon\tcount\tproduct\tmatches_ref_codon\tmatches_ref_product\tdownstream_of_frameshift_strain_ids\thgvs_p";
  my ($rh,$f)=tempfile(UNLINK=>1);
  print $rh "$header\nLmjF.01\t3745\tUNKNOWN:mRNA\t1\t1\tGAC\t1\t1\tD\t1\t1\t\tp.x\n"; close $rh;
  open(my $r,'<',$f); my $j; open(my $w,'>',\$j);
  transformTranscriptProduct($r,$w,\%map);
} 'dies on unresolvable transcript_id';

dies_ok {
  my %map;
  my $header = "#seq_id\tlocation\ttranscript_id\tpos_in_cds\tpos_in_protein\tcodon\tpos_in_codon\tcount\tproduct\tmatches_ref_codon\tmatches_ref_product\tdownstream_of_frameshift_strain_ids\thgvs_p";
  my ($rh,$f)=tempfile(UNLINK=>1);
  print $rh "$header\nLmjF.01\t3745\t\t1\t1\tGAC\t1\t1\tD\t1\t1\t\tp.x\n"; close $rh;
  open(my $r,'<',$f); my $j; open(my $w,'>',\$j);
  transformTranscriptProduct($r,$w,\%map);
} 'dies on empty transcript_id (NOT NULL column)';

use ApiCommonData::Load::VariationLoader qw/transformVariationEffect/;

{
  my %map = ('LmjF.01.0010:mRNA' => 9000001);
  my $header = join("\t", qw/location seq_id allele transcript_id impact effect hgvs_c source/);
  my $coding     = join("\t", 3745, 'LmjF.01', 'A', 'LmjF.01.0010:mRNA', 'MODERATE', 'missense_variant', 'c.958G>A', 'snpeff');
  my $intergenic = join("\t", 233,  'LmjF.01', 'G', '',                  'MODIFIER', 'intergenic_region', 'n.233C>G', 'snpeff');

  my ($inFh, $inFile)   = tempfile(UNLINK => 1);
  my ($outFh, $outFile) = tempfile(UNLINK => 1);
  print $inFh "$header\n$coding\n$intergenic\n"; close $inFh;
  open(my $rh, '<', $inFile) or die $!;

  my $n = transformVariationEffect($rh, $outFh, \%map);
  close $outFh; close $rh;
  is($n, 2, 'two rows');

  open(my $oh, '<', $outFile); my @lines = <$oh>; close $oh;
  my @c = split /\t/, $lines[0], -1;
  is(scalar @c, 8, 'output has 8 fields');
  is($c[0], 'LmjF.01', 'sequence_source_id first');
  is($c[1], 3745, 'location second');
  is($c[3], 9000001, 'coding row resolved na_feature_id');
  my @i = split /\t/, $lines[1], -1;
  is($i[3], '', 'intergenic row has empty na_feature_id (-> NULL)');
}

dies_ok {
  my %map;
  my $header = "location\tseq_id\tallele\ttranscript_id\timpact\teffect\thgvs_c\tsource";
  my ($rh,$f)=tempfile(UNLINK=>1);
  print $rh "$header\n1\tLmjF.01\tA\tUNKNOWN:mRNA\tHIGH\tx\tc.1A>T\tsnpeff\n"; close $rh;
  open(my $r,'<',$f); my $j; open(my $w,'>',\$j);
  transformVariationEffect($r,$w,\%map);
} 'dies on non-empty unresolvable transcript_id';

done_testing;
