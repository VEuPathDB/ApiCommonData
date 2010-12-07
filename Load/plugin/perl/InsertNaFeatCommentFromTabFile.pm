package ApiCommonData::Load::Plugin::InsertNaFeatCommentFromTabFile;
@ISA = qw(GUS::PluginMgr::Plugin);

use strict;
use warnings;

use GUS::PluginMgr::Plugin;


use GUS::Model::DoTS::GeneFeature;
use GUS::Model::DoTS::NAFeatureComment;
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
	       isList => 0,
	       mustExist => 1,
	       format => 'Two column tab delimited file in the order identifier, comment',
	     }),
     stringArg({ name => 'genomeDbName',
		 descr => 'externaldatabase name for gene comment source',
		 constraintFunc=> undef,
		 reqd  => 1,
		 isList => 0
	       }),
     stringArg({ name => 'genomeDbVer',
		 descr => 'externaldatabaserelease version used for gene comment source',
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
						 $self->getArg('genomeDbVer')) || $self->error("Can't find external_database_release_id for genome");

  my $tabFile = $self->getArg('file');

  my $processed;

  open(FILE,$tabFile) || $self->error("$tabFile can't be opened for reading");

  while(<FILE>){
      next if (/^\s*$/);

      chomp;

      my ($sourceId, $comment) = split(/\t/,$_);

      my $geneFeature = GUS::Model::DoTS::GeneFeature->new({source_id => $sourceId, external_database_release_id => $genomeReleaseId});

      if($geneFeature->retrieveFromDB()){

	  my $nafeatureId = $geneFeature->getNaFeatureId();
    
	  $self->makeNaFeatComment($nafeatureId,$comment);
  
	  $processed++;

      }else{
	  $self->log("WARNING","Gene Feature with source id: $sourceId and external database release id $genomeReleaseId cannot be found");
      }
     $self->undefPointerCache();

  }



  return "$processed na feature comments parsed and loaded";
}


sub makeNaFeatComment {
  my ($self,$naFeatId,$comment) = @_;

  my $naFeatComment = GUS::Model::DoTS::NAFeatureComment->new({'na_feature_id' => $naFeatId,
						              'comment_string' => $comment,});

  $naFeatComment->submit();
}

sub undoTables {
  return ('DoTS.NaFeatureComment',
	 );
}

