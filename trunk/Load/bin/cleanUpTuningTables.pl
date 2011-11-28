#!/usr/bin/perl

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


my $d_sh = $dbh->prepare("   select table_name, regexp_replace(table_name, '[0-9][0-9][0-9][0-9]', '') as syn
from all_tables
where regexp_replace(table_name, '[0-9][0-9][0-9][0-9]', 'fournumbers')
      like '\%fournumbers'
  AND owner = '$schema'
  AND table_name not like 'QUERY_RESULT_%'");
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
