#!/usr/bin/perl

use strict;

use lib "$ENV{GUS_HOME}/lib/perl";

use CBIL::Util::PropertySet;
use Getopt::Long;
use DBI;
use DBD::Oracle;

my ($verbose,$gusConfigFile,$idSQL);

&GetOptions("verbose!"=> \$verbose,
            'gus_config_file=s' => \$gusConfigFile,
            "idSQL=s" => \$idSQL,
            );

die "usage: executeIdSQL.pl --idSQL 'sql query' [ --configFile gusConfigFile ]\n" unless $idSQL;

#============================================

$gusConfigFile = $ENV{GUS_HOME} . "/config/gus.config" unless($gusConfigFile);

my @properties = ();
my $gusconfig = CBIL::Util::PropertySet->new($gusConfigFile, \@properties, 1);

my $u = $gusconfig->{props}->{databaseLogin};
my $pw = $gusconfig->{props}->{databasePassword};
my $dsn = $gusconfig->{props}->{dbiDsn};

my $dbh = DBI->connect($dsn, $u, $pw) or die DBI::errstr;
$dbh->{RaiseError} = 1;
$dbh->{AutoCommit} = 0;

my $stmt = $dbh->prepare($idSQL);
$stmt ->execute();
$stmt->finish();
$dbh->commit;
print "Deleted rows from table.\n";

$dbh->disconnect();

1;
