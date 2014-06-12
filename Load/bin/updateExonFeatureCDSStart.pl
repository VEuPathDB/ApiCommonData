#!/usr/bin/perl

use strict;
use lib "$ENV{GUS_HOME}/lib/perl";

use CBIL::Util::PropertySet;
use Getopt::Long;
use DBI;
use DBD::Oracle;

my ($help, $log, $gusConfigFile);

&GetOptions('help|h' => \$help,
            'log=s' => \$log,
            'gus_config_file=s' => \$gusConfigFile
            );

#============================================

$gusConfigFile = $ENV{GUS_HOME} . "/config/gus.config" unless($gusConfigFile);

unless($log) {
  print STDERR "usage --log [--gus_config_file]\n";
  exit;
}

my @properties = ();
my $gusconfig = CBIL::Util::PropertySet->new($gusConfigFile, \@properties, 1);

my $u = $gusconfig->{props}->{databaseLogin};
my $pw = $gusconfig->{props}->{databasePassword};
my $dsn = $gusconfig->{props}->{dbiDsn};

my $dbh = DBI->connect($dsn, $u, $pw) or die DBI::errstr;
$dbh->{RaiseError} = 1;
$dbh->{AutoCommit} = 0;

open(FILE, ">$log") or die "Cannot open file $log for writing:$!";

my $selectSql = "select ef.na_feature_id
from dots.exonfeature ef, dots.nalocation l
where ef.na_feature_id = l.na_feature_id
and ((l.is_reversed = 1
and ef.coding_start != l.end_max
and l.end_max - ef.coding_start <= 2)
or (l.is_reversed = 0
and ef.coding_start != l.start_min
and ef.coding_start - l.start_min <= 2))";

my $sth = $dbh->prepare($selectSql) || die "Couldn't prepare the SQL statement: $selectSql";

$sth->execute ||  die "Couldn't execute statement: ";

my @ids;
while(my ($naFeatureId)= $sth->fetchrow_array()){
  push(@ids,$naFeatureId);
}

print FILE "Retrieved ",scalar(@ids), " exon features to update\n";

my $num;

my $updateSql = "update dots.exonfeature ef set ef.coding_start =
(select CASE WHEN l.is_reversed = 1 THEN l.end_max ELSE l.start_min END from dots.nalocation l where l.na_feature_id = ?)
where ef.na_feature_id = ?";

my $sth2 = $dbh->prepare($updateSql)|| die "Couldn't prepare the SQL statement: $updateSql";

foreach my $naFeatureId (@ids){
  $sth2->execute($naFeatureId,$naFeatureId);

  $num++;

  if ($num % 500 == 0){
    $dbh->commit;
    print FILE "Number of dots.exonfeature rows updated = $num\n";
  }

}

print FILE "Total number of dots.exonfeature rows updated = $num\n";

$dbh->commit;

print FILE "Update Complete\n";

close FILE;

1;
