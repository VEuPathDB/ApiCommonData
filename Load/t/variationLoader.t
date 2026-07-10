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

done_testing;
