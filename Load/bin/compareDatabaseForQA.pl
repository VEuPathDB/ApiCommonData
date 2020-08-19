#!/usr/bin/perl

use strict;
use Getopt::Long;
use GUS::Model::SRes::Taxon;
use GUS::Model::SRes::TaxonName;
use GUS::Supported::GusConfig;


my ($dbA, $dbB, $gusConfigFile, $organismList, $help);

&GetOptions(
            'dbA=s' => \$dbA,
            'dbB=s' => \$dbB,
            'organismList=s' => \$organismList,
            'gusConfigFile=s' => \$gusConfigFile,
            'help|h' => \$help
            );

&usage() if ($help);
&usage("Missing a Required Argument") unless (defined $dbA && $dbB);

$gusConfigFile = "$ENV{GUS_HOME}/config/gus.config" unless ($gusConfigFile);

my $verbose;
my $gusconfig = GUS::Supported::GusConfig->new($gusConfigFile);

my $test = $gusconfig->getDbiDsn();
print STDERR "The test db is $test.\n";

my @orgs = ($organismList) ? split (/\,\s*/, $organismList) : @{getOrganismList($dbA)};

my (%seqA, %geneA, %pseudoA, %seqB, %geneB, %pseudoB);

## query dbA
foreach my $org (@orgs) {

  my $db = getDatabase($dbA);
  my $dbh = $db->getQueryHandle();

  my $ncbiTaxonId = getNcbiTaxonId ($org, $dbh);
  if ($ncbiTaxonId) {
    $seqA{$org} = getSequenceCount ($ncbiTaxonId, $dbh);
    $geneA{$org} = getGeneFeature ($ncbiTaxonId, $dbh);
    $pseudoA{$org} = getPseudoGeneCount ($ncbiTaxonId, $dbh);
  }

  $dbh->disconnect();
}

## query dbB
foreach my $org(@orgs) {
  my $db = getDatabase($dbB);
  my $dbh = $db->getQueryHandle();

  my $ncbiTaxonId = getNcbiTaxonId ($org, $dbh);
  if ($ncbiTaxonId) {
    $seqB{$org} = getSequenceCount ($ncbiTaxonId, $dbh);
    $geneB{$org} = getGeneFeature ($ncbiTaxonId, $dbh);
    $pseudoB{$org} = getPseudoGeneCount ($ncbiTaxonId, $dbh);
  }

  $dbh->disconnect();
}

foreach my $k (sort keys %seqA) {
  print STDERR "$k, sequence number, $dbA = $seqA{$k}, $dbB = $seqB{$k}\n";
  print STDERR "$k, pseudogene, $dbA = $pseudoA{$k}, $dbB = $pseudoB{$k}\n";

  print STDERR "Warning... for $k, sequence number, $dbA = $seqA{$k}, NOT EQUAL $dbB = $seqB{$k}.\n" if ($seqA{$k} != $seqB{$k});
  print STDERR "Warning... for $k, pseudogene, $dbA = $pseudoA{$k} NOT EQUAL $dbB = $pseudoB{$k}.\n" if ($pseudoA{$k} != $pseudoB{$k});
}

############

sub getDatabase {
  my ($dbName) = @_;

  $dbName = "dbi:Oracle:" . $dbName;
  print STDERR "\dbName = $dbName.\n";

  my $db = ($dbName)
           ? GUS::ObjRelP::DbiDatabase->new($dbName,
                                        $gusconfig->getDatabaseLogin(),
                                        $gusconfig->getDatabasePassword(),
                                        $verbose,0,1,
                                        $gusconfig->getCoreSchemaName()
                                       )
           : GUS::ObjRelP::DbiDatabase->new($gusconfig->getDbiDsn(),
                                        $gusconfig->getDatabaseLogin(),
                                        $gusconfig->getDatabasePassword(),
                                        $verbose,0,1,
                                        $gusconfig->getCoreSchemaName()
                                       );
  return $db;
}

sub getOrganismList {
  my ($dbName) = @_;
  my (@orgs, %taxonId);
  my $db = getDatabase($dbName);
  my $dbh = $db->getQueryHandle();

  my $sql = "select abbrev from apidb.organism";
  my $stmt = $dbh->prepareAndExecute($sql);
  while ( my ($val) = $stmt->fetchrow_array()) {
    push @orgs, $val;
  }
  $dbh->disconnect();

  return \@orgs;
}

sub getNcbiTaxonId {
  my ($org, $dbh) = @_;

  my $ncbiTaxonId;

  my $sql = "select t.NCBI_TAX_ID from apidb.organism o, SRES.TAXON t
             where o.TAXON_ID=t.TAXON_ID and o.ABBREV like '$org'";
  my $stmt = $dbh->prepareAndExecute($sql);
  while ( my ($val) = $stmt->fetchrow_array()) {
    $ncbiTaxonId = $val;
  }

  print STDERR "For $org, get ncbiTaxonId = $ncbiTaxonId\n";

  return $ncbiTaxonId;
}

sub getSequenceCount {
  my ($ncbiTaxonId, $dbh) = @_;
  my $count;

  my $sql = "select count(*) from APIDBTUNING.GENOMICSEQATTRIBUTES where NCBI_TAX_ID=$ncbiTaxonId and IS_TOP_LEVEL=1";
  my $stmt = $dbh->prepareAndExecute($sql);
  while ( my ($val) = $stmt->fetchrow_array()) {
     $count = $val;
  }

  return $count;
}

sub getGeneFeature {
  my ($ncbiTaxonId, $dbh) = @_;
  my %genes;

  my $sql = "select DISTINCT GENE_TYPE, count(*) from APIDBTUNING.GENEATTRIBUTES where NCBI_TAX_ID=$ncbiTaxonId group by GENE_TYPE";
  my $stmt = $dbh->prepareAndExecute($sql);
  while ( my ($type, $count) = $stmt->fetchrow_array()) {
    $type =~ s/\s*encoding//;
    $genes{$type} = $count;
  }

  return \%genes;
}

sub getPseudoGeneCount {
  my ($ncbiTaxonId, $dbh) = @_;
  my $pseudoCount;

  my $sql = "select count(*) from APIDBTUNING.GENEATTRIBUTES where NCBI_TAX_ID=$ncbiTaxonId and IS_PSEUDO=1";
  my $stmt = $dbh->prepareAndExecute($sql);
  while ( my ($c) = $stmt->fetchrow_array()) {
    $pseudoCount = $c;
  }

  return $pseudoCount;
}

sub usage {
  die
"
A script to compare database A with database B regarding genome and annotation

Usage: perl compareDatabaseForQA.pl --dbA toxo-inc --dbB toxo-rbld --organismList \"tgonME49, ccayNF1_C8\"

where:
  --dbA: required, e.g. inc instance
  --dbB: required, e.g. rbld instance
  --organismList: optional, comma delimited list, e.g. tgonME49, ccayNF1_C8
  --gusConfigFile: optional, default is \$GUS_HOME/config/gus.config

";
}
