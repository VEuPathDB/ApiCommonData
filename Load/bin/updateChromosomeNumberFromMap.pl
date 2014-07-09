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

my ($help, $fn, $gusConfigFile, $sequenceTable);

&GetOptions('help|h' => \$help,
            'map_file=s' => \$fn,
            'gus_config_file=s' => \$gusConfigFile,
            'sequence_table=s' => \$sequenceTable,
            'ncbiTaxId=s' => \$ncbiTaxId,
            );

#============================================

$gusConfigFile = $ENV{GUS_HOME} . "/config/gus.config" unless($gusConfigFile);

unless(-e $fn && -e $fn && $sequenceTable) {
  print STDERR "usage --map_file map_file --sequence_table 'ExternalNaSequence|VirtualSequence' [--gus_config_file]\n";
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

open(FILE, $fn) or die "Cannot open file $fn for reading:$!";

# get taxon_id
$sth = $dbh->prepare("select taxon_id from sres.taxon where ncbi_tax_id = $ncbiTaxId") || die "Couldn't prepare the SQL statement: " . $$handle->errstr;  
$sth->execute ||  die "Couldn't execute statement: " . $sth->errstr;

my  ($taxon_id)  = $sth->fetchrow_array();

die "can't find taxon_id for ncbiTaxId ''\n" unless $taxon_id;

my $sql = "update dots.$sequenceTable set chromosome = ?, chromosome_order_num = ?, modification_date=sysdate where source_id = ? and taxon_id = $taxon_id";
my $sh = $dbh->prepare($sql);

my $error;

while(<FILE>) {
  chomp;
  my ($sourceId, $chr_order_num, $chrom) = split(/\t/, $_);

  next unless($chr_order_num);

  $chrom = "chromosome $chr_order_num" unless $chrom;

  $sh->execute($chrom, $chrom, $sourceId);
  my $rowCount = $sh->rows;
  unless($rowCount == 1) {
    print STDERR "ERROR:  Chrom $sourceId updated $rowCount rows !!!\n";
    $error = 1;
  }
}

if($error) {
  $dbh->rollback();
  die ("Errors!  Rolled back database\n");
}

$dbh->commit;
print STDERR "Update Complete\n";

close FILE;

1;
