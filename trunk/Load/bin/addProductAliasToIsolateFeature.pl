#!/usr/bin/perl

use strict;

use Getopt::Long;

use DBI;
use DBD::Oracle;

use CBIL::Util::PropertySet;

my ($help, $fn, $gusConfig, $extDbName, $extDbVer);

&GetOptions('help|h' => \$help,
            'file=s' => \$fn,
            'gus_config=s' => \$gusConfig,
            'extDbName=s' => \$extDbName,
            'extDbVer=s' => \$extDbVer,
            );

unless(-e $fn && $extDbName && $extDbVer) {
  print STDERR "usage:  perl addProductAliasToIsolateFeature.pl --file <MAPPING FILE> --extDbName --extDbVer  [--gus_config <FILE>]\n";
  exit;
}

unless(-e $gusConfig) {
  print STDERR "gus.config not found... using default\n";
  $gusConfig = $ENV{GUS_HOME} ."/config/gus.config";
}

my @properties = ();
my $gusconfig = CBIL::Util::PropertySet->new($gusConfig, \@properties, 1);

my $u = $gusconfig->{props}->{databaseLogin};
my $pw = $gusconfig->{props}->{databasePassword};
my $dsn = $gusconfig->{props}->{dbiDsn};

my $dbh = DBI->connect($dsn, $u, $pw) or die DBI::errstr;

my $namesMap = &makeMap($fn);

my $sql = "select f.na_feature_id, f.product 
from dots.ISOLATEFEATURE f, 
Sres.EXTERNALDATABASE e, SRes.EXTERNALDATABASERELEASE r 
where f.external_database_release_id = r.external_database_release_id
and r.external_database_id = e.external_database_id
and r.version = '$extDbVer'
and e.name = '$extDbName'
";
my $sh = $dbh->prepare($sql);
$sh->execute();

my $update = "update dots.isolatefeature set product = ?, product_alias = ? where na_feature_id = ?";
my $updateSh = $dbh->prepare($update);

my $count;
while(my ($id, $product) = $sh->fetchrow_array()) {

  my $new = $namesMap->{$product};
  die "Row in mapping file missing for product: $product" unless($new);

  # only update if the product is different from the alias
  if($new ne $product) {
    my $rowsUp = $updateSh->execute($new, $product, $id);

    $count = $count + $rowsUp;
  }

}

print STDERR "Updated $count rows in IsolateFeature\n";

$updateSh->finish();
$sh->finish();

$dbh->disconnect();

sub makeMap {
  my ($fn) = @_;

  my %map;
  open(FILE, $fn) or die "Cannot open file $fn for reading: $!";
 
  #rm header
  <FILE>;
  while(<FILE>) {
    chomp;

    my ($old, $new) = split(/\t/, $_);

    $map{$old} = $new;
  }

  return \%map;
}
