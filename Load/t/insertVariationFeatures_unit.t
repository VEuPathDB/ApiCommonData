use strict;
use warnings;
use lib "$ENV{GUS_HOME}/lib/perl";
use Test::More;

# DB-free unit test of the plugin's psql \copy assembly. This pins the actual
# copyCommand output and guards the single-line invariant (a multi-line \copy
# fails in psql -f), plus the validSchema identifier check.

require ApiCommonData::Load::Plugin::InsertVariationFeatures;

my $pkg = 'ApiCommonData::Load::Plugin::InsertVariationFeatures';

# copyCommand uses no instance state, so a bare undef invocant is fine.
my $cmd = $pkg->can('copyCommand')->(undef, 'sch.MyTable', [qw/a b c/], '/tmp/x.tmp');

unlike($cmd, qr/\n/, 'copyCommand output is a single line (required by psql -f)');
is($cmd,
   "\\copy sch.MyTable (a, b, c) FROM '/tmp/x.tmp' "
   . "WITH (FORMAT CSV, DELIMITER E'\\t', QUOTE '`', ENCODING 'UTF8')",
   'copyCommand output matches the exact \copy form the integration test uses');

# validSchema rejects anything that is not a bare identifier.
is($pkg->can('validSchema')->(undef, 'apidb'), 'apidb', 'validSchema accepts a bare identifier');
eval { $pkg->can('validSchema')->(undef, 'apidb; drop table x') };
ok($@, 'validSchema rejects a schema name containing SQL');

done_testing;
