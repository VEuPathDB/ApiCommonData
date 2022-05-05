use strict;
use warnings;

use lib "$ENV{GUS_HOME}/lib/perl";

use ApiCommonData::Load::MBioResultsTable::AsEntities;
use Test::More;

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
  my $t = \&ApiCommonData::Load::MBioResultsTable::AsEntities::entitiesForSampleAbundanceCpms;
  is_deeply($t->({}), {}, "null case");

  my $x1 = $t->({Bacteria => 95, Archaea => 5});
  ok(keys %$x1 > 0, "return something");
  my @k1 = sort keys %$x1;

  my $x2 = $t->({Bacteria => 950, Archaea => 50});


  my @k2 = sort keys %$x2;

  is_deeply(\@k1, \@k2, "keys stay equal if all vars are scaled");

  is(
    $x1->{"relative abundance of class data"}{Archaea_}[1] * 10.0,
    $x2->{"relative abundance of class data"}{Archaea_}[1] * 1.0,
    "stays equal if all vars are scaled");

};

done_testing;
