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

my $sqldbref = "select df.db_ref_na_feature_id,r.db_ref_id from dots.genefeature official, dots.dbrefnafeature df, dots.genefeature other, sres.dbref r where official.na_feature_id = df.na_feature_id and other.source_id = r.primary_identifier and df.db_ref_id = r.db_ref_id";

my $sqldbrefnafeaturedelete = "delete from dots.dbrefnafeature where db_ref_na_feature_id= ?";

my $sqldbrefdelete = "delete from sres.dbref where sres.dbref= ?";

my $select = $dbh->prepare($sqldbref);

my $delete1 = $dbh->prepare($sqldbrefnafeaturedelete);

my $delete2 = $dbh->prepare($sqldbrefdelete);

$select ->execute();

my (%db_ref_na_feature_ids, %db_ref_ids);

while (my ($db_ref_na_feature_id, $db_ref_id) = $select->fetchrow_array()){

    $db_ref_na_feature_ids{$db_ref_na_feature_id}=1;
    $db_ref_ids{$db_ref_id}=1;
}

$select->finish();
my $error;
foreach(keys %db_ref_na_feature_ids) {
    next unless $_;
    $delete1 ->execute($_);
    my $rowCount = $delete1->rows;

    unless($rowCount == 1) {
	print STDERR "ERROR:   $_ deleted $rowCount rows !!!\n";
	$error = 1;
   }
}

if($error) {
  $dbh->rollback();
  print STDERR "Errors!  Rolled back database\n";
}

foreach(keys %db_ref_ids) {
    next unless $_;
    $delete2 ->execute($_);
    my $rowCount = $delete2->rows;

    unless($rowCount == 1) {
	print STDERR "ERROR:   $_ deleted $rowCount rows !!!\n";
	$error = 1;
   }
}

if($error) {
  $dbh->rollback();
  print STDERR "Errors!  Rolled back database\n";
}

$dbh->commit;


1;
