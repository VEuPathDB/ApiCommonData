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

sub testAlphaDiversity {
  my ($label, $t) = @_;
  subtest $label => sub {
    is($t->([]), 0, "diversity of no population is zero");
    ok($t->([1,2,3]) > 0, "diversity of two or more taxa is positive");
    ok($t->([1,2,3,4]) == $t->([10,20,30,40]), "diversity uses relative values");
    ok($t->([1,2,3,4]) > $t->([1,2,3]), "additional taxa -> more diversity");
    ok($t->([1,1,1]) > $t->([1,2,3]), "more even distribution of taxa -> more diversity");
  };
};

testAlphaDiversity("Alpha diversity, Shannon", \&ApiCommonData::Load::MBioResultsTable::AsEntities::alphaDiversityShannon);
testAlphaDiversity("Alpha diversity, inverse Simpson", \&ApiCommonData::Load::MBioResultsTable::AsEntities::alphaDiversityInverseSimpson);


done_testing;
