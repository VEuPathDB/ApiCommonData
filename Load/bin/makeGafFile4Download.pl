#!/usr/bin/perl

use strict;
use lib "$ENV{GUS_HOME}/lib/perl/";

use DBI;
use DBD::Oracle;
use Getopt::Long;

use CBIL::Util::PropertySet;
use GUS::Community::GeneModelLocations;

#use Bio::Tools::GAF;
use HTTP::Date;

my ($date, ) = split(" ", HTTP::Date::time2iso());
$date = join("",split(/-/,$date));

my ($help, $gusConfigFile, $organismAbbrev, $outputFile);
&GetOptions('help|h' => \$help,
            'gusConfigFile=s' => \$gusConfigFile,
            'organismAbbrev=s' => \$organismAbbrev,
            'outputFile=s' => \$outputFile,
);

##Create db handle
if(!$gusConfigFile) {
  $gusConfigFile = $ENV{GUS_HOME} . "/config/gus.config";
}

&usage("Config file $gusConfigFile does not exist.") unless -e $gusConfigFile;
&usage("Miss required parameter: organismAbbrev.") unless -e $organismAbbrev;

my @properties;
my $gusconfig = CBIL::Util::PropertySet->new($gusConfigFile, \@properties, 1);

my $dbiDsn = $gusconfig->{props}->{dbiDsn};
my $dbiUser = $gusconfig->{props}->{databaseLogin};
my $dbiPswd = $gusconfig->{props}->{databasePassword};

my $dbh = DBI->connect($dbiDsn, $dbiUser, $dbiPswd) or die DBI->errstr;
$dbh->{RaiseError} = 1;
$dbh->{AutoCommit} = 0;

open(my $fhl, ">$outputFile") or die "Cannot open file $outputFile For writing: $!";

my $ncbiTaxonId = getNcbiTaxonIdForOrganism ($dbh, $organismAbbrev);
my $extDbRlsId = getPrimaryExtRlsIdFromOrganismAbbrev ($dbh, $organismAbbrev);
print STDERR "For $organismAbbrev got externalDatabaseRlsId = $extDbRlsId\n";

my $geneIdRef = getGeneIdsForOrganism($dbh, $extDbRlsId);
my $geneNameRef = getGeneNamesForOrganism ($dbh, $extDbRlsId);
my $productRef = getProductNamesForOrganism ($dbh, $extDbRlsId);
my $transcriptTypeRef = getTranscriptTypeForOrganism ($dbh, $extDbRlsId);
my $goRef = getGoInfoFromDbs ($dbh, $extDbRlsId, $ncbiTaxonId, $geneIdRef, $geneNameRef, $productRef, $transcriptTypeRef, $date);

printGoInfo ($fhl, $goRef);

close $fhl;

$dbh->disconnect();

1;

#################
sub getGoInfoFromDbs {
  my ($dbhSub, $extDbRlsId, $taxonId, $idRef, $nameRef, $prodRef, $transTypeRef, $date) = @_;
  my @goInfos;

  ## use apidbtuning.GoTermSummary table to get GO info
  my $sqlSub = "
select GENE_SOURCE_ID, TRANSCRIPT_SOURCE_ID, GO_ID, REFERENCE, EVIDENCE_CODE, GO_TERM_NAME, SOURCE, 
decode(ontology, 'Biological Process', 'P',
                 'Molecular Function', 'F',
                 'Cellular Component', 'C', ontology) 
from apidbtuning.GoTermSummary
";

  my $sqlRefSub = readFromDatabase($dbhSub, $sqlSub);

  foreach my $i (0..$#$sqlRefSub) {
    my ($gSourceId, $tSourceId, $goId, $reference, $evidenceCode, $goTermName, $source, $ontology) = split(/\|/, $sqlRefSub->[$i]);

    next if (!$idRef->{$gSourceId});  ## continue only when the gSourceId is in the queried organism
    ## remove the prefix GO: and GO_
    $goId =~ s/_/:/;  ## change GO_123456 To GO:123456


    $evidenceCode = "IEA" if (!$evidenceCode);  ## default value
    my $geneName = ($nameRef->{$gSourceId}) ? ($nameRef->{$gSourceId}) : "" ;
    my $product = ($prodRef->{$tSourceId}) ? ($prodRef->{$tSourceId}) : "unspecified product";
    my $transType = ($transTypeRef->{$tSourceId}) ? ($transTypeRef->{$tSourceId}) : "gene_product";

    my @items;
    $items[0] = "EuPathDB";
    $items[1] = $gSourceId;                        ## gene source id
    $items[2] = $geneName;                         ## "Symbol"
    $items[3] = "";                                ## Qualifier, optional
    $items[4] = $goId;                             ## GO ID
    $items[5] = $reference;                        ## DB:Reference
    $items[6] = $evidenceCode;                     ## Evidence Code
    $items[7] = "";                                ## With (or) From, optional
    $items[8] = $ontology;                         ## Aspect
    $items[9] = $product;                          ## DB Object Name, productName in EuPathDB
    $items[10] = "";                               ## DB Object Synonym, optional
    $items[11] = $transType;                       ## DB Object Type, eg. protein, tRNA, rRNA, ncRNA ...
    $items[12] = "taxon:$taxonId";                 ## Taxon: taxon:9606
    $items[13] = $date;                            ## Date
    $items[14] = $source;                          ## Assigned By
    $items[15] = "";                               ## Annotation Extension 
    $items[16] = "EuPathDB:$tSourceId";            ## Gene Product Form ID, transcript ID in EuPathDB

    my $value = join ('|', @items);
    push (@goInfos, $value) if ($value);
  }
  return \@goInfos;
}

sub getGeneNamesForOrganism {
  my ($dbhSub, $extRlsId) = @_;
  my %geneNames;

  my $sqlSub = "
select gf.SOURCE_ID, gfn.NAME from apidb.GeneFeatureName gfn, dots.genefeature gf
where gf.NA_FEATURE_ID=gfn.NA_FEATURE_ID and gf.EXTERNAL_DATABASE_RELEASE_ID=$extRlsId

";

  my $sqlRefSub = readFromDatabase($dbhSub, $sqlSub);
  foreach my $i (0..$#$sqlRefSub) {
    my ($id, $name) = split (/\|/, $sqlRefSub->[$i]);
    $geneNames{$id} = $name;
  }
  print STDERR "For externalDatabaseReleaseId $extRlsId, can not find the record in apidb.genefeaturename table\n" if (!$sqlRefSub);
  return \%geneNames;
}

sub getProductNamesForOrganism {
  my ($dbhSub, $extRlsId) = @_;
  my %products;

  my $sqlSub = "
select t.SOURCE_ID, tp.PRODUCT from ApiDB.TranscriptProduct tp, DOTS.TRANSCRIPT t
where t.NA_FEATURE_ID=tp.NA_FEATURE_ID and tp.IS_PREFERRED=1 and t.EXTERNAL_DATABASE_RELEASE_ID=$extRlsId

";

  my $sqlRefSub = readFromDatabase($dbhSub, $sqlSub);
  foreach my $i (0..$#$sqlRefSub) {
    my ($id, $name) = split (/\|/, $sqlRefSub->[$i]);
    $products{$id} = $name;
  }
  print STDERR "For externalDatabaseReleaseId $extRlsId, can not find the record in apidb.transcriptProduct table\n" if (!$sqlRefSub);
  return \%products;
}

sub getTranscriptTypeForOrganism {
  my ($dbhSub, $extRlsId) = @_;
  my %types;

  my $sqlSub = "
select gf.SOURCE_ID as gene_source_id, t.SOURCE_ID trans_source_id, gf.NAME as gene_name 
from dots.genefeature gf, dots.transcript t
where t.PARENT_ID=gf.NA_FEATURE_ID and gf.EXTERNAL_DATABASE_RELEASE_ID=$extRlsId

";

  my $sqlRefSub = readFromDatabase($dbhSub, $sqlSub);
  foreach my $i (0..$#$sqlRefSub) {
    my ($gid, $tid, $value) = split (/\|/, $sqlRefSub->[$i]);
    $value = "transcript" if ($value =~ /coding_gene/); ## make it as transcript if it is coding_gene
    $value =~ s/\_gene//;
    $types{$tid} = $value;
  }
  print STDERR "For externalDatabaseReleaseId $extRlsId, can not find the record in transcript table\n" if (!$sqlRefSub);
  return \%types;
}

sub getGeneIdsForOrganism {
  my ($dbhSub, $extRlsId) = @_;
  my %ids;

  my $sqlSub = "
select SOURCE_ID from dots.genefeature 
where EXTERNAL_DATABASE_RELEASE_ID=$extRlsId

";

  my $sqlRefSub = readFromDatabase($dbhSub, $sqlSub);
  foreach my $i (0..$#$sqlRefSub) {
    $ids{$sqlRefSub->[$i]} = $sqlRefSub->[$i];
  }
  print STDERR "For externalDatabaseReleaseId $extRlsId, can not find the record in geneFeature table\n" if (!$sqlRefSub);
  return \%ids;
}


sub getPrimaryExtRlsIdFromOrganismAbbrev {
  my ($dbhSub, $abbrev) = @_;
  my $extRlsId;

  ## get ncbiTaxonId from organismAbbrev
  my $databaseName = $abbrev . "_primary_genome_RSRC";
  my $sqlSub = "
select edr.external_database_release_id 
from SRES.EXTERNALDATABASE ed, SRES.EXTERNALDATABASERELEASE edr 
where ed.EXTERNAL_DATABASE_ID=edr.EXTERNAL_DATABASE_ID and ed.name like '$databaseName'

";

  my $sqlRefSub = readFromDatabase($dbhSub, $sqlSub);
  $extRlsId = $sqlRefSub->[0] if ($sqlRefSub);

  print STDERR "For $abbrev, can not find the record in externalDatabaseRelease\n" if (!$extRlsId);
  return $extRlsId;
}


sub getNcbiTaxonIdForOrganism {
  my ($dbhSub, $abbrev) = @_;
  my $taxonId;

  ## get ncbiTaxonId from organismAbbrev
  my $sqlSub = "
select t.NCBI_TAX_ID from apidb.organism o, sres.taxon t
where o.TAXON_ID=t.TAXON_ID and o.ABBREV='$abbrev'

";

  my $sqlRefSub = readFromDatabase($dbhSub, $sqlSub);
  $taxonId = $sqlRefSub->[0] if ($sqlRefSub);
  return $taxonId;
}


sub readFromDatabase {
  my ($dbh, $sql) = @_;
  my $stmt = $dbh->prepare($sql);
  $stmt->execute();
  my (@arrays);
  while (my @fetchs = $stmt->fetchrow_array()) {
    my $oneline= join ('|', @fetchs);
    push @arrays, $oneline;
  }
  $stmt->finish();
  return \@arrays;
}

sub printGoInfo {
  my ($fileH, $arrayRef) = @_;

  print $fileH "!gaf-version: 2.1\n";

  foreach my $j (0..$#$arrayRef) {
    my @items = split (/\|/, $arrayRef->[$j]);
    foreach my $i (0..16) {
      ($i == 16) ? $fileH->print ("$items[$i]\n") : $fileH->print ("$items[$i]\t");
    }
  }
  return $fileH;
}

sub usage {
  die
"
A script to make a GAF download file
Usage:
      makeGafFile4Download.pl --organismAbbrev pknoH --outputFile pknoH.gaf

NOTE: the GUS_HOME should point to the instance that the GO association has been loaded

where
  --organismAbbrev: the organism Abbrev in the table apidb.organism
  --outputFile: the name of the output .gaf file
  --optionalTaxonId: only required in case the taxonId is not available in ncbi Taxonomy
";
}
