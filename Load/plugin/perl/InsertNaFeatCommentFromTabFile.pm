package ApiCommonData::Load::Plugin::InsertGeneCommentFromTabFile;
@ISA = qw(GUS::PluginMgr::Plugin);

use strict;
use warnings;

use GUS::PluginMgr::Plugin;


use GUS::Model::DoTS::GeneFeature;
use GUS::Model::DoTS::NaFeatureComment;
use ApiCommonData::Load::Util;

# ----------------------------------------------------------
# Load Arguments
# ----------------------------------------------------------

sub getArgsDeclaration {
  my $argsDeclaration  =
    [
     fileArg({ name => 'file',
	       descr => 'tab delimited file containing gene identifiers and comments',
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
Plugin to load comments
DESCR

  my $purpose = <<PURPOSE;
Plugin to load comments
PURPOSE

  my $purposeBrief = <<PURPOSEBRIEF;
Plugin to load comments
PURPOSEBRIEF

  my $notes = <<NOTES;
NOTES

  my $tablesAffected = <<AFFECT;
DoTS.NaFeatureComment
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

      my ($sourceId, $comment) = split(/\t/,$_);

      my $nafeatureId=$self->getNaFeatId($genomeReleaseId,$sourceId);

      $self->makeNaFeatComment($nafeatureId,$comment);

      $processed++;
  }

  $self->undefPointerCache();

  return "$processed na feature comments parsed and loaded";
}


sub makeNaFeatComment {
  my ($self,$naFeatId,$comment) = @_;

  my $naFeatComment = GUS::Model::ApiDB::NaFeatureComment->new({'na_feature_id' => $naFeatId,
						                  'COMMENT_STRING' => $comment});

  $naFeatComment->submit() unless $naFeatComment->retrieveFromDB();
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
  return ('ApiDB.NaFeatureComment',
	 );
}

