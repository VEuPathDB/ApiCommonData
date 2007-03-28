#!/usr/bin/perl

use strict;

use DBI;
use DBD::Oracle;

use Getopt::Long;

use CBIL::Util::PropertySet;

=pod

=head1 Purpose

Simple script to convert database values to gus primary keys in a simple RAD Config file:  key<TAB>value)

=cut

my ($help, $fn, $gusConfig, $out, $data, $dataOut);

&GetOptions('help|h' => \$help,
            'config_in=s' => \$fn,
            'data_in=s' => \$data,
            'gus_config_file=s' => \$gusConfig,
            'config_out=s' => \$out,
            'data_out=s' => \$dataOut,
            );

if($help || !$fn || !$data || !$out || !$dataOut) {
  print STDERR "usage: perl loadArrayDesignConfig.pl --config_in <CONFIG> --data_in <DATA> --config_out STRING --data_out STRING [--gus_config_file] \n";
  exit();
}

unless($gusConfig) {
  $gusConfig = $ENV{GUS_HOME} . "/config/gus.config";
}

my @properties = ();
my $gusProp = CBIL::Util::PropertySet->new($gusConfig, \@properties, 1);

my $u = $gusProp->{props}->{databaseLogin};
my $pw = $gusProp->{props}->{databasePassword};
my $dsn = $gusProp->{props}->{dbiDsn};

my $dbh = DBI->connect($dsn, $u, $pw) or die DBI::errstr;

my %expected = (external_database_release_id => <<Sql,
select external_database_release_id 
from SRes.ExternalDatabaseRelease r, SRes.EXTERNALDATABASE e
where e.external_database_id = r.external_database_id
 and e.name = ?
 and r.version = ?
Sql
                design_element_type_id => <<Sql,
select ontology_entry_id from Study.ONTOLOGYENTRY 
where category = 'DesignElement' 
 and value = ?
Sql
                physical_biosequence_type_id => <<Sql,
select ontology_entry_id from Study.ONTOLOGYENTRY 
where category = 'PhysicalBioSequenceType' 
 and value = ?
Sql
                polymer_type_id => <<Sql,
select ontology_entry_id from Study.ONTOLOGYENTRY 
where category = 'PolymerType' 
 and value = ?

Sql
               );

open(CONFIG, $fn) or die "Cannot open file $fn for reading: $!";
open(OUT, "> $out") or die "Cannot open file $out for writing: $!";


my %addData;

while(<CONFIG>) {
  chomp;

  my ($key, $value) = split(/\t/, $_);

  my @ar = split(/\|/, $value);

  foreach my $s (keys %expected) {
    if($key =~ /\.$s/) {
      my $sql = $expected{$s};

      my $sh = $dbh->prepare($sql);
      $sh->execute(@ar);

      $addData{$s} = $sh->fetchrow_array();

      unless($addData{$s}) {
        die "ERROR:  [$key] ... No Result for Sql $sql";
      }

      $value = $s;

      $sh->finish();
    }
  }
  print OUT "$key\t$value\n";
}

close CONFIG;
close OUT;

open(DATA, $data) or die "Cannot open file $data for reading: $!";
open(DATAOUT, "> $dataOut") or die "Cannot open file $dataOut for writing: $!";

my $header = join("\t", sort keys %addData);
print DATAOUT $header . "\t" . <DATA>;

while(<DATA>) {
  my @values = map { $addData{$_} } sort keys %addData;
  my $row = join("\t", @values);

  print DATAOUT $row . "\t" . <DATA>;
}

close DATA;
close DATAOUT;


$dbh->disconnect();

1;
