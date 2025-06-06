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
use Getopt::Long;
use DBI;
use DBD::Oracle;
use CBIL::Util::PropertySet;

my ($aefExtDbSpec, $inputFile, $outputFile);
&GetOptions('aefExtDbSpec=s' => \$aefExtDbSpec,
            'inputFile=s' => \$inputFile,
            'outputFile=s' => \$outputFile,
           );

die "ERROR: Please provide a valid External Database Spec ('name|version') for the Array Element Features"  unless ($aefExtDbSpec);
die "ERROR: Please provide a valid smoothed profile file"  unless ($inputFile);

my $gusConfigFile = $ENV{GUS_HOME} . "/config/gus.config";

my @properties = ();
my $gusconfig = CBIL::Util::PropertySet->new($gusConfigFile, \@properties, 1);

my $u = $gusconfig->{props}->{databaseLogin};
my $pw = $gusconfig->{props}->{databasePassword};
my $dsn = $gusconfig->{props}->{dbiDsn};
my $dbh = DBI->connect($dsn, $u, $pw) or die DBI::errstr;

my $sql = "select aef.source_id, aef.name
from sres.externaldatabase d, sres.externaldatabaserelease r, dots.arrayelementfeature aef
where d.external_database_id = r.external_database_id
and d.name || '|' || r.version = '$aefExtDbSpec'
and aef.external_database_release_id = r.external_database_release_id";

my %hash;

my $sh = $dbh->prepare($sql);
$sh->execute();

while(my ($sourceId, $name) = $sh->fetchrow_array()) {
  push @{$hash{$name}}, $sourceId;
}
$sh->finish();

$dbh->disconnect();

open(FILE, $inputFile) or die "Cannot open file $inputFile for reading: $!";
open(OUT, ">$outputFile") or die "Cannot open file $outputFile for writing: $!";
#remove the header;
<FILE>;

print OUT "ID_REF\tfloat_value\n";


while(<FILE>) {
  chomp;
  my ($probe, $val) = split(/\t/, $_);

  unless($hash{$probe}) {
    print STDERR "WARN:  No mapping for probe $probe\n";
    next;
  }

  foreach my $sourceId (@{$hash{$probe}}) {
    print OUT "$sourceId\t$val\n";
  }
}

close FILE;
