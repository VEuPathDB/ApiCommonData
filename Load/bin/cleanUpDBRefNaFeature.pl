#!/usr/bin/perl

use strict;

use CBIL::Util::PropertySet;
use Getopt::Long;
use DBI;
use DBD::Oracle;

my ($help, $fn, $gusConfigFile, $sequenceTable);

&GetOptions('help|h' => \$help,
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

my $stmt1 = $dbh->prepareAndExecute($sqldbref);

my (%db_ref_na_feature_ids, %db_ref_ids);

while (my ($db_ref_na_feature_id, $db_ref_id) = stmt1 -> getchrow_array()){

    $db_ref_na_feature_ids{$db_ref_na_feature_id}=1;
    $db_ref_ids($db_ref_id)=1;
}
$stmt1->finish();

my $tmp1= scalar keys %db_ref_na_feature_ids;

my $tmp2 = scalar keys %db_ref_ids;

print STDERR "$tmp1\n";

print STDERR "$tmp2\n";



my $error;




1;
