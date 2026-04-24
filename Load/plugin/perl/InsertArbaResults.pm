package ApiCommonData::Load::Plugin::InsertArbaResults;

@ISA = qw(GUS::PluginMgr::Plugin);

use GUS::PluginMgr::Plugin;
use GUS::Model::DoTS::GeneFeature;
use GUS::Model::DoTS::Transcript;
use GUS::Model::ApiDB::GeneFeatureProduct;
use GUS::Model::ApiDB::TranscriptProduct;
use GUS::Model::SRes::ExternalDatabase;
use GUS::Model::SRes::ExternalDatabaseRelease;
use GUS::Supported::Util;
use GUS::Model::ApiDB::Organism;
use GUS::Model::SRes::OntologyTerm;
use GUS::Supported::OntologyLookup;

use strict;

# ----------------------------------------------------------------------
my $argsDeclaration =
  [
   fileArg({name           => 'resultsFile',
            descr          => 'file for the sample data',
            reqd           => 1,
            mustExist      => 1,
            format         => '',
            constraintFunc => undef,
            isList         => 0, }),

   stringArg({name           => 'ncbiTaxId',
              descr          => 'NCBI Taxon Id of Organism',
              reqd           => 1,
              constraintFunc => undef,
              isList         => 0, }),

   stringArg({name           => 'organismAbbrev',
              descr          => 'Organism Abbreviation',
              reqd           => 1,
              constraintFunc => undef,
              isList         => 0, }),

   stringArg({name           => 'extDbRlsSpec',
              descr          => 'externaldatabase spec to use',
              constraintFunc => undef,
              reqd           => 1,
              isList         => 0, }),
  ];

my $documentation = { purpose          => "",
                      purposeBrief     => "",
                      notes            => "",
                      tablesAffected   => "",
                      tablesDependedOn => "",
                      howToRestart     => "",
                      failureCases     => "" };

# ----------------------------------------------------------------------

sub new {
  my ($class) = @_;
  my $self = {};
  bless($self, $class);

  $self->initialize({ requiredDbVersion => 4.0,
                      cvsRevision       => '$Revision$',
                      name              => ref($self),
                      argsDeclaration   => $argsDeclaration,
                      documentation     => $documentation });

  return $self;
}

# ======================================================================

sub run {
  my $self = shift;

  my $dbh = $self->getQueryHandle();

  my $fileName       = $self->getArg('resultsFile');
  my $organismAbbrev = $self->getArg('organismAbbrev');
  my $taxonId        = $self->getArg('ncbiTaxId');

  my $organismInfo = GUS::Model::ApiDB::Organism->new({'abbrev' => $organismAbbrev});
  $organismInfo->retrieveFromDB();
  my $projectId = $organismInfo->getRowProjectId();

  my $externalDatabaseSpec = $self->getArg('extDbRlsSpec');
  my $dbRlsId = $self->getExtDbRlsId("$externalDatabaseSpec");

  my %proteinToGene;

  my $sourceSql = "select geneId, proteinId from (select gf.source_id as geneId, aas.source_id as proteinId, rank() over (partition by gf.source_id order by aas.length desc) as rnk from dots.genefeature gf, dots.transcript t, dots.translatedaafeature taf, dots.translatedaasequence aas where t.parent_id = gf.na_feature_id and t.na_feature_id = taf.na_feature_id and gf.external_database_release_id = '$dbRlsId' and taf.aa_sequence_id = aas.aa_sequence_id) ranked where rnk = 1";
  my $stmt = $dbh->prepareAndExecute($sourceSql);
  while (my ($geneId, $proteinId) = $stmt->fetchrow_array()) {
    $proteinToGene{$proteinId} = $geneId;
  }

  my %allProteins;

  my $allProteinsSql = "select aas.source_id from dots.translatedaasequence aas, dots.translatedaafeature taf, dots.transcript t, dots.genefeature gf where aas.aa_sequence_id = taf.aa_sequence_id and taf.na_feature_id = t.na_feature_id and t.parent_id = gf.na_feature_id and gf.external_database_release_id = '$dbRlsId'";
  my $allProteinsStmt = $dbh->prepareAndExecute($allProteinsSql);
  while (my ($proteinId) = $allProteinsStmt->fetchrow_array()) {
    $allProteins{$proteinId} = 1;
  }

  my $processed;
  my $totalNum;

  my $sourceIdMap = $self->getSourceIdToFeatureInfoMap($organismAbbrev, $dbh);

  open(my $data, '<', $fileName) || die "Could not open file $fileName: $!";
  while (my $line = <$data>) {
    chomp $line;

    # Example line
    # PF3D7_0100300.1-p1	acidic terminal segments, variant surface antigen of PfEMP1 | Duffy-binding-like domain, C-terminal subdomain | Duffy binding domain | N-terminal segments of PfEMP1 | domain-containing protein	1		IEA	Pfam:PF15445,PF22672,PF05424,PF15447	VEuPathDB
    my ($proteinSourceId, $description, $one, $empty, $iea, $source, $veupathdb) = split(/\t/, $line);

    $source =~ s/^Pfam://;
    $source =~ s/ //;

    unless ($allProteins{$proteinSourceId}) {
      $self->log("WARNING", "protein '$proteinSourceId' from results file not found in dots.translatedaasequence");
    }

    my $geneSourceId = $proteinToGene{$proteinSourceId};

    next unless $geneSourceId;

    $totalNum++;

    if ($sourceIdMap->{'GeneFeature'}->{$geneSourceId}) {
      my $nafeatureId      = $sourceIdMap->{'GeneFeature'}->{$geneSourceId}->{na_feature_id};
      my $productReleaseId = $sourceIdMap->{'GeneFeature'}->{$geneSourceId}->{external_database_release_id};

      $self->makeGeneFeatureProduct($productReleaseId, $nafeatureId, $description, 0, undef, 149, undef, 'ARBA');

      $processed++;
    } else {
      $self->log("WARNING", "gene with source id '$geneSourceId' and organism '$organismAbbrev' cannot be found");
    }
    $self->undefPointerCache();
  }

  die "Less than half of the products were parsed and loaded\n" if ($totalNum > 1 && $processed / $totalNum < 0.5);
  return "$processed gene feature products parsed and loaded";
}

# =========================== Subroutines ================================================================================

sub makeGeneFeatureProduct {
  my ($self, $geneReleaseId, $naFeatId, $product, $preferred, $pmid, $evCode, $with, $assignedBy) = @_;

  my $geneProduct = GUS::Model::ApiDB::GeneFeatureProduct->new({'na_feature_id' => $naFeatId,
                                                                'product'       => $product,
                                                                'publication'   => $pmid,
                                                               });

  unless ($geneProduct->retrieveFromDB()) {
    $geneProduct->set("is_preferred", $preferred);
    $geneProduct->set("external_database_release_id", $geneReleaseId);
    $geneProduct->set("evidence_code", $evCode);
    $geneProduct->set("with_from", $with);
    $geneProduct->set("assigned_by", $assignedBy);
    $geneProduct->submit();
  } else {
    $self->log("WARNING", "product $product already exists for na_feature_id: $naFeatId\n");
  }
}

sub getSourceIdToFeatureInfoMap {
  my ($self, $organismAbbrev, $dbh) = @_;

  my $sql = "select f.source_id
     , f.na_feature_id
     , f.external_database_release_id
     , f.subclass_view
from dots.nafeature f
   join dots.nasequence s on f.na_sequence_id = s.na_sequence_id
   join apidb.organism o on s.taxon_id = o.taxon_id
where o.abbrev = ?
and f.subclass_view in ('GeneFeature')";

  my $sth = $dbh->prepare($sql);
  $sth->execute($organismAbbrev);

  my %sourceIdMap;
  while (my ($sourceId, $naFeatureId, $extDbRlsId, $subClassView) = $sth->fetchrow_array()) {
    $sourceIdMap{$subClassView}->{$sourceId} = {
      na_feature_id                => $naFeatureId,
      external_database_release_id => $extDbRlsId,
    };
  }

  return \%sourceIdMap;
}

sub undoTables {
  my ($self) = @_;
  return ('ApiDB.GeneFeatureProduct');
}

1;
