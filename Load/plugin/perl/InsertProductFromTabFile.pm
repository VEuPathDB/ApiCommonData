package ApiCommonData::Load::Plugin::InsertProductFromTabFile;

@ISA = qw(GUS::PluginMgr::Plugin);

use strict;
use warnings;

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

# ----------------------------------------------------------
# Load Arguments
# ----------------------------------------------------------

sub getArgsDeclaration {
  my $argsDeclaration  =
    [
     fileArg({name           => 'soGusConfigFile',
              descr          => 'The gus config file for database containing SO term info',
              reqd           => 0,
              mustExist      => 0,
              format         =>'TXT',
              constraintFunc => undef,
              isList         => 0 }),
     fileArg({ name => 'file',
	       descr => 'tab delimited file containing gene or transcript identifiers and product names',
	       constraintFunc=> undef,
	       reqd  => 1,
	       isList => 0,
	       mustExist => 1,
	       format => 'Two column tab delimited file in the order identifier, product',
	     }),
     stringArg({ name => 'organismAbbrev',
		 descr => 'organismAbbrev for product name source',
		 constraintFunc=> undef,
		 reqd  => 1,
		 isList => 0
	       })
    ];

  return $argsDeclaration;
}


# ----------------------------------------------------------
# Documentation
# ----------------------------------------------------------

sub getDocumentation {

  my $description = <<DESCR;
Plugin to load product names
DESCR

  my $purpose = <<PURPOSE;
Plugin to load product names
PURPOSE

  my $purposeBrief = <<PURPOSEBRIEF;
Plugin to load product names
PURPOSEBRIEF

  my $notes = <<NOTES;
NOTES

  my $tablesAffected = <<AFFECT;
ApiDB.TrasncriptProduct
AFFECT

  my $tablesDependedOn = <<TABD;
DoTS.Transcript,SRes.ExternalDatabase,SRes.ExternalDatabaseRelease
TABD

  my $howToRestart = <<RESTART;
No restart provided. Must undo and reload.
RESTART

  my $failureCases = <<FAIL;
FAIL

  my $documentation = { purpose          => $purpose,
			purposeBrief     => $purposeBrief,
			tablesAffected   => $tablesAffected,
			tablesDependedOn => $tablesDependedOn,
			howToRestart     => $howToRestart,
			failureCases     => $failureCases,
			notes            => $notes
		      };

  return ($documentation);

}


sub new {
  my $class = shift;
  my $self = {};
  bless($self, $class);

  my $documentation = &getDocumentation();

  my $args = &getArgsDeclaration();

  my $configuration = { requiredDbVersion => 4.0,
			cvsRevision => '$Revision$', # cvs fills this in!
			name => ref($self),
			argsDeclaration => $args,
			documentation => $documentation
		      };

  $self->initialize($configuration);

  return $self;
}

sub run {
  my $self = shift;

  my $organismAbbrev = $self->getArg('organismAbbrev');
  my $organismInfo = GUS::Model::ApiDB::Organism->new({'abbrev' => $organismAbbrev});
  $organismInfo->retrieveFromDB();
  my $projectId = $organismInfo->getRowProjectId();

  my $tabFile = $self->getArg('file');

  my $processed;

  my $totalNum;

  open(FILE,$tabFile) || $self->error("$tabFile can't be opened for reading");

  while(<FILE>){

      chomp();

      next if (/^\s*$/);

      $totalNum++;

      my ($sourceId, $product, $preferred, $pmid, $evCode, $with, $assignedBy) = split(/\t/,$_);
      next if ($sourceId =~ /^\s*$/ || $product =~ /^\s*$/);
      if ($preferred =~ /true/i || $preferred == 1) {
	$preferred = 1;
      } else {
	$preferred = 0;
      }

      $self->error("Either sourceId or product is null on line of $. of input file '$tabFile'") unless $sourceId && $product;

#      my $preferred = 0;

      my $gene = GUS::Model::DoTS::GeneFeature->new({source_id => $sourceId, row_project_id => $projectId});
      my $transcript = GUS::Model::DoTS::Transcript->new({source_id => $sourceId, row_project_id => $projectId});

      if($transcript->retrieveFromDB()){
	  my $transcriptProduct = $transcript->getChild('ApiDB::TranscriptProduct',1);

#	  $preferred = 1 unless $transcriptProduct;

	  my $nafeatureId = $transcript->getNaFeatureId();
          my $productReleaseId = $transcript->getExternalDatabaseReleaseId();

	  $self->makeTranscriptProduct($productReleaseId,$nafeatureId,$product,$preferred, $pmid, $evCode, $with, $assignedBy);

	  $processed++;

      }elsif ($gene->retrieveFromDB()) {
	  my $nafeatureId = $gene->getNaFeatureId();
          my $productReleaseId = $gene->getExternalDatabaseReleaseId();

	  $self->makeGeneFeatureProduct($productReleaseId,$nafeatureId,$product,$preferred, $pmid, $evCode, $with, $assignedBy);

	  $processed++;

      }else{
	  $self->log("WARNING","gene or Transcript with source id '$sourceId' and organism '$organismAbbrev' cannot be found");
      }
      $self->undefPointerCache();
  }

  die "Less than half of the products were parsed and loaded\n" if ($processed/$totalNum < 0.5);

  return "$processed gene feature products parsed and loaded";
}


sub makeTranscriptProduct {
  my ($self,$productReleaseId,$naFeatId,$product,$preferred, $pmid, $evCode, $with, $assignedBy) = @_;

  my $evCodeLink = getEvidCodeLink ($self, $evCode) if ($evCode);
  my $transcriptProduct = GUS::Model::ApiDB::TranscriptProduct->new({'na_feature_id' => $naFeatId,
						                    'product' => $product,
						                    'publication' => $pmid,
						                     });

  unless ($transcriptProduct->retrieveFromDB()){
      $transcriptProduct->set("is_preferred",$preferred);
      $transcriptProduct->set("external_database_release_id",$productReleaseId);
      $transcriptProduct->set("evidence_code",$evCodeLink);
      $transcriptProduct->set("with_from",$with);
      $transcriptProduct->set("assigned_by",$assignedBy);
      $transcriptProduct->submit();
  }else{
      $self->log("WARNING","product $product already exists for na_feature_id: $naFeatId, with publication: $pmid\n");
  }

}

sub makeGeneFeatureProduct {

  my ($self,$geneReleaseId,$naFeatId,$product,$preferred, $pmid, $evCode, $with, $assignedBy) = @_;

  my $evCodeLink = getEvidCodeLink ($self, $evCode) if ($evCode);
  my $geneProduct = GUS::Model::ApiDB::GeneFeatureProduct->new({'na_feature_id' => $naFeatId,
						                    'product' => $product,
                                                                    'publication' => $pmid,
						                     });

  unless ($geneProduct->retrieveFromDB()){
      $geneProduct->set("is_preferred",$preferred);
      $geneProduct->set("external_database_release_id",$geneReleaseId);
      $geneProduct->set("evidence_code",$evCodeLink);
      $geneProduct->set("with_from",$with);
      $geneProduct->set("assigned_by",$assignedBy);
      $geneProduct->submit();
  }else{
      $self->log("WARNING","product $product already exists for na_feature_id: $naFeatId\n");
  }

}

sub getEvidCodeLink {
  my ($self, $evCodeName) = @_;

  my $evCodeLink;

  my $soGusConfigFile = $self->getArg('soGusConfigFile') if ($self->getArg('soGusConfigFile'));
  my $soExtDbSpec = "GO_evidence_codes_RSRC|%";
  my $soLookup = GUS::Supported::OntologyLookup->new($soExtDbSpec, $soGusConfigFile);
  my $soSourceId = $soLookup->getSourceIdFromName($evCodeName);
  unless($soSourceId) {
    $self->error("Could not determine sourceId from evidence code: $evCodeName\n");
  }

  my $goecExtDbRlsId= $self->getOrCreateExtDbAndDbRls("GO_evidence_codes_RSRC", "N/A");
  my $ontologyTerm = GUS::Model::SRes::OntologyTerm->new ({
						       'name' => $evCodeName,
						       'source_id' => $soSourceId,
                                                       'external_database_release_id' => $goecExtDbRlsId
						       });

  unless ($ontologyTerm->retrieveFromDB()) {
    $self->log ("WARNING", "Evidence code $evCodeName does not exists in SRes::OntologyTerm table... adding");
    $ontologyTerm->submit();
  }
  $evCodeLink = $ontologyTerm->getOntologyTermId();

  return $evCodeLink;
}

sub getOrCreateExtDbAndDbRls{
  my ($self, $dbName,$dbVer) = @_;

  my $extDbId=$self->InsertExternalDatabase($dbName);

  my $extDbRlsId=$self->InsertExternalDatabaseRls($dbName,$dbVer,$extDbId);

  return $extDbRlsId;
}

sub InsertExternalDatabase{

    my ($self,$dbName) = @_;
    my $extDbId;

    my $sql = "select external_database_id from sres.externaldatabase where lower(name) like '" . lc($dbName) ."'";
    my $sth = $self->prepareAndExecute($sql);
    $extDbId = $sth->fetchrow_array();

    unless ($extDbId){
	my $newDatabase = GUS::Model::SRes::ExternalDatabase->new({
	    name => $dbName,
	   });
	$newDatabase->submit();
	$extDbId = $newDatabase->getId();
	print STDERR "created new entry for database $dbName with primary key $extDbId\n";
    }
    return $extDbId;
}

sub InsertExternalDatabaseRls{

    my ($self,$dbName,$dbVer,$extDbId) = @_;

    my $extDbRlsId = $self->releaseAlreadyExists($dbName, $extDbId,$dbVer);

    unless ($extDbRlsId){
        $extDbRlsId = $self->makeNewReleaseId($extDbId,$dbVer);
	print STDERR "Created new release id for $dbName with version $dbVer and release id $extDbRlsId\n";
    }
    return $extDbRlsId;
}


sub releaseAlreadyExists{
    my ($self, $dbName, $extDbId,$dbVer) = @_;

    my $sql;

    if ($dbName =~ /GO_evidence_codes_RSRC/i || $dbName =~ /SO_RSRC/i) {
      $sql = "select external_database_release_id 
               from SRes.ExternalDatabaseRelease
               where external_database_id = $extDbId";
    } else {
      $sql = "select external_database_release_id 
               from SRes.ExternalDatabaseRelease
               where external_database_id = $extDbId
               and version = '$dbVer'";
    }

    my $sth = $self->prepareAndExecute($sql);
    my ($relId) = $sth->fetchrow_array();

    return $relId; #if exists, entry has already been made for this version

}

sub makeNewReleaseId{
    my ($self, $extDbId,$dbVer) = @_;

    my $newRelease = GUS::Model::SRes::ExternalDatabaseRelease->new({
	external_database_id => $extDbId,
	version => $dbVer,
	download_url => '',
	id_type => '',
	id_url => '',
	secondary_id_type => '',
	secondary_id_url => '',
	description => '',
	file_name => '',
	file_md5 => '',

    });

    $newRelease->submit();
    my $newReleasePk = $newRelease->getId();

    return $newReleasePk;

}

sub undoTables {
  return ('ApiDB.TranscriptProduct',
	  'ApiDB.GeneFeatureProduct',
	  'SRes.OntologyTerm',
	  'SRes.ExternalDatabaseRelease',
	  'SRes.ExternalDatabase',
	 );
}

