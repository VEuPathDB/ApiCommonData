use strict;
use warnings;

use lib "$ENV{GUS_HOME}/lib/perl";

use ApiCommonData::Load::MBioResultsTable;
use ApiCommonData::Load::MBioResultsTable::AsText;
use ApiCommonData::Load::MBioResultsTable::AsGus;
use ApiCommonData::Load::MBioResultsTable::AsEntities;
use Test::More;
use Test::Exception;
use YAML;
use List::Util qw/uniq/;


my $ampliconTaxaPath=<<"EOF";
	s1	s2
k;p;c;o;f;g;s	11111.0	12111.0
different_kingdom	13111.0	14111.0
yet_different_kingdom	1111.0	
EOF

my $wgsTaxaPath=<<"EOF";
	s1	s2
k__K|p__P|c__C|o__O|f__F|g__G|s__S	15111.0	16111.0
k__DifferentKingdom	0.1	0.2
k__yet_different_kingdom	1111.0	0
EOF

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

my ($ampliconTaxaTable, $wgsTaxaTable, $level4ECsTable, $pathwaysTable);

sub setUpWithClass {
  my ($class) = @_;

  $ampliconTaxaTable = $class->ampliconTaxa(\$ampliconTaxaPath);
  $wgsTaxaTable = $class->wgsTaxa(\$wgsTaxaPath);
  $level4ECsTable = $class->wgsFunctions("level4EC",\$level4ECsPath);
  $pathwaysTable = $class->wgsPathways(\$pathwayAbundancesPath, \$pathwayCoveragesPath);
}
subtest "parse the input" => sub {
  setUpWithClass('ApiCommonData::Load::MBioResultsTable');
  like(Dump($ampliconTaxaTable->{rows}), qr/k;p;c;o;f;g;s/, "Amplicon taxa strings are not modified");
  like(Dump($wgsTaxaTable->{rows}), qr/K;P;C;O;F;G;S/, "WGS taxa strings are converted from humann format");

  like(Dump($ampliconTaxaTable->{rows}), qr/different_kingdom/, "Amplicon taxa aggregates are preserved");
  unlike(Dump($wgsTaxaTable->{rows}), qr/DifferentKingdom/, "WGS taxa aggregates are skipped");

  is_deeply($_->{samples}, ["s1", "s2"], "Samples") for ($ampliconTaxaTable , $wgsTaxaTable, $level4ECsTable, $pathwaysTable);

  like(Dump($level4ECsTable->{rows}), qr/1.1.1.103/, "Mentions bits of row headers: 1.1.1.103");
  unlike(Dump($level4ECsTable->{rows}), qr/UNGROUPED/, "Skips ungrouped");
  like(Dump($pathwaysTable->{rows}), qr/ANAEROFRUCAT-PWY/, "Mentions bits of row headers:  ANAEROFRUCAT-PWY");


  subtest "table dump mentions bits of data" => sub {
    my $out = "";
    like(Dump($ampliconTaxaTable->{data}), qr/${_}111/, "amplicon taxa: $_")
      for ("11".."14");
    like(Dump($wgsTaxaTable->{data}), qr/${_}111/, "WGS taxa: $_")
      for ("15".."16");
    like(Dump($level4ECsTable->{data}), qr/${_}111/, "level4ECs: $_")
      for ("17".."24");
    like(Dump($pathwaysTable->{data}), qr/${_}111/, "pathways: $_")
      for ("25".."36");
  };
};


subtest "writeTabData mentions bits of data" => sub {
  setUpWithClass('ApiCommonData::Load::MBioResultsTable::AsText');
  my $out = "";
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

subtest "writeBiom mentions bits of data" => sub {
  setUpWithClass('ApiCommonData::Load::MBioResultsTable::AsText');
  my $out = "";
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

my %sd = (
  s1 => { property => "aValue" },
  s2 => { property => "aDifferentValue", anotherProperty => "anotherValue"},
);
my @sd = uniq map {%{$sd{$_}}} qw/s1 s2/;


subtest "writeTabSampleDetails mentions sample details" => sub {
  setUpWithClass('ApiCommonData::Load::MBioResultsTable::AsText');
  my $out = "";
  $_->addSampleDetails(\%sd) for ($ampliconTaxaTable, $wgsTaxaTable, $level4ECsTable, $pathwaysTable);
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
subtest "writeBiom mentions sample details" => sub {
  setUpWithClass('ApiCommonData::Load::MBioResultsTable::AsText');
  my $out = "";
  $_->addSampleDetails(\%sd) for ($ampliconTaxaTable, $wgsTaxaTable, $level4ECsTable, $pathwaysTable);
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


subtest "submitToGus mentions bits of data" => sub {
  setUpWithClass('ApiCommonData::Load::MBioResultsTable::AsGus');
  my $protocolAppNodeIdsForSamples = { "s1" => "s1pan111", "s2" => "s2pan111" };
  my $out = "";
  my @out = ();

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
done_testing;
