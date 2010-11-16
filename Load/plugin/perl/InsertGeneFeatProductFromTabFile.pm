package ApiCommonData::Load::Plugin::InsertGeneFeatProductFromTabFile;
@ISA = qw(GUS::PluginMgr::Plugin);

use strict;
use warnings;

use GUS::PluginMgr::Plugin;


use GUS::Model::DoTS::GeneFeature;
use GUS::Model::ApiDB::GeneFeatureProduct;
use ApiCommonData::Load::Util;

# ----------------------------------------------------------
# Load Arguments
# ----------------------------------------------------------

sub getArgsDeclaration {
  my $argsDeclaration  =
    [
     fileArg({ name => 'file',
	       descr => 'tab delimited file containing gene identifiers and product names',
	       constraintFunc=> undef,
	       reqd  => 1,
	       isList => 0
	     }),
     stringArg({ name => 'genomeDbName',
		 descr => 'externaldatabase name for genome sequences scanned',
		 constraintFunc=> undef,
		 reqd  => 1,
		 isList => 0
	       }),
     stringArg({ name => 'genomeDbVer',
		 descr => 'externaldatabaserelease version used for genome sequences scanned',
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
ApiDB.GeneFeatureProduct
AFFECT

  my $tablesDependedOn = <<TABD;
DoTS.GeneFeature,SRes.ExternalDatabase,SRes.ExternalDatabaseRelease
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

  my $configuration = { requiredDbVersion => 3.5,
			cvsRevision => '$Revision$',
			name => ref($self),
			argsDeclaration => $args,
			documentation => $documentation
		      };

  $self->initialize($configuration);

  return $self;
}

sub run {
  my $self = shift;

  my $genomeReleaseId = $self->getExtDbRlsId($self->getArg('genomeDbName'),
						 $self->getArg('genomeDbVer')) || $self->error("Can't find external_database_release_id for genome");

  my $tabFile = $self->getArg('file');

  my $processed;

  open(FILE,$tabFile) || $self->error("$tabFile can't be opened for reading");

  while(<FILE>){
      next if (^\s*$);

      my ($sourceId, $product) = split(/\t/,$_);

      my $preferred = 0;
	       
      my $geneFeature = GUS::Model::DoTS::GeneFeature->new({source_id => $sourceId, external_database_release_id => $genomeReleaseId});
      

      if($geneFeature->retrieveFromDB()){
	  my $product = $geneFeature->getChild("GUS::Model::ApiDB::GeneFeatureProduct");

	  $preferred = 1 unless $product->retrieveFromDB();

	  my $nafeatureId = $geneFeature->getNaFeatureId();
    
	  $self->makeGeneFeatProduct($genomeReleaseId,$nafeatureId,$product,$preferred);
  
	  $processed++;
      }else{
	  $self->warn("Gene Feature with source id: $sourceId and external database release id $genomeReleaseId cannot be found");
      }
  }        


  $self->undefPointerCache();

  return "$processed gene feature products parsed and loaded";
}


sub makeGeneFeatProduct {
  my ($self,$genomeReleaseId,$naFeatId,$product,$preferred) = @_;

  my $geneFeatProduct = GUS::Model::ApiDB::GeneFeatureProduct->new({'na_feature_id' => $naFeatId,
						                    'external_database_release_id' => $genomeReleaseId,
						                    'product' => $product,
						                    'is_preferred' => $preferred});

  $geneFeatProduct->submit() unless $geneFeatProduct->retrieveFromDB();
}


sub undoTables {
  return ('ApiDB.GeneFeatureProduct',
	 );
}

