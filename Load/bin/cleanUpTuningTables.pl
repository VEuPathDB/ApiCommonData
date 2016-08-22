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

use DBI;

use XML::Simple;

use Getopt::Long;

use Data::Dumper;

my ($help, $instance, $schema, $xml, $cleanAll);

&GetOptions('help|h' => \$help,
            'instance=s' => \$instance,
            'schema=s' => \$schema,
            'xml=s' => \$xml,
            'clean_all' => \$cleanAll,
            );

my $dsn = "dbi:Oracle:$instance";

my $dbh = DBI->connect($dsn, $schema) or die DBI->errstr;
$dbh->{RaiseError} = 1;
$dbh->{AutoCommit} = 1;

$schema = uc $schema;

my $sh = $dbh->prepare("select synonym_name from all_synonyms where owner = '$schema'");
$sh->execute();

my @allSynonyms;
while(my ($syn) = $sh->fetchrow_array()) {
  push @allSynonyms, uc $syn;
}
$sh->finish();




my %legitTables;


unless($cleanAll) {
  my $xml = XMLin($xml, ForceArray => 1);

  foreach(map {uc} keys %{$xml->{tuningTable}}) {
    $legitTables{$_} = 1;
  }
}

my @extra;
foreach(@allSynonyms) {
  push @extra, $_ unless($legitTables{$_});
}


my $d_sh = $dbh->prepare("select tab.table_name, syn.synonym_name as syn
from all_tables tab, all_synonyms syn
where regexp_replace(tab.table_name, '[0-9][0-9][0-9][0-9]\$', 'fournumbers')
      like '\%fournumbers'
  AND tab.owner = '$schema'
  AND tab.owner = syn.owner
  AND syn.table_name = tab.table_name
  AND tab.table_name not like 'QUERY_RESULT_%'");
$d_sh->execute();

my %all4D;
while(my ($table, $synonym) = $d_sh->fetchrow_array()) {
  push @{$all4D{$synonym}}, $table;
}

foreach(@extra) {

  if($all4D{$_}) {
    $dbh->do("drop synonym $schema.$_");
    $dbh->do("delete apidb.tuningtable where upper(name) = '$schema.$_'");
  }
  else {
    print STDERR "-- WARNING There is a synonym for $schema.$_ but no table with 4 digits... skipping\n";
  }

  foreach(@{$all4D{$_}}) {
    $dbh->do("drop table $schema.$_");
  }
}


$dbh->disconnect();
