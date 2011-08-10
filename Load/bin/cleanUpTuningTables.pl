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

my $dbh = DBI->connect($dsn) or die DBI->errstr;
$dbh->{RaiseError} = 1;
$dbh->{AutoCommit} = 0;

$schema = uc $schema;

my $sh = $dbh->prepare("select synonym_name from all_synonyms where owner = '$schema'");
$sh->execute();

my @allSynonyms;
while(my ($syn) = $sh->fetchrow_array()) {
  push @allSynonyms, uc $syn;
}
$sh->finish();


my $xml = XMLin($xml, ForceArray => 1);

my %legitTables;




unless($cleanAll) {
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
  AND owner != 'SYS'
  AND table_name not like 'QUERY_RESULT_%'");
$d_sh->execute();


my %all4D;
while(my ($table, $synonym) = $d_sh->fetchrow_array()) {
  push @{$all4D{$synonym}}, $table;
}

foreach(@extra) {
  print "drop synonym $schema.$_;\n";
  print "delete apidb.tuningtable where upper(name) = '$schema.$_';\n";


  foreach(@{$all4D{$_}}) {
    print "dropt table $schema.$_;\n";
  }

print "\n\n";
}


$dbh->disconnect();
