package ApiCommonData::Load::Plugin::InsertNaFeatCommentFromTabFile;
#vvvvvvvvvvvvvvvvvvvvvvvvv GUS4_STATUS vvvvvvvvvvvvvvvvvvvvvvvvv
  # GUS4_STATUS | SRes.OntologyTerm              | auto   | absent
  # GUS4_STATUS | SRes.SequenceOntology          | auto   | absent
  # GUS4_STATUS | Study.OntologyEntry            | auto   | absent
  # GUS4_STATUS | SRes.GOTerm                    | auto   | absent
  # GUS4_STATUS | Dots.RNAFeatureExon            | auto   | absent
  # GUS4_STATUS | RAD.SageTag                    | auto   | absent
  # GUS4_STATUS | RAD.Analysis                   | auto   | absent
  # GUS4_STATUS | ApiDB.Profile                  | auto   | absent
  # GUS4_STATUS | Study.Study                    | auto   | absent
  # GUS4_STATUS | Dots.Isolate                   | auto   | absent
  # GUS4_STATUS | DeprecatedTables               | auto   | absent
  # GUS4_STATUS | Pathway                        | auto   | absent
  # GUS4_STATUS | DoTS.SequenceVariation         | auto   | absent
  # GUS4_STATUS | RNASeq Junctions               | auto   | absent
  # GUS4_STATUS | Simple Rename                  | auto   | absent
  # GUS4_STATUS | ApiDB Tuning Gene              | auto   | absent
  # GUS4_STATUS | Rethink                        | auto   | absent
  # GUS4_STATUS | dots.gene                      | manual | absent
#^^^^^^^^^^^^^^^^^^^^^^^^^ End GUS4_STATUS ^^^^^^^^^^^^^^^^^^^^
@ISA = qw(GUS::PluginMgr::Plugin);

use strict;
use warnings;

use GUS::PluginMgr::Plugin;

use GUS::Model::DoTS::GeneFeature;
use GUS::Model::DoTS::Transcript;
use GUS::Model::DoTS::NAFeatureComment;
use GUS::Supported::Util;
use GUS::Model::ApiDB::Organism;

use POSIX qw(strftime);

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
     stringArg({ name => 'datasetVersion',
		 descr => 'the version of the dataset',
		 constraintFunc=> undef,
		 reqd  => 0,
		 isList => 0
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

  my $configuration = { requiredDbVersion => 4.0,
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
  my $datasetVersion = $self->getArg('datasetVersion') if ($self->getArg('datasetVersion'));
  my $organismInfo = GUS::Model::ApiDB::Organism->new({'abbrev' => $organismAbbrev});
  $organismInfo->retrieveFromDB();
  my $projectId = $organismInfo->getRowProjectId();

  my $tabFile = $self->getArg('file');

  my $processed;

  open(FILE,$tabFile) || $self->error("$tabFile can't be opened for reading");

  my @fileStats = stat($tabFile);
  my $fileModificationDate = strftime("%Y-%m-%d %H:%M:%S", localtime($stats[9]));


  while(<FILE>){
      next if (/^\s*$/);

      chomp;

      my ($sourceId, $comment, $comment_date) = split(/\t/,$_);

      my $geneFeature = GUS::Model::DoTS::GeneFeature->new({source_id => $sourceId, row_project_id => $projectId});
      my $transcript  = GUS::Model::DoTS::Transcript->new({source_id => $sourceId, row_project_id => $projectId});

      if(!$comment_date) {
        if ($datasetVersion =~ /^\d{4}-\d{2}-\d{2}$/) {
          $comment_date = $datasetVersion;
        }
        else {
          $comment_date = $fileModificationDate
        }
      }

      if($geneFeature->retrieveFromDB()){

	  my $nafeatureId = $geneFeature->getNaFeatureId();
    
	  $self->makeNaFeatComment($nafeatureId,$comment, $comment_date);
  
	  $processed++;

      } elsif($transcript->retrieveFromDB()) { 

	      my $nafeatureId = $transcript->getNaFeatureId();
	      $self->makeNaFeatComment($nafeatureId,$comment, $comment_date);
  
	      $processed++; 
   } else{
	  $self->log("WARNING","Gene/Transcript Feature with source id: $sourceId and organism '$organismAbbrev' cannot be found");
      }
     $self->undefPointerCache();

  }

  die and print "There is NO row loaded!!! Check the data!" unless ($processed > 0);

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

