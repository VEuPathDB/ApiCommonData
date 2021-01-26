use strict;
use warnings;

use lib "$ENV{GUS_HOME}/lib/perl";

use ApiCommonData::Load::MBioResults;
use ApiCommonData::Load::MBioResultsTable;
use Test::More;
use Test::Exception;
use YAML;
use List::Util qw/uniq/;

my $t = bless {}, 'ApiCommonData::Load::MBioResults';

my %args;

dies_ok {$t->readData(\%args) } "Required: dataset name";
$args{datasetName} = "Test dataset";


dies_ok {$t->readData(\%args) } "Required: some files";


dies_ok {$t->readData({%args, ampliconTaxaPath => "/bad/path"}) } "Required: file args are openable";
dies_ok {$t->readData({%args, ampliconTaxaPath => \""}) } "Required: file args have stuff in them";

my $ampliconTaxaPath=<<"EOF";
	s1	s2
k;p;c;o;f;g;s	11111.0	12111.0
different_kingdom	13111.0	14111.0
yet_different_kingdom	1111.0	
EOF
my $badAmpliconTaxaPath = $ampliconTaxaPath.'\nbad line no tabs';
dies_ok {$t->readData({%args, ampliconTaxaPath => \$badAmpliconTaxaPath}) } "Bad files are bad";

$args{ampliconTaxaPath} = \$ampliconTaxaPath;

lives_ok {$t->readData({%args}) } "Amplicon files have stuff";

my $wgsTaxaPath=<<"EOF";
	s1	s2
k__K|p__P|c__C|o__O|f__F|g__G|s__S	15111.0	16111.0
k__DifferentKingdom	0.1	0.2
k__yet_different_kingdom	1111.0	0
EOF

$args{wgsTaxaPath} = \$wgsTaxaPath;
dies_ok {$t->readData({%args}) } "WGS files need ECs and pathways";

my $level4ECsPath=<<"EOF";
	s1	s2
UNGROUPED	0.1	0.1
1.1.1.103: L-threonine 3-dehydrogenase|g__Escherichia.s__Escherichia_coli	17111.0	18111.0
1.1.1.103: L-threonine 3-dehydrogenase|unclassified	19111.0	20111.0
1.1.1.103: L-threonine 3-dehydrogenase	21111.0	22111.0
7.2.1.1: NO_NAME	23111.0	24111.0
8.2.1.1: NO_NAME	23111.0	0.0
EOF

my $pathwayAbundancesPath=<<"EOF";
	s1	s2
ANAEROFRUCAT-PWY: homolactic fermentation	25111.0	26111.0
ANAEROFRUCAT-PWY: homolactic fermentation|g__Escherichia.s__Escherichia_coli	27111.0	28111.0
ANAEROFRUCAT-PWY: homolactic fermentation|unclassified	29111.0	30111.0
BNAEROFRUCAT-PWY: homolactic fermentation|unclassified	29111.0	0.0
EOF

my $pathwayCoveragesPath=<<"EOF";
	s1	s2
ANAEROFRUCAT-PWY: homolactic fermentation	0.31111	0.32111
ANAEROFRUCAT-PWY: homolactic fermentation|g__Escherichia.s__Escherichia_coli	0.33111	0.34111
ANAEROFRUCAT-PWY: homolactic fermentation|unclassified	0.35111	0.36111
BNAEROFRUCAT-PWY: homolactic fermentation|unclassified	0.35111	0.0
EOF

$args{level4ECsPath} = \$level4ECsPath;
$args{pathwayAbundancesPath} = \$pathwayAbundancesPath;
$args{pathwayCoveragesPath} = \$pathwayCoveragesPath;

lives_ok {$t->readData({%args}) } "WGS files have stuff";

(my $badPathwayCoveragesPath = $pathwayCoveragesPath) =~ s/s2/different_sample/;
dies_ok {$t->readData({%args, pathwayCoveragesPath => \$badPathwayCoveragesPath}) } "Sample names should match";


(my $secondBadPathwayCoveragesPath = $pathwayCoveragesPath) =~ s/Escher/different_artist/;
dies_ok {$t->readData({%args, pathwayCoveragesPath => \$secondBadPathwayCoveragesPath}) } "Rows should match";


my @out = $t->readData({%args});
my $out = Dump @out;

like($out, qr/k;p;c;o;f;g;s/, "Amplicon taxa strings are not modified");
like($out, qr/K;P;C;O;F;G;S/, "WGS taxa strings are converted from humann format");

like($out, qr/different_kingdom/, "Amplicon taxa aggregates are preserved");
unlike($out, qr/DifferentKingdom/, "WGS taxa aggregates are skipped");

like($out, qr/s1/, "Mentions sample name");

like($out, qr/$_/, "Mentions bits of row headers: $_")
  for qw/1.1.1.103 L-threonine Escherichia ANAEROFRUCAT-PWY homolactic unclassified/;


subtest "ApiCommonData::Load::MBioResults::readData mentions bits of data" => sub {
  like($out, qr/${_}111/, "amplicon taxa: $_")
    for ("11".."14");
  like($out, qr/${_}111/, "WGS taxa: $_")
    for ("15".."16");
  like($out, qr/${_}111/, "level4ECs: $_")
    for ("17".."24");
  like($out, qr/${_}111/, "pathways: $_")
    for ("25".."36");
};
unlike($out, qr/UNGROUPED/, "Filters out artifact rows");
like($out, qr/description: homolactic fermentation/, "Description");
unlike($out, qr/description: NO_NAME/, "NO_NAME skipped as description");

like($out, qr/Escherichia coli/, "Fix the underscore in species name");

diag ("Do these look okay?"); 
diag (ApiCommonData::Load::MBioResultsTable::unmessBiobakerySpecies("Enterobacter_cloacae_complex"));
diag (ApiCommonData::Load::MBioResultsTable::unmessBiobakerySpecies("Veillonella_sp_T11011_6"));
diag (ApiCommonData::Load::MBioResultsTable::unmessBiobakerySpecies("Actinomyces_sp_oral_taxon_181"));
diag (ApiCommonData::Load::MBioResultsTable::unmessBiobakerySpecies("[Collinsella]_massiliensis"));
diag (ApiCommonData::Load::MBioResultsTable::maybeGoodMetaphlanRow("k__Bacteria|p__Actinobacteria|c__Actinobacteria|o__Actinomycetales|f__Actinomycetaceae|g__Varibaculum|s__Varibaculum_cambriense
"));

my $ampliconTaxaTable = ApiCommonData::Load::MBioResultsTable->ampliconTaxa(\$ampliconTaxaPath);
$ampliconTaxaTable->writeBiom(\$out);

my $wgsTaxaTable = ApiCommonData::Load::MBioResultsTable->wgsTaxa(\$wgsTaxaPath);
my $level4ECsTable = ApiCommonData::Load::MBioResultsTable->wgsFunctions("level4EC",\$level4ECsPath);
my $pathwaysTable = ApiCommonData::Load::MBioResultsTable->wgsPathways(\$pathwayAbundancesPath, \$pathwayCoveragesPath);

subtest "ApiCommonData::Load::MBioResultsTable::writeTabData mentions bits of data" => sub {
  $ampliconTaxaTable->writeTabData(\$out);
  like($out, qr/${_}111/, "amplicon taxa: $_")
    for ("11".."14");
  $wgsTaxaTable->writeTabData(\$out);
  like($out, qr/${_}111/, "WGS taxa: $_")
    for ("15".."16");

  $level4ECsTable->writeTabData(\$out);
  like($out, qr/${_}111/, "level4ECs: $_")
    for ("17".."24");
  $pathwaysTable->writeTabData(\$out);
  like($out, qr/${_}111/, "pathways: $_")
    for ("25".."36");
};

subtest "ApiCommonData::Load::MBioResultsTable::writeBiom mentions bits of data" => sub {
  $ampliconTaxaTable->writeBiom(\$out);
  like($out, qr/${_}111/, "amplicon taxa: $_")
    for ("11".."14");
  $wgsTaxaTable->writeBiom(\$out);
  like($out, qr/${_}111/, "WGS taxa: $_")
    for ("15".."16");

  $level4ECsTable->writeBiom(\$out);
  like($out, qr/${_}111/, "level4ECs: $_")
    for ("17".."24");
  $pathwaysTable->writeBiom(\$out);
  like($out, qr/${_}111/, "pathways: $_")
    for ("25".."36");
};

my $protocolAppNodeIdsForSamples = { "s1" => "s1pan111", "s2" => "s2pan111" };

subtest "ApiCommonData::Load::MBioResultsTable::submitToGus mentions bits of data" => sub {
  @out = ();

  $ampliconTaxaTable->submitToGus(sub{}, sub{}, sub{push @out, $_[1];}, $protocolAppNodeIdsForSamples);
  $out = Dump @out;

  like($out, qr/${_}111/, "amplicon taxa: $_")
    for ("11".."14", "s1pan", "s2pan");

  @out = ();
  $wgsTaxaTable->submitToGus(sub{}, sub{}, sub{push @out, $_[1];}, $protocolAppNodeIdsForSamples);
  $out = Dump @out;
  like($out, qr/${_}111/, "WGS taxa: $_")
    for ("15".."16", "s1pan", "s2pan");

  @out = ();
  $level4ECsTable->submitToGus(sub{}, sub{}, sub{push @out, $_[1];}, $protocolAppNodeIdsForSamples);
  $out = Dump @out;
  like($out, qr/${_}111/, "level4ECs: $_")
    for ("17".."24", "s1pan", "s2pan");

  @out = ();
  $pathwaysTable->submitToGus(sub{}, sub{}, sub{push @out, $_[1];}, $protocolAppNodeIdsForSamples);
  $out = Dump @out;
  like($out, qr/${_}111/, "pathways: $_")
    for ("25".."36", "s1pan", "s2pan");
};

my %sd = (
  s1 => { property => "aValue" },
  s2 => { property => "aDifferentValue", anotherProperty => "anotherValue"},
);
my @sd = uniq map {keys $sd{$_}, values $sd{$_}} qw/s1 s2/;

$_->addSampleDetails(\%sd) for ($ampliconTaxaTable, $wgsTaxaTable, $level4ECsTable, $pathwaysTable);

subtest "ApiCommonData::Load::MBioResultsTable::writeTabSampleDetails mentions sample details" => sub {
  $ampliconTaxaTable->writeTabSampleDetails(\$out);
  like($out, qr/${_}/, "amplicon taxa: $_")
    for @sd;
  $wgsTaxaTable->writeTabSampleDetails(\$out);
  like($out, qr/${_}/, "WGS taxa: $_")
    for @sd;
  $level4ECsTable->writeTabSampleDetails(\$out);
  like($out, qr/${_}/, "level4ECs: $_")
    for @sd;
  $pathwaysTable->writeTabSampleDetails(\$out);
  like($out, qr/${_}/, "pathways: $_")
    for @sd;
};
subtest "ApiCommonData::Load::MBioResultsTable::writeBiom mentions sample details" => sub {
  $ampliconTaxaTable->writeBiom(\$out);
  like($out, qr/${_}/, "amplicon taxa: $_")
    for @sd;
  $wgsTaxaTable->writeBiom(\$out);
  like($out, qr/${_}/, "WGS taxa: $_")
    for @sd;
  $level4ECsTable->writeBiom(\$out);
  like($out, qr/${_}/, "level4ECs: $_")
    for @sd;
  $pathwaysTable->writeBiom(\$out);
  like($out, qr/${_}/, "pathways: $_")
    for @sd;
};
done_testing;
