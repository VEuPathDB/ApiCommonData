#!/usr/bin/perl

use strict;
use JSON;
use Getopt::Long;
use GUS::Model::SRes::Taxon;
use GUS::Model::SRes::TaxonName;
use GUS::Supported::GusConfig;


## TODO, better to ignore null record

my ($genomeSummaryFile, $organismAbbrev, $gusConfigFile, $outputFileName, $help);

&GetOptions('organismAbbrev=s' => \$organismAbbrev,
            'gusConfigFile=s' => \$gusConfigFile,
            'outputFileName=s' => \$outputFileName,
            'help|h' => \$help
            );

&usage() if ($help);
&usage("Missing a Required Argument") unless (defined $organismAbbrev);


$gusConfigFile = "$ENV{GUS_HOME}/config/gus.config" unless ($gusConfigFile);
my $verbose;
my $gusconfig = GUS::Supported::GusConfig->new($gusConfigFile);

my $db = GUS::ObjRelP::DbiDatabase->new($gusconfig->getDbiDsn(),
                                        $gusconfig->getDatabaseLogin(),
                                        $gusconfig->getDatabasePassword(),
                                        $verbose,0,1,
                                        $gusconfig->getCoreSchemaName()
                                       );
my $dbh = $db->getQueryHandle();

my $outputFileName = $organismAbbrev . "_functional_annotation.json" unless($outputFileName);
open (OUT, ">$outputFileName") || die "cannot open $outputFileName file to write.\n";

my %dbxrefs;

my $geneIdHash = getGeneFeatureSourceId($organismAbbrev);
my $uniprotHash = getDbxRefs($organismAbbrev, "UniProt");
my $entrezGeneHash = getDbxRefs($organismAbbrev, "EntrezGene");

foreach my $k (sort keys %{$geneIdHash}) {

  if ($entrezGeneHash->{$k}) {
    my %dbxrefEG = (
		  'id' => $entrezGeneHash->{$k},
		  'dbname' => "EntrezGene"
		  );
    push @{$dbxrefs{$k}}, \%dbxrefEG;
  }

  if ($uniprotHash->{$k}) {
    my %dbxref = (
		  'id' => $uniprotHash->{$k},
		  'dbname' => "UniProt"
		 );

    push @{$dbxrefs{$k}}, \%dbxref;
  }
}

my $extDbRlsId = getExtDbRlsIdFormOrgAbbrev ($organismAbbrev);

my $sql = "select gf.SOURCE_ID, t.SOURCE_ID, tp.product,
             tp.IS_PREFERRED, tp.PUBLICATION, tp.EVIDENCE_CODE, tp.WITH_FROM
             from dots.genefeature gf, dots.transcript t, ApiDB.TranscriptProduct tp
             where gf.NA_FEATURE_ID=t.PARENT_ID and t.NA_FEATURE_ID=tp.NA_FEATURE_ID
             and t.EXTERNAL_DATABASE_RELEASE_ID=$extDbRlsId";

my $stmt = $dbh->prepareAndExecute($sql);

my (@functAnnotInfos, $c);

while (my ($gSourceId, $tSourceId, $product, $isPreferred, $publication, $evidencdCode, $withFrom)
	 = $stmt->fetchrow_array()) {

  my %functAnnot = (
		 'object_type' => "gene",
		 'id' => $gSourceId,
		 'transcripts' => {
				  'id' => $tSourceId,
				  'description' => {
						    'description' => $product,
						    'isPreferred' => $isPreferred,
						    }
				 },
		 );

  $functAnnot{transcripts}{description}{publication} = $publication if ($publication);
  $functAnnot{transcripts}{description}{evidencdCode} = $evidencdCode if ($evidencdCode);
  $functAnnot{transcripts}{description}{withFrom} = $withFrom if ($withFrom);
  $functAnnot{xrefs} = \@{$dbxrefs{$gSourceId}} if ($dbxrefs{$gSourceId});

  push @functAnnotInfos, \%functAnnot;

  $c++;
#  last if ($c == 2);
}

$stmt->finish();

my $json = encode_json(\@functAnnotInfos);

print OUT "$json\n";

#print "]";

close OUT;

$dbh->disconnect();

###########

sub getDbxRefs {
  my ($orgnaismAbbrev, $name) = @_;

  my %dbxrefs;
  my $dbName;
  if ($name =~ /uniprot/i) {
    $dbName = $orgnaismAbbrev. "_dbxref_gene2Uniprot_RSRC";
  } elsif ($name =~ /entrezgene/i) {
    $dbName = $orgnaismAbbrev. "_dbxref_gene2Entrez_RSRC";
  } else {
    die "dbxref db name has not been configured yet\n";
  }

  my $dbRlsId = getExtDbRlsIdFromExtDbName($dbName);

  my $sql = "select gf.SOURCE_ID, df.PRIMARY_IDENTIFIER
             from dots.genefeature gf, DOTS.DBREFNAFEATURE dnf, SRES.DBREF df,
             SRES.EXTERNALDATABASERELEASE edr
             where gf.NA_FEATURE_ID=dnf.NA_FEATURE_ID and dnf.DB_REF_ID=df.DB_REF_ID
             and df.EXTERNAL_DATABASE_RELEASE_ID=$dbRlsId";

  my $stmt = $dbh->prepareAndExecute($sql);
  while (my ($sourceId, $dbxref) = $stmt->fetchrow_array()) {
    $dbxrefs{$sourceId}= $dbxref;
  }
  $stmt->finish();

  return \%dbxrefs;
}

sub getProductName {
  my ($orgnaismAbbrev) = @_;

  my @productInfo;

  my $extDbRlsId = getExtDbRlsIdFormOrgAbbrev ($orgnaismAbbrev);

  my $sql = "select gf.SOURCE_ID, t.SOURCE_ID, tp.product, 
             tp.IS_PREFERRED, tp.PUBLICATION, tp.EVIDENCE_CODE, tp.WITH_FROM
             from dots.genefeature gf, dots.transcript t, ApiDB.TranscriptProduct tp
             where gf.NA_FEATURE_ID=t.PARENT_ID and t.NA_FEATURE_ID=tp.NA_FEATURE_ID
             and t.EXTERNAL_DATABASE_RELEASE_ID=$extDbRlsId";

  my $stmt = $dbh->prepareAndExecute($sql);

  while (my ($gSourceId, $tSourceId, $product, $isPreferred, $publication, $evidencdCode, $withFrom)
             = $stmt->fetchrow_array()) {
    push @productInfo, "$gSourceId, $tSourceId, $product, $isPreferred, $publication, $evidencdCode, $withFrom";

  }
  $stmt->finish();

  return \@productInfo;
}

sub getGeneFeatureSourceId {
  my ($abbrev) = @_;

  my %sourceIds;

  my $extDbRlsId = getExtDbRlsIdFormOrgAbbrev ($abbrev);
  my $sql = "select source_id from dots.genefeature where EXTERNAL_DATABASE_RELEASE_ID=$extDbRlsId";

  my $stmt = $dbh->prepareAndExecute($sql);

  while (my ($sourceId) = $stmt->fetchrow_array()) {
    $sourceIds{$sourceId} = $sourceId;
  }

  return \%sourceIds;
}

sub getExtDbRlsIdFormOrgAbbrev {
  my ($abbrev) = @_;

  my $extDb = $abbrev. "_primary_genome_RSRC";

  my $extDbRls = getExtDbRlsIdFromExtDbName ($extDb);

  return $extDbRls;
}

sub getExtDbRlsIdFromExtDbName {
  my ($extDbRlsName) = @_;

  my $sql = "select edr.external_database_release_id
             from sres.externaldatabaserelease edr, sres.externaldatabase ed
             where ed.name = '$extDbRlsName'
             and edr.external_database_id = ed.external_database_id";
  my $stmt = $dbh->prepareAndExecute($sql);
  my @rlsIdArray;

  while ( my($extDbRlsId) = $stmt->fetchrow_array()) {
      push @rlsIdArray, $extDbRlsId;
  }

  die "No extDbRlsId found for '$extDbRlsName'" unless(scalar(@rlsIdArray) > 0);
  die "trying to find unique extDbRlsId for '$extDbRlsName', but more than one found" if(scalar(@rlsIdArray) > 1);

  return @rlsIdArray[0];
}



sub usage {
  die
"
A script to generate functional_annotation.json file that required by EBI

Usage: perl bin/generateFunctionalAnnotationJson.pl --organismAbbrev pfal3D7 --gusConfigFile \$GUS_HOME/config/gus.config

where:
  --organismAbbrev: required, eg. pfal3D7
  --outputFileName: optional, default is organismAbbrev_genome.json
  --gusConfigFile: optional, default is \$GUS_HOME/config/gus.config

";
}
