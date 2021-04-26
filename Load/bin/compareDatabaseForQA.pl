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
my (%fullNameA, %fullNameB);

## query dbA
foreach my $org (@orgs) {

  my $db = getDatabase($dbA);
  my $dbh = $db->getQueryHandle();

  my $ncbiTaxonId = getNcbiTaxonId ($org, $dbh);
  #print STDERR "For $org, at $dbA, get ncbiTaxonId = $ncbiTaxonId\n";

  if ($ncbiTaxonId) {
    $fullNameA{$org} = getOrganismFullName ($org, $dbh);
    $seqA{$org} = getSequenceSummary ($ncbiTaxonId, $dbh);
    $geneA{$org} = ($useDotsTable =~ /^y/i) ? getGeneFeatureFromDotsTable ($ncbiTaxonId, $dbh) : getGeneFeatureFromTuningTable ($ncbiTaxonId, $dbh);
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
    $fullNameB{$org} = getOrganismFullName ($org, $dbh);
    $seqB{$org} = getSequenceSummary ($ncbiTaxonId, $dbh);
    $geneB{$org} = ($useDotsTable =~ /^y/i) ? getGeneFeatureFromDotsTable ($ncbiTaxonId, $dbh) : getGeneFeatureFromTuningTable ($ncbiTaxonId, $dbh);
  }

  $dbh->disconnect();
}

foreach my $k (sort keys %seqA) {

  ## 1. check if organism available in $dbB
  if (!$seqB{$k}) {
    print STDERR "WARNING ... $k only available in $dbA, but not in $dbB\n";
    next;
  }

  ## 1.2 check if organism full Name changed
  if ($fullNameA{$k} ne $fullNameB{$k}) {
    print STDERR "WARNING ... organism full name changed. '$fullNameB{$k}' in $dbB, '$fullNameA{$k}' in $dbA\n";
  }

  ## 2. check if the total number of sequence is same
  print STDERR "\n";
  print STDERR "$k in $dbA\n";
  my ($seqACount, $seqBCount);
  foreach my $ks (sort keys %{$seqA{$k}}) {
    print STDERR "ERROR ... loaded sequences, in $dbA $ks = $seqA{$k}{$ks}, in $dbB $ks = $seqB{$k}{$ks}\n" if ($seqA{$k}{$ks} != $seqB{$k}{$ks});
    $seqACount += $seqA{$k}{$ks};
  }
  print STDERR "  sequence number = $seqACount\n";

  ## 3. check the total number of gene feature
  foreach my $kk (sort keys %{$geneA{$k}}) {
    print STDERR "    $kk = $geneA{$k}->{$kk}\n";
  }

  print STDERR "$k in $dbB\n";
  foreach my $ks (sort keys %{$seqB{$k}}) {
    $seqBCount += $seqB{$k}{$ks};
  }
  print STDERR "  sequence number = $seqBCount\n";
  foreach my $kk (sort keys %{$geneB{$k}}) {
    print STDERR "    $kk = $geneB{$k}->{$kk}\n";
  }

  foreach my $t ("protein coding", "rRNA", "snRNA", "snoRNA", "tRNA", "snRNA", "scRNA", "miRNA", "RNase_P_RNA",
		 "ncRNA",
                 "RNase_MRP_RNA", "antisense_RNA", "telomerase_RNA", "SRP_RNA", "misc_RNA") {
    my $aTotal = ($t eq "protein coding") ? $geneA{$k}->{"$t"} + $geneA{$k}->{"pseudogene"} : $geneA{$k}->{$t};
    my $bTotal = ($t eq "protein coding") ? $geneB{$k}->{"$t"} + $geneB{$k}->{"pseudogene"} : $geneB{$k}->{$t};
    print STDERR "ERROR ... for $k, '$t' in $dbA = $aTotal NOT EQUAL $dbB = $bTotal.\n" if ($aTotal != $bTotal);
  }
}

############

sub getDatabase {
  my ($dbName) = @_;

  $dbName = "dbi:Oracle:" . $dbName;
  #print STDERR "\dbName = $dbName.\n";

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

sub getOrganismFullName {
  my ($org, $dbh) = @_;

  my $fullName;

  my $sql = "select tn.NAME from apidb.organism o, SRES.TAXON t, SRES.TAXONNAME tn
             where o.TAXON_ID=t.TAXON_ID and t.TAXON_ID=tn.TAXON_ID and o.ABBREV like '$org'
             and tn.NAME_CLASS like 'scientific name'";

  my $stmt = $dbh->prepareAndExecute($sql);
  while ( my ($val) = $stmt->fetchrow_array()) {
    $fullName = $val;
  }

  return $fullName;
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

sub getSequenceSummary {
  my ($ncbiTaxonId, $dbh) = @_;

  my %seqSum;
  my $sql = "select DISTINCT SEQUENCE_ONTOLOGY_ID, count(*)  from APIDBTUNING.GENOMICSEQATTRIBUTES where NCBI_TAX_ID=$ncbiTaxonId and IS_TOP_LEVEL=1
             group by SEQUENCE_ONTOLOGY_ID";

  my $stmt = $dbh->prepareAndExecute($sql);
  while ( my ($so, $val) = $stmt->fetchrow_array()) {
    my $type = getSequenceTypeFromSO($so, $dbh);
     $seqSum{$type} = $val;
  }
  $stmt->finish();

  return \%seqSum;
}

sub getSequenceTypeFromSO {
  my ($soTerm, $dbh) = @_;

  my $name;
  my $sql = "select name from SRES.ONTOLOGYTERM where ONTOLOGY_TERM_ID=$soTerm";

  my $stmt = $dbh->prepareAndExecute($sql);
  while ( my ($val) = $stmt->fetchrow_array()) {
    $name = $val;
  }
  $stmt->finish();
  return $name;
}


sub getGeneFeatureFromTuningTable {
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
	|| $type =~ /nontranslating_CDS/
	|| $type eq "TEC"
	|| $type eq "TR_C"
	|| $type eq "TR_D"
	|| $type eq "TR_J"
	|| $type eq "TR_V"
	|| $type eq "IG_C"
	|| $type eq "IG_D"
	|| $type eq "IG_J"
	|| $type eq "IG_LV"
	|| $type eq "IG_V"
        || $type =~ /coding/) {
      $type = "protein coding";
    } elsif ($type eq "pseudogene"
        || $type eq "processed_pseudogene"
        || $type eq "transcribed_processed_pseudogene"
        || $type eq "transcribed_unprocessed_pseudogene"
        || $type eq "transcribed_unitary_pseudogene"
        || $type eq "translated_processed_pseudogene"
        || $type eq "translated_unprocessed_pseudogene"
        || $type eq "polymorphic_pseudogene"
        || $type eq "unitary_pseudogene"
        || $type eq "IG_C_pseudogene"
        || $type eq "IG_D_pseudogene"
        || $type eq "IG_J_pseudogene"
        || $type eq "IG_V_pseudogene"
        || $type eq "IG_pseudogene"
        || $type eq "TR_J_pseudogene"
        || $type eq "TR_V_pseudogene"
        || $type eq "unprocessed_pseudogene"
        || $type eq "pseudogene_with_CDS") {
      $type = "pseudogene";
    } elsif ($type eq "tRNA_pseudogene") {
      $type = "tRNA";
    } elsif ($type eq "rRNA_pseudogene") {
      $type = "rRNA";
    } elsif ($type eq "ribozyme") {
      $type = "ncRNA";
    } elsif ($type eq "sense_intronic"
        || $type eq "sense_overlapping"
        || $type eq "processed_transcript"
        || $type eq "antisense" ) {
      $type = "misc_RNA";
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
