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

my $sqlgenefeature = "SELECT source_id, na_feature_id FROM dots.genefeature";
my $sqlnafeaturenagene = "SELECT nag.name, nag.na_gene_id, nfng.na_feature_id, nfng.na_feature_na_gene_id
FROM Dots.NAGene nag, Dots.NaFeatureNaGene nfng
WHERE nfng.na_gene_id = nag.na_gene_id";

my $sqlnafeaturenagenedel = "delete from dots.nafeaturenagene where na_feature_na_gene_id = ?";
my $sqlnafeaturedel = "delete from dots.nagene where na_gene_id = ?";

my $sqldateupdate1="update dots.nafeaturenagene set modification_date=sysdate";
my $sqldateupdate2="update dots.nagene set modification_date=sysdate";

my $select1 = $dbh->prepare($sqlgenefeature);
my $select2 = $dbh->prepare($sqlnafeaturenagene);
my $delete1 = $dbh->prepare($sqlnafeaturenagenedel);
my $delete2 = $dbh->prepare($sqlnafeaturedel);
my $update1 = $dbh->prepare($sqldateupdate1);
my $update2 = $dbh->prepare($sqldateupdate2);

my %sourceId2NaFeatureId;
$select1 ->execute();
while (my ($sourceId, $na_feature_id) = $select1->fetchrow_array()) {
    $sourceId2NaFeatureId{$sourceId} = $na_feature_id;
}

my @pretenderAliases;
$select2 ->execute();
while (my ($alias, $na_gene_id, $na_feature_id, $na_f_na_g_id)
	 = $select2->fetchrow_array()) {

    my $a = [$alias, $na_f_na_g_id, $na_gene_id];

    if ($sourceId2NaFeatureId{$alias}) {
      push(@pretenderAliases, $a);
    }
}


my $NaFeatureNaGeneCount;
my $NaGeneCount;
my $error;


foreach my $dup (@pretenderAliases) {

  
  $delete1 ->execute($dup->[1]);
  my $delete1Rows = $delete1->rows;
  $NaFeatureNaGeneCount = $NaFeatureNaGeneCount + $delete1Rows;

  $delete2 ->execute($_);
  my $delete2Rows = $delete2->rows;
  $NaGeneCount = $NaGeneCount + $delete2Rows;

  # using the primary key should only be able to delete one row

 unless($delete1Rows == 1 ) {
    print STDERR "ERROR:   na_feature_na_gene_id [$dup->[1]] deleted $delete1Rows rows from dots.nagenenafeature !!!\n";
    $error = 1;
  }
  unless($delete2Rows == 1 ) {
    print STDERR "ERROR:   na_gene_id [$dup->[1]] deleted $delete2Rows rows from dots.nagene !!!\n";
    $error = 1;
  }
}

$update1->execute();
$update2->execute();

$select1->finish();
$select2->finish();
$delete1->finish();
$delete2->finish();
$update1->finish();
$update2->finish();

if($error) {
  $dbh->rollback();
  print STDERR "Errors!  Rolled back database\n";
}
else {
  $dbh->commit;
  print "Deleted $NaFeatureNaGeneCount from Dots.NaFeatureNaGene and $NaGeneCount from Dots.NaGene\n";
}

$dbh->disconnect();

1;
