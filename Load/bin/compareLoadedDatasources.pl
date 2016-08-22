#!/usr/bin/perl

use strict;
use DBI;
use DBD::Oracle;
use Getopt::Long;

use Data::Dumper;

my ($help, $dsn1, $dsn2);


&GetOptions('help|h' => \$help,
            'dbi_dsn1=s' => \$dsn1,
            'dbi_dsn2=s' => \$dsn2,
            );



my $dbh1 = DBI->connect($dsn1) or die DBI->errstr;
$dbh1->{RaiseError} = 1;
$dbh1->{AutoCommit} = 0;


my $dbh2 = DBI->connect($dsn2) or die DBI->errstr;
$dbh2->{RaiseError} = 1;
$dbh2->{AutoCommit} = 0;


my $sql = "select name from apidb.datasource where name not like '%copyNumberVariation%' and name not like '%metaData%'";

my $sh1 = $dbh1->prepare($sql);
$sh1->execute();

my $sh2 = $dbh2->prepare($sql);
$sh2->execute();

my %hash;

while(my ($name) = $sh1->fetchrow_array()) {
  push @{$hash{$name}}, 0;
}
$sh1->finish();

while(my ($name) = $sh2->fetchrow_array()) {
  push @{$hash{$name}}, 1;
}
$sh2->finish();

$dbh1->disconnect();
$dbh2->disconnect();


foreach my $name (keys %hash) {
  die "cannot be more than 2 datasets" if(scalar @{$hash{$name}} > 2);

  next if(scalar @{$hash{$name}} > 1);

  my $index = $hash{$name}->[0];

  my @a;

  $a[$index] = $name;

  print join("\t", @a) . "\n";
  
}

