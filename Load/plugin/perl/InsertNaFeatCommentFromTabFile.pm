package ApiCommonData::Load::Plugin::InsertNaFeatCommentFromTabFile;
@ISA = qw(GUS::PluginMgr::Plugin);

use strict;
use warnings;

use GUS::PluginMgr::Plugin;


use GUS::Model::DoTS::GeneFeature;
use GUS::Model::DoTS::NAFeatureComment;
use GUS::Supported::Util;
use GUS::Model::ApiDB::Organism;

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
     stringArg({ name => 'organismAbbrev',
		 descr => 'organismAbbrev for gene comment source',
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

  my $configuration = { requiredDbVersion => 3.6,
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

  my $organismAbbrev = $self->getArg('organismAbbrev');
  my $organismInfo = GUS::Model::ApiDB::Organism->new({'abbrev' => $organismAbbrev});
  $organismInfo->retrieveFromDB();
  my $projectId = $organismInfo->getRowProjectId();

  my $tabFile = $self->getArg('file');

  my $processed;

  open(FILE,$tabFile) || $self->error("$tabFile can't be opened for reading");

  while(<FILE>){
      next if (/^\s*$/);

      chomp;

      my ($sourceId, $comment, $comment_date) = split(/\t/,$_);

      my $geneFeature = GUS::Model::DoTS::GeneFeature->new({source_id => $sourceId, row_project_id => $projectId});

      if($geneFeature->retrieveFromDB()){

	  my $nafeatureId = $geneFeature->getNaFeatureId();
    
	  $self->makeNaFeatComment($nafeatureId,$comment, $comment_date);
  
	  $processed++;

      }else{
	  $self->log("WARNING","Gene Feature with source id: $sourceId and organism '$organismAbbrev' cannot be found");
      }
     $self->undefPointerCache();

  }



  return "$processed na feature comments parsed and loaded";
}


sub makeNaFeatComment {
  my ($self,$naFeatId,$comment,$comment_date) = @_;

  my $naFeatComment = GUS::Model::DoTS::NAFeatureComment->new({'na_feature_id' => $naFeatId,
						              'comment_string' => $comment,
						              'comment_date' => $comment_date
                        });

  $naFeatComment->submit();
}

sub undoTables {
  return ('DoTS.NaFeatureComment',
	 );
}

