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
use DBI;
use DBD::Oracle;

use Getopt::Long;

use CBIL::Util::PropertySet;

my ($help, $gusConfigFile, $extDbRlsSpec);

&GetOptions('help|h' => \$help,
            'gus_config_file=s' => \$gusConfigFile,
            'evigan_ext_db_rls_spec=s' => \$extDbRlsSpec,
            );


$gusConfigFile = $ENV{GUS_HOME} . "/config/gus.config" unless($gusConfigFile);

if($help) {
  print STDERR "usage:  perl updateEviganSecondaryScore --evigan_ext_db_rls_spec [--gus_config_file]\n";
  exit;
}

unless($extDbRlsSpec) {
  die "USER Error:  evigan_ext_db_rls_spec was not specified";
}

unless(-e $gusConfigFile) {
  die "Error:  gus config file [$gusConfigFile] does not exist";
}

my @properties = ();
my $gusconfig = CBIL::Util::PropertySet->new($gusConfigFile, \@properties, 1);

my $u = $gusconfig->{props}->{databaseLogin};
my $pw = $gusconfig->{props}->{databasePassword};
my $dsn = $gusconfig->{props}->{dbiDsn};

my $dbh = DBI->connect($dsn, $u, $pw) or die DBI::errstr;


my $sql = "select gf.na_feature_id, gf.source_id, gf.score
           from dots.genefeature gf, sres.externaldatabase d, sres.externaldatabaserelease r
           where gf.external_database_release_id = r.external_database_release_id
           and d.external_database_id = r.external_database_id
           and '$extDbRlsSpec' = d.name || '|' || r.version";

my $sh = $dbh->prepare($sql);
$sh->execute();


my $eviganModels = {};

my $rowCount;
while(my ($naFeatureId, $sourceId, $score) = $sh->fetchrow_array()) {
  $rowCount++;

  $sourceId =~ /(.+(rev|for))\d+$/;

  my $geneGroup = $1;

  $eviganModels->{$geneGroup}->{$naFeatureId} = $score;
}

print STDERR "Read $rowCount rows from Dots.GeneFeature\n";

$sh->finish();


$sql = "update dots.genefeature set secondary_score = ?, modification_date = sysdate where na_feature_id = ?";
$sh = $dbh->prepare($sql);

my $updates;
foreach my $group (keys %$eviganModels) {

  my $features = $eviganModels->{$group};

  my $max = 0;

  foreach my $feature (keys %$features) {
    my $score = $features->{$feature};

    $max = $score if($score > $max);
  }

  foreach my $feature (keys %$features) {
    my $score = $features->{$feature};
    my $percentage = $score / $max;

    $sh->execute($percentage, $feature);
    $updates++;


    if($updates % 500 == 0) {
      print STDERR "LOG:  updated $updates rows\n";
    }
  }
}

print STDERR "Updated $updates rows from Dots.GeneFeature\n";

$sh->finish();

$dbh->commit();
$dbh->disconnect();

1;
