use strict;
use warnings;

use lib "$ENV{GUS_HOME}/lib/perl";

use Test::More;
use YAML;
use List::Util qw/uniq/;

use File::Temp qw/tempdir/;
use File::Slurp qw/write_file/;


my $dir = tempdir(CLEANUP => 1);
my $study = "datasetName";

write_file("$dir/$study.16s.lineage_abundance.tsv", <<"EOF");
	s1	s2
k;p;c;o;f;g;s	11111.0	12111.0
different_kingdom	13111.0	14111.0
yet_different_kingdom	1111.0	
EOF

write_file("$dir/$study.wgs.lineage_abundance.tsv", <<"EOF");
	s1	s2
k__K|p__P|c__C|o__O|f__F|g__G|s__S	15111.0	16111.0
k__DifferentKingdom	0.1	0.2
k__yet_different_kingdom	1111.0	0
EOF

write_file("$dir/$study.level4ec.tsv", <<"EOF");
	s1	s2
UNGROUPED	0.1	0.1
1.1.1.103: L-threonine 3-dehydrogenase|g__Escherichia.s__Escherichia_coli	17111.0	18111.0
1.1.1.103: L-threonine 3-dehydrogenase|unclassified	19111.0	20111.0
1.1.1.103: L-threonine 3-dehydrogenase	21111.0	22111.0
7.2.1.1: NO_NAME	23111.0	24111.0
8.2.1.1: NO_NAME	23111.0	0.0
EOF

write_file("$dir/$study.pathway_abundance.tsv", <<"EOF");
	s1	s2
ANAEROFRUCAT-PWY: homolactic fermentation	25111.0	26111.0
ANAEROFRUCAT-PWY: homolactic fermentation|g__Escherichia.s__Escherichia_coli	27111.0	28111.0
ANAEROFRUCAT-PWY: homolactic fermentation|unclassified	29111.0	30111.0
BNAEROFRUCAT-PWY: homolactic fermentation|unclassified	29111.0	0.0
EOF

write_file("$dir/$study.pathway_coverage.tsv", <<"EOF");
	s1	s2
ANAEROFRUCAT-PWY: homolactic fermentation	0.31111	0.32111
ANAEROFRUCAT-PWY: homolactic fermentation|g__Escherichia.s__Escherichia_coli	0.33111	0.34111
ANAEROFRUCAT-PWY: homolactic fermentation|unclassified	0.35111	0.36111
BNAEROFRUCAT-PWY: homolactic fermentation|unclassified	0.35111	0.0
EOF

my $getAddMoreDataStr = 'require ApiCommonData::Load::MBioResultsDir; ApiCommonData::Load::MBioResultsDir->new($dir, {ampliconTaxa => ".16s.lineage_abundance.tsv", wgsTaxa => ".wgs.lineage_abundance.tsv", level4ECs => ".level4ec.tsv", pathwayAbundances => ".pathway_abundance.tsv", pathwayCoverages => ".pathway_coverage.tsv"})->toGetAddMoreData';

my $getAddMoreData = eval $getAddMoreDataStr;
diag $@ if $@;
ok $getAddMoreData;

my $addMoreData = $getAddMoreData->({dataset => [$study]});
my $result = $addMoreData->({name => ["s1"]});
diag explain $result;

ok($result->{$_}, "Result has key: $_") for qw /abundance_amplicon_c abundance_amplicon_f abundance_amplicon_g abundance_amplicon_k abundance_amplicon_o abundance_amplicon_p abundance_amplicon_s abundance_wgs_c abundance_wgs_f abundance_wgs_g abundance_wgs_k abundance_wgs_o abundance_wgs_p abundance_wgs_s function_level4EC function_level4EC_species pathway_abundance pathway_abundance_species pathway_coverage pathway_coverage_species/;

done_testing;
