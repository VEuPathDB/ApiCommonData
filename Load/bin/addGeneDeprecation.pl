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

my ($help, $gusConfig, $file, $act, $date, $reas);

&GetOptions('help|h' => \$help,
            'gus_config=s' => \$gusConfig,
            'file=s' => \$file,
	    'action=s' => \$act,
	    'reason=s' => \$reas,
	    'date=s' => \$date,
            );
unless(-e $file && $date && ($act eq 'deprecated' || $act eq 'undeprecated')) {
  print STDERR "usage:  perl addGeneDeprecation.pl --file <INPUT_FILE> --action <deprecated|undeprecated> --date <18-November-2008> [--reason <text>] [--gus_config <FILE>]\n";
  exit;
}

unless(-e $gusConfig) {
  print STDERR "gus.config not found... using default\n";
  $gusConfig = $ENV{GUS_HOME} ."/config/gus.config";
}

my @properties = ();
my $gusconfig = CBIL::Util::PropertySet->new($gusConfig, \@properties, 1);

my $u = $gusconfig->{props}->{databaseLogin};
my $pw = $gusconfig->{props}->{databasePassword};
my $dsn = $gusconfig->{props}->{dbiDsn};

my $dbh = DBI->connect($dsn, $u, $pw, {RaiseError => 1}) or die DBI::errstr;
my @gene_id;
my $count = 0;
my $id;


my $sql = "INSERT INTO ApiDB.GeneDeprecation (source_id, action, action_date, reason) 
    VALUES (?, '$act', (SELECT TO_DATE ( '$date', 'DD-MONTH-YYYY') from dual), '$reas')";
my $sh = $dbh->prepare($sql);


open(FILE, $file) or die "Cannot open file $file for reading: $!";
while(<FILE>) {
  chomp;

  $id = $_;
  $sh->execute($id);
  $count++;
}

print STDERR "Inserted $count rows\n";
$sh->finish();
close(FILE);
$dbh->disconnect();


## RUNS on giar-inc:
## > perl  addGeneDeprecation.pl --file /files/cbil/data/cbil/giardiaDB/manualDelivery/deprecatedGenes/GeneDeprecationTable/deprecated_v11  --action deprecated --date 18-November-2008
## Inserted 4778 rows

## > perl  addGeneDeprecation.pl --file /files/cbil/data/cbil/giardiaDB/manualDelivery/deprecatedGenes/GeneDeprecationTable/undeprecated_v20 --action undeprecated --date 16-November-2009 --reason 'This assemblage A gene has been undeprecated based on synteny to assemblage B and E genomes.'
## Inserted 1012 rows
