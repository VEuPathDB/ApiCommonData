#!/usr/bin/perl

use strict;
use Getopt::Long;
use GUS::Model::SRes::Taxon;
use GUS::Model::SRes::TaxonName;
use GUS::Supported::GusConfig;


my ($dbA, $dbB, $gusConfigFile, $organismList, $useDotsTable, $help);

&GetOptions(
            'dbA=s' => \$dbA,
            'dbB=s' => \$dbB,
            'organismList=s' => \$organismList,
            'gusConfigFile=s' => \$gusConfigFile,
            'useDotsTable=s' => \$useDotsTable,
            'help|h' => \$help
            );

&usage() if ($help);
&usage("Missing a Required Argument") unless (defined $dbA && $dbB);

$gusConfigFile = "$ENV{GUS_HOME}/config/gus.config" unless ($gusConfigFile);

my $verbose;
my $gusconfig = GUS::Supported::GusConfig->new($gusConfigFile);

#my $test = $gusconfig->getDbiDsn();
#print STDERR "The test db is $test.\n";

my @orgs = ($organismList) ? split (/\,\s*/, $organismList) : @{getOrganismList($dbA)};

my (%seqA, %geneA, %pseudoA, %seqB, %geneB, %pseudoB);

## query dbA
foreach my $org (@orgs) {

  my $db = getDatabase($dbA);
  my $dbh = $db->getQueryHandle();

  my $ncbiTaxonId = getNcbiTaxonId ($org, $dbh);
  #print STDERR "For $org, at $dbA, get ncbiTaxonId = $ncbiTaxonId\n";

  if ($ncbiTaxonId) {
    $seqA{$org} = getSequenceCount ($ncbiTaxonId, $dbh);
    $geneA{$org} = ($useDotsTable =~ /^y/i) ? getGeneFeatureFromDotsTable ($ncbiTaxonId, $dbh) : getGeneFeature ($ncbiTaxonId, $dbh);
  }

  $dbh->disconnect();
}

## query dbB
foreach my $org(@orgs) {
  my $db = getDatabase($dbB);
  my $dbh = $db->getQueryHandle();

  my $ncbiTaxonId = getNcbiTaxonId ($org, $dbh);
  #print STDERR "For $org, at $dbB, get ncbiTaxonId = $ncbiTaxonId\n";

  if ($ncbiTaxonId) {
    $seqB{$org} = getSequenceCount ($ncbiTaxonId, $dbh);
    $geneB{$org} = ($useDotsTable =~ /^y/i) ? getGeneFeatureFromDotsTable ($ncbiTaxonId, $dbh) : getGeneFeature ($ncbiTaxonId, $dbh);
  }

  $dbh->disconnect();
}

foreach my $k (sort keys %seqA) {

  ## 1. check if organism available in $dbB
  if (!$seqB{$k}) {
    print STDERR "ERROR ... $k only available in $dbA, but not in $dbB\n";
    next;
  }

  ## 2. check if the total number of sequence is same
  print STDERR "\n";
  print STDERR "$k in $dbA\n";
  print STDERR "  sequence number = $seqA{$k}\n";
  print STDERR "ERROR ... for $k, sequence number, $dbA = $seqA{$k}, NOT EQUAL $dbB = $seqB{$k}.\n" if ($seqA{$k} != $seqB{$k});

  ## 3. check the total number of gene feature
  foreach my $kk (sort keys %{$geneA{$k}}) {
    print STDERR "    $kk = $geneA{$k}->{$kk}\n";
  }

  print STDERR "$k in $dbB\n";
  print STDERR "  sequence number = $seqB{$k}\n";
  foreach my $kk (sort keys %{$geneB{$k}}) {
    print STDERR "    $kk = $geneB{$k}->{$kk}\n";
  }

  foreach my $t ("protein coding", "rRNA", "snRNA", "snoRNA", "", "tRNA") {
    my $aTotal = ($t eq "protein coding") ? $geneA{$k}->{"$t"} + $geneA{$k}->{"pseudogene"} : $geneA{$k}->{$t};
    my $bTotal = ($t eq "protein coding") ? $geneB{$k}->{"$t"} + $geneB{$k}->{"pseudogene"} : $geneB{$k}->{$t};
    print STDERR "ERROR ... for $k, '$t' in $dbA = $aTotal NOT EQUAL $dbB = $bTotal.\n" if ($aTotal != $bTotal);
  }
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
    $type =~ s/\s+encoding//;
    $type =~ s/\s+gene$//;
    if ($type =~ /protein coding/) {
      $type = "protein coding";
    }
    $genes{$type} = $count;
  }

  return \%genes;
}

sub getGeneFeatureFromDotsTable {
  my ($ncbiTaxonId, $dbh) = @_;
  my (%genes, $abbrev, $edrId);

  my $sql1 = "select o.ABBREV from SRES.TAXON t, APIDB.ORGANISM o
              where o.TAXON_ID=t.TAXON_ID and t.NCBI_TAX_ID=$ncbiTaxonId";

  my $stmt1 = $dbh->prepareAndExecute($sql1);
  while (my ($value) = $stmt1->fetchrow_array()) {
    $abbrev = $value;
  }

  my $extDbName = $abbrev . "_primary_genome_RSRC";

  my $sql2 = "select edr.EXTERNAL_DATABASE_RELEASE_ID from SRES.EXTERNALDATABASE ed, SRES.EXTERNALDATABASERELEASE edr
              where ed.EXTERNAL_DATABASE_ID=edr.EXTERNAL_DATABASE_ID and ed.name like '$extDbName'";
  my $stmt2 = $dbh->prepareAndExecute($sql2);
  while (my ($value) = $stmt2->fetchrow_array()) {
    $edrId = $value;
  }

  my $sql = "select DISTINCT name, count(*) from dots.genefeature where EXTERNAL_DATABASE_RELEASE_ID=$edrId group by name";
  my $stmt = $dbh->prepareAndExecute($sql);
  while ( my ($type, $count) = $stmt->fetchrow_array()) {
#    print STDERR "in $extDbName, $type, $count\n";
    $type =~ s/\_gene$//;
    $type =~ s/\s+gene$//;
    if ($type =~ /protein_coding/
        || $type =~ /coding/) {
      $type = "protein coding";
    } elsif ($type =~ /pseudogene/i || $type =~ /pseudogene_with_CDS/i) {
      $type = "pseudogene";
    } elsif ($type =~ /RNA$/i) {
    } else {
      print STDERR "ERROR: \$type = $type has not been configured yet\n";
    }

    $genes{$type} += $count;
  }

  return \%genes;
}

sub usage {
  die
"
A script to compare database A with database B regarding genome and annotation

Usage: perl compareDatabaseForQA.pl --dbA toxo-inc --dbB toxo-rbld --organismList 'tgonME49, ccayNF1_C8' --useDotsTable y

where:
  --dbA: required, e.g. inc instance
  --dbB: required, e.g. rbld instance
  --organismList: optional, comma delimited list, e.g. tgonME49, ccayNF1_C8
  --useDotsTable: optional, Yes|yes|Y|y|No|no|N|n, use DoTS.genefeature table instead of apidbtuning tables for gene features
  --gusConfigFile: optional, default is \$GUS_HOME/config/gus.config

";
}
