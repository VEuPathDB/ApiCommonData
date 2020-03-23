use strict;
use warnings;

use lib "$ENV{GUS_HOME}/lib/perl";

use ApiCommonData::Load::Biom::Lineages;
use Test::More;

my $maxLengthLevel = 200;
my $maxLengthLineage = 150;
my $t = ApiCommonData::Load::Biom::Lineages->new("unassigned", ["l1", "l2", "l3"], $maxLengthLevel, $maxLengthLineage);

is_deeply($t->getTermsFromObject("id",{}), {unassigned => "id", lineage => "id"}, "Use id if taxonomy missing");
is_deeply($t->getTermsFromObject("id",{taxonomy => "pancake"}), {unassigned => "pancake", lineage => "pancake"}, "No semicolons means unassigned");
is_deeply($t->getTermsFromObject("id",{Taxonomy => "pancake"}), $t->getTermsFromObject("id",{taxonomy => "pancake"}), "Uppercase taxonomy dict key");

is_deeply($t->getTermsFromObject("id",{l1=>"a", l2=>"b"}),{lineage => "a;b", l1 => "a", l2 => "b"}, "If terms are provided then use them");

is_deeply($t->getTermsFromObject("id",{l1=>""}),{lineage => "id", unassigned => "id"}, "If terms provided are no good then do not use them");
is_deeply($t->getTermsFromObject("id",{l1=>{k=>1}}),{lineage => "id", unassigned => "id"}, "If terms provided are no good then do not use them 2");

is_deeply($t->getTermsFromObject("id",{taxonomy =>"a;b;c"}),{lineage => "a;b;c", l1 => "a", l2 => "b", l3 => "c"}, "Simple case");
is_deeply($t->getTermsFromObject("id",{taxonomy =>"a;b"}),{lineage => "a;b", l1 => "a", l2 => "b"}, "Not enough terms is also okay");

is_deeply($t->getTermsFromObject("a" x 666, {})->{"lineage"}, "a" x $maxLengthLineage, "Limit lineage length");
is_deeply($t->getTermsFromObject("id", {taxonomy => "a" x 666})->{"lineage"}, "a" x $maxLengthLineage, "Limit lineage length 2");
is_deeply($t->getTermsFromObject("a" x 666, {})->{"unassigned"}, "a" x $maxLengthLevel, "Limit level length");
is_deeply($t->getTermsFromObject("id", {taxonomy => ("a" x 666).";b"})->{"l1"},"a" x $maxLengthLevel, "Limit level length 2");
is_deeply($t->getTermsFromObject("id", {taxonomy => "a;" .("b" x 666)})->{"l2"},"b" x $maxLengthLevel, "Limit level length 3");

is_deeply($t->splitLineageString("a;b"),["a","b"], "Simple case 2");

is_deeply($t->splitLineageString("a;b;c subsp. d ; c subsp. d serovar e"),["a","b","c subsp. d serovar e"], "Extra terms - drop extra terms with no information");

is_deeply($t->splitLineageString("a;;b"),["a","b"], "Remove empty terms");
is_deeply($t->splitLineageString("a;;"),["a"], "Remove empty terms 2");
is_deeply($t->splitLineageString("a;a"),["a","a"], "Terms can repeat");
is_deeply($t->splitLineageString(" a ; b "),["a","b"], "Strip whitespace");
is_deeply($t->splitLineageString("g__a;s__b"),["a","b"], "Strip prefixes");
is_deeply($t->splitLineageString("sk__a;k__b"),["a","b"], "Strip prefixes 2");
is_deeply($t->splitLineageString("g__a;s__"),["a"], "Skip empty terms at the end");
is_deeply($t->splitLineageString("sk__a;k__;s__b"),["a","b"], "Ignore superkingdoms");
is_deeply($t->splitLineageString("cellular organisms;a"),["a"], "Ignore ncbi root node");
is_deeply($t->splitLineageString("cellular organisms;a;b"),["a","b"], "Ignore ncbi root node 2");

is_deeply($t->splitLineageString("a;b;c;d"),["a","b","c d"], "Extra terms - store in the last term, separated by space");
is_deeply($t->splitLineageString("a;b;c;c"),["a","b", "c"], "Extra terms - drop if they're repeated");

is_deeply($t->splitLineageString("Bacteria;Escherichia;coli"),["Bacteria","Escherichia", "Escherichia coli"], "Species are in binomial 1");
is_deeply($t->splitLineageString("Bacteria;Escherichia;Escherichia coli"),["Bacteria","Escherichia", "Escherichia coli"], "Species are in binomial 2");
is_deeply($t->splitLineageString("Bacteria;Escherichia;E. coli"),["Bacteria","Escherichia", "E. coli"], "Species are in binomial 3");
is_deeply($t->splitLineageString("Bacteria;Escherichia;coli subsp. 1"),["Bacteria","Escherichia", "Escherichia coli subsp. 1"], "Species are in binomial 4");
is_deeply($t->splitLineageString("Bacteria;Escherichia;the great escherichia coli species"),["Bacteria","Escherichia", "the great escherichia coli species"], "Species are in binomial 5");
done_testing;
