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

my ($help, $gusConfigFile, $organismAbbrev, $outputFile, $tuningTablePrefix);
&GetOptions('help|h' => \$help,
            'gusConfigFile=s' => \$gusConfigFile,
            'organismAbbrev=s' => \$organismAbbrev,
            'tuningTablePrefix=s' => \$tuningTablePrefix,
            'outputFile=s' => \$outputFile,
);

##Create db handle
if(!$gusConfigFile) {
  $gusConfigFile = $ENV{GUS_HOME} . "/config/gus.config";
}

&usage("Config file $gusConfigFile does not exist.") unless -e $gusConfigFile;
&usage("Miss required parameter: organismAbbrev.") unless ($organismAbbrev);

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
my $transcriptTypeRef = getTranscriptTypeForOrganism ($dbh, $extDbRlsId);

my $geneNameRef = getGeneNamesForOrganism ($dbh, $extDbRlsId);
my $productRef = getProductNamesForOrganism ($dbh, $extDbRlsId);
my $synonymRef = getSynonymsForOrganism ($dbh, $organismAbbrev);

my $goRef = getGoInfoFromDbs ($dbh, $extDbRlsId, $ncbiTaxonId, $geneIdRef, $geneNameRef, $productRef, $synonymRef, $transcriptTypeRef, $date, $tuningTablePrefix);

printGoInfo ($fhl, $goRef);

close $fhl;

$dbh->disconnect();

1;

#################
sub getGoInfoFromDbs {
  my ($dbhSub, $extDbRlsId, $taxonId, $idRef, $nameRef, $prodRef, $synonRef, $transTypeRef, $date, $tuningTablePrefix) = @_;
  my @goInfos;

  ## use apidbtuning.GoTermSummary table to get GO info- JP changed to GeneGoTerms to match gene pages - only those go terms assigned, not the linked hierarchy 
  my $sqlSub = "
select GENE_SOURCE_ID, TRANSCRIPT_SOURCE_ID, IS_NOT, GO_ID, REFERENCE, EVIDENCE_CODE, GO_TERM_NAME, SOURCE, EVIDENCE_CODE_PARAMETER, 
decode(ontology, 'Biological Process', 'P',
                 'Molecular Function', 'F',
                 'Cellular Component', 'C', ontology) 
from apidbtuning.${tuningTablePrefix}GeneGoTerms
";

  my $sqlRefSub = readFromDatabase($dbhSub, $sqlSub);
  print STDERR "the total number of GeneGoTerms is $#$sqlRefSub\n";

  foreach my $i (0..$#$sqlRefSub) {
    my ($gSourceId, $tSourceId, $isNot, $goId, $reference, $evidenceCode, $goTermName, $source, $eviCodeParameter, $ontology) = split(/\|/, $sqlRefSub->[$i]);

    next if (!$idRef->{$gSourceId});  ## continue only when the gSourceId is in the queried organism
    next if (!$goId);
    next if (!$ontology);
    next if ($goId =~ /^BFO:/);  ## skip BFO: for now

    ## change GO_123456 To GO:123456
    $goId =~ s/_/:/g;

    ## remove the prefix GO:
    $goId =~ s/GO:GO:/GO:/;

    $evidenceCode = "IEA" if (!$evidenceCode);  ## default value
    my $geneName = ($nameRef->{$gSourceId}) ? ($nameRef->{$gSourceId}) : "$gSourceId";   ## if not available use gSourceId because it is required
    my $product = ($prodRef->{$tSourceId}) ? ($prodRef->{$tSourceId}) : "unspecified product";
    my $synonym = ($synonRef->{$gSourceId}) ? ($synonRef->{$gSourceId}) : "";
    #$synonym =~ s/\,/\|/g;  ## in the line 148, all goInfos will be assigned to a string separated by "|", so delay the change until subroutine printGoInfo
    #print STDERR "\$synonym = $synonym;\n" if ($gSourceId eq "TcCLB.509179.100");

    my $transType = ($transTypeRef->{$tSourceId}) ? ($transTypeRef->{$tSourceId}) : "gene_product";

    $reference = "VEuPathDB:".$gSourceId if (!$reference);

    $source = "VEuPathDB" if (!$source);
    $source =~ s/Interpro/InterPro/g;
    $reference = "GO_REF:0000002" if ($source =~ /InterPro/i);  ## required by Achchuthan
                                                                ## https://www.ebi.ac.uk/GOA/InterPro2GO
    $source = "VEuPathDB" if ($source =~ /InterPro/);  ## required by Achchuthan

    my $withOrFrom = $eviCodeParameter;  ## required by Achchuthan
    #if ($evidenceCode eq "IEA") {  ## is $eviCodeParameter if $evidenceCode eq "IEA"
    #  $withOrFrom = $eviCodeParameter;
    #} elsif ($evidenceCode eq "IPI" || $evidenceCode eq "ISS") {
    #  $withOrFrom = $gSourceId;
    #} elsif ($evidenceCode eq "EXP" || $evidenceCode eq "IDA" || $evidenceCode eq "IEP"
    #         || $evidenceCode eq "TAS" || $evidenceCode eq "NAS" || $evidenceCode eq "ND") {
    #  $withOrFrom = "";
    #} else {
    #  $withOrFrom = $eviCodeParameter;
    #}

    my @items;
    $items[0] = "VEuPathDB";
    $items[1] = $gSourceId;                        ## gene source id
    $items[2] = $geneName;                         ## "Symbol"
    $items[3] = uc($isNot);                        ## Qualifier, optional
    $items[4] = $goId;                             ## GO ID
    $items[5] = $reference;                        ## DB:Reference
    $items[6] = $evidenceCode;                     ## Evidence Code
    $items[7] = $withOrFrom;                       ## With (or) From, optional, Can be evidence_code_parameter in VEuPathDB
    $items[8] = $ontology;                         ## Aspect
    $items[9] = $product;                          ## DB Object Name, productName in VEuPathDB
    $items[10] = $synonym;                         ## DB Object Synonym, optional
    $items[11] = $transType;                       ## DB Object Type, eg. protein, tRNA, rRNA, ncRNA ...
    $items[12] = "taxon:$taxonId";                 ## Taxon: taxon:9606
    $items[13] = $date;                            ## Date
    $items[14] = $source;                          ## Assigned By
    $items[15] = "";                               ## Annotation Extension 
    $items[16] = "";                               ## Gene Product Form ID

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

sub getSynonymsForOrganism {
  my ($dbhSub, $abbrev) = @_;
  my %synonyms;

  my $dbName = $abbrev. "_dbxref_%_synonym_RSRC";
  my $sqlSub = "
select gf.SOURCE_ID, df.PRIMARY_IDENTIFIER, ed.NAME 
from dots.genefeature gf, sres.dbref df, dots.dbrefnafeature dfnf, SRES.EXTERNALDATABASE ed, SRES.EXTERNALDATABASERELEASE edr
where gf.NA_FEATURE_ID=dfnf.NA_FEATURE_ID and dfnf.DB_REF_ID=df.DB_REF_ID 
and df.EXTERNAL_DATABASE_RELEASE_ID=edr.EXTERNAL_DATABASE_RELEASE_ID 
and edr.EXTERNAL_DATABASE_ID=ed.EXTERNAL_DATABASE_ID 
and ed.NAME like '$dbName'

";

  my $sqlRefSub = readFromDatabase($dbhSub, $sqlSub);
  foreach my $i (0..$#$sqlRefSub) {
    my ($id, $name) = split (/\|/, $sqlRefSub->[$i]);
    $synonyms{$id} = ($synonyms{$id}) ? ($synonyms{$id}.",".$name) : $name;
  }
  print STDERR "For $abbrev, can not find records in synonym table\n" if (!$sqlRefSub);
  return \%synonyms;
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
    foreach my $i (0..$#fetchs) {
      $fetchs[$i] =~ s/\|/\,/g;
    }
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
      $items[10] =~ s/\,/\|/g; ## column 11, synomys needs to be separated by "|"
      $items[5] =~ s/\,/\|/g; ## column 5, pmid needs to be separated by "|";
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
  --tuningTablePrefix: the letter 'P' following by the organism_id in the apidb.organism table, eg P101_
  --optionalTaxonId: only required in case the taxonId is not available in ncbi Taxonomy
";
}
