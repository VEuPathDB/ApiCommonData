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
						 $self->getArg('genomeDbVer')) || $self->error("Can't find db_el_id for genome");

  my $tabFile = $self->getArg('file');

  my $processed;

  open(FILE,$tabFile) || $self->error("$tabFile can't be opened for reading");

  while(<FILE>){
      next if (^\s*$);

      my ($sourceId, $product, $preferred) = split(/\t/,$_);

      my $nafeatureId=$self->getNaFeatId($genomeReleaseId,$sourceId);

      $self->makeGeneFeatProduct($genomeReleaseId,$nafeatureId,$product,$preferred);

      $processed++;
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

  $geneFeatProductexon->submit() unless $geneFeatProduct->retrieveFromDB();
}

sub getNaFeatId {
  my ($self,$genomeReleaseId,$sourceId) = @_;

  my $geneFeat =  GUS::Model::DoTS::GeneFeature->new({'external_database_release_id' => $genomeReleaseId,
						      'source_id' => $sourceId});
  $geneFeat->retrieveFromDB();

  my $naFeatId = $geneFeat->getNaFeatureId();

  $self->undefPointerCache();

  return $naFeatId;
}

sub undoTables {
  return ('ApiDB.GeneFeatureProduct',
	 );
}

