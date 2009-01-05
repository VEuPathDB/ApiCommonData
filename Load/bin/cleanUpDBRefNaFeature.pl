#!/usr/bin/perl

use strict;

use lib "$ENV{GUS_HOME}/lib/perl";

use CBIL::Util::PropertySet;
use Getopt::Long;
use DBI;
use DBD::Oracle;

my ($verbose,$gusConfigFile);

&GetOptions("verbose!"=> \$verbose,
            'gus_config_file=s' => \$gusConfigFile,
            );

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

my $sqldbref = "select distinct r.db_ref_id
from dots.genefeature official, dots.dbrefnafeature df, dots.genefeature other, sres.dbref r 
where official.na_feature_id = df.na_feature_id 
and other.source_id = r.primary_identifier 
and df.db_ref_id = r.db_ref_id";

my $sqldbrefnafeaturedelete = "delete from dots.dbrefnafeature where db_ref_id= ?";
my $sqldbrefdelete = "delete from sres.dbref where db_ref_id = ?";

my $select = $dbh->prepare($sqldbref);
my $delete1 = $dbh->prepare($sqldbrefnafeaturedelete);
my $delete2 = $dbh->prepare($sqldbrefdelete);

$select ->execute();

my $dbrefNaFeatureCount;
my $dbrefCount;
my $error;

my @dbRefIds;

while (my ($db_ref_id) = $select->fetchrow_array()){
  push @dbRefIds, $db_ref_id;
}

foreach(@dbRefIds) {

  #There may be many dbrefnafeature for a given db_ref_id
  $delete1 ->execute($_);
  $dbrefNaFeatureCount = $dbrefNaFeatureCount + $delete1->rows;

  $delete2 ->execute($_);
  my $delete2Rows = $delete2->rows;
  $dbrefCount = $dbrefCount + $delete2Rows;

  # using the primary key should only be able to delete one row
  unless($delete2Rows == 1) {
    print STDERR "ERROR:   db_ref_id [$_] deleted $delete2Rows rows from sres.dbref !!!\n";
    $error = 1;
  }
}

$select->finish();
$delete1->finish();
$delete2->finish();

if($error) {
  $dbh->rollback();
  print STDERR "Errors!  Rolled back database\n";
}
else {
  $dbh->commit;
  print "Deleted $dbrefNaFeatureCount from Dots.DbrefNaFeature and $dbrefCount from SRes.DbRef\n";
}

$dbh->disconnect();

1;
