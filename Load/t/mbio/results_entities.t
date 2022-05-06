use strict;
use warnings;

use lib "$ENV{GUS_HOME}/lib/perl";

use ApiCommonData::Load::MBioResultsTable::AsEntities;
use Test::More;
use YAML;

my $t = 'ApiCommonData::Load::MBioResultsTable::AsEntities';

subtest 'relative abundances' => sub {
  my $t = \&ApiCommonData::Load::MBioResultsTable::AsEntities::entitiesForSampleRelativeAbundances;
  is_deeply($t->({}), {}, "null case");

  my $x1 = $t->({Bacteria => 95, Archaea => 5});
  ok(keys %$x1 > 0, "return something");

  my $x2 = $t->({Bacteria => 950, Archaea => 50});

  is_deeply($x1, $x2, "stays equal if all vars are scaled");
};

subtest 'abundances cpms' => sub {
  my $t = \&ApiCommonData::Load::MBioResultsTable::AsEntities::entitiesForSampleGroupedAbundancesEukCpms;
  is_deeply($t->({}), {}, "null case");

  my $bla = "Eukaryota;;Bigyra;Opalinata;Blastocystidae;Blastocystis";
  my $myc = "Fungi;Ascomycota;Dothideomycetes;Capnodiales;Mycosphaerellaceae;Mycosphaerella;Mycosphaerella populi";
  my $x1 = $t->({$bla => 0.1337, $myc => 0.005});
  ok(keys %$x1 > 0, "return something");

  my $txt = Dump $x1;
  like($txt, qr/$_/, "has: $_") for qw/fungal Mycosphaerella protist Blastocystis 1337/;

};

done_testing;
