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
  # GUS4_STATUS | dots.gene                      | manual | unreviewed
die 'This file has broken or unreviewed GUS4_STATUS rules.  Please remove this line when all are fixed or absent';
#^^^^^^^^^^^^^^^^^^^^^^^^^ End GUS4_STATUS ^^^^^^^^^^^^^^^^^^^^

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

my $selectSql = "select na_feature_id from dots.genefeature";

my $sth = $dbh->prepare($selectSql) || die "Couldn't prepare the SQL statement: $selectSql";

$sth->execute ||  die "Couldn't execute statement: ";

my @ids;
while(my ($naFeatureId)= $sth->fetchrow_array()){
  push(@ids,$naFeatureId);
}

print FILE "Retrieved ",scalar(@ids), " gene features to update\n";

my $num;

my $updateSql = "update dots.NaLocation
set start_min = (select min(start_min)
                 from dots.NaLocation
                 where na_feature_id in (select na_feature_id
                                         from dots.ExonFeature
                                         where parent_id = ?)),
    start_max = (select min(start_max)
                 from dots.NaLocation
                 where na_feature_id in (select na_feature_id
                                         from dots.ExonFeature
                                         where parent_id = ?)),
    end_min = (select max(end_min)
               from dots.NaLocation
               where na_feature_id in (select na_feature_id
                                       from dots.ExonFeature
                                       where parent_id = ?)),
    end_max = (select max(end_max)
               from dots.NaLocation
               where na_feature_id in (select na_feature_id
                                       from dots.ExonFeature
                                       where parent_id = ?))
where na_feature_id = ?";

my $sth2 = $dbh->prepare($updateSql)|| die "Couldn't prepare the SQL statement: $updateSql";

foreach my $naFeatureId (@ids){
  $sth2->execute($naFeatureId,$naFeatureId,$naFeatureId,$naFeatureId,$naFeatureId);

  $num++;

  if ($num % 500 == 0){
    $dbh->commit;
    print FILE "Number of dots.genefeature rows updated = $num\n";
  }

}

print FILE "Total number of dots.genefeature rows updated = $num\n";

$dbh->commit;

print FILE "Update Complete\n";

close FILE;

1;
