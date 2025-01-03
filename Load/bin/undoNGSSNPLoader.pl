#!/usr/bin/perl
#vvvvvvvvvvvvvvvvvvvvvvvvv GUS4_STATUS vvvvvvvvvvvvvvvvvvvvvvvvv
  # GUS4_STATUS | SRes.OntologyTerm              | auto   | absent
  # GUS4_STATUS | SRes.SequenceOntology          | auto   | absent
  # GUS4_STATUS | Study.OntologyEntry            | auto   | absent
  # GUS4_STATUS | SRes.GOTerm                    | auto   | absent
  # GUS4_STATUS | Dots.RNAFeatureExon            | auto   | absent
  # GUS4_STATUS | RAD.SageTag                    | auto   | absent
  # GUS4_STATUS | RAD.Analysis                   | auto   | absent
  # GUS4_STATUS | ApiDB.Profile                  | auto   | absent
  # GUS4_STATUS | Study.Study                    | auto   | absent
  # GUS4_STATUS | Dots.Isolate                   | auto   | absent
  # GUS4_STATUS | DeprecatedTables               | auto   | absent
  # GUS4_STATUS | Pathway                        | auto   | absent
  # GUS4_STATUS | DoTS.SequenceVariation         | auto   | absent
  # GUS4_STATUS | RNASeq Junctions               | auto   | absent
  # GUS4_STATUS | Simple Rename                  | auto   | absent
  # GUS4_STATUS | ApiDB Tuning Gene              | auto   | absent
  # GUS4_STATUS | Rethink                        | auto   | absent
  # GUS4_STATUS | dots.gene                      | manual | absent
#^^^^^^^^^^^^^^^^^^^^^^^^^ End GUS4_STATUS ^^^^^^^^^^^^^^^^^^^^

use strict;

use Getopt::Long;

use DBI;
use DBD::Oracle;

my ($help, $extDbRlsSpec, $dbiInstance, $dbiUser, $dbiPass);

&GetOptions("extdb_spec=s"=> \$extDbRlsSpec,
            "dbi_instance=s" => \$dbiInstance,
            "dbi_user=s" => \$dbiUser,
            "dbi_pswd=s" => \$dbiPass,
            "help|h" => \$help);

if($help || !$extDbRlsSpec) {
  print STDERR "usage:  perl undoNGSSNPLoader.pl --extdb_spec=s";
  exit(0);
}

my $dbh = DBI->connect("dbi:Oracle:$dbiInstance", $dbiUser, $dbiPass) or die DBI->errstr;
$dbh->{RaiseError} = 1;
$dbh->{AutoCommit} = 0;


my $sql = "select r.external_database_release_id from sres.externaldatabase d, sres.externaldatabaserelease r where d.external_database_id = r.external_database_id and d.name || '|' || r.version = ?";
my $sh = $dbh->prepare($sql);
$sh->execute($extDbRlsSpec);

my ($extDbrlsId) = $sh->fetchrow_array();
$sh->finish();

die "Did not retrieve an ext db rls id for $extDbRlsSpec" unless($extDbrlsId);


$dbh->do("create table apidb.sequencevariation_tmp as (select * from apidb.sequencevariation where snp_ext_db_rls_id != $extDbrlsId)");

$dbh->do("drop table apidb.sequencevariation");

$dbh->do("create table apidb.sequencevariation as (select * from apidb.sequencevariation_tmp)");

$dbh->do("drop table apidb.sequencevariation_tmp");

$dbh->do("create table apidb.snp_tmp as (select * from apidb.snp where external_database_release_id != $extDbrlsId)");

$dbh->do("drop table apidb.snp");

$dbh->do("create table apidb.snp as (select * from apidb.snp_tmp)");

$dbh->do("drop table apidb.snp_tmp");

# Grant permissions
$dbh->do("GRANT insert, select, update, delete ON ApiDB.SNP TO gus_w");
$dbh->do("GRANT select ON ApiDB.SNP TO gus_r");
$dbh->do("GRANT insert, select, update, delete ON ApiDB.SequenceVariation TO gus_w");
$dbh->do("GRANT select ON ApiDB.SequenceVariation TO gus_r");

$dbh->disconnect();










