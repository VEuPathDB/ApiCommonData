package ApiCommonData::Load::Plugin::LoadSageTagFeature;
@ISA = qw(GUS::PluginMgr::Plugin);


use strict;
use GUS::PluginMgr::Plugin;
use GUS::Model::RAD::SAGETag;
use GUS::Model::DoTS::NALocation;
use GUS::Model::DoTS::SAGETagFeature;
use GUS::Model::DoTS::NASequence;
use GUS::Model::Core::Algorithm;

$| = 1;

# ---------------------------------------------------------------------------
# Load Arguments
# ---------------------------------------------------------------------------

sub getArgumentsDeclaration{
  my $argsDeclaration =
    [

     fileArg({name => 'tagToSeqFile',
	      descr => 'full path of file containing result of tagToSeq.pl analysis',
	      constraintFunc=> undef,
	      reqd  => 1,
	      isList => 0,
	      mustExist => 1,
	      format => 'Ex:395 (composite_element_id) matched against 4 (na_sequence_id) from 1405549 to 1405563 on forward strand'
	     }),

     integerArg({name  => 'restart',
		 descr => 'The last line number from the tagToSeqFile processed, read from the STDOUT file.',
		 constraintFunc=> undef,
		 reqd  => 0,
		 isList => 0
		})

    ];


  return $argsDeclaration;
}



# --------------------------------------------------------------------------
# Documentation
# --------------------------------------------------------------------------

sub getDocumentation {

my $purposeBrief = <<PURPOSEBRIEF;
Plug_in to populate DoTS.SAGETagFeature.
PURPOSEBRIEF

my $purpose = <<PLUGIN_PURPOSE;
plug_in that inserts Suffix::Array::match mapping results into DoTS.SAGETagFeature and DoTS.NALocation.
PLUGIN_PURPOSE

my $syntax = <<SYNTAX;
Standard plugin syntax.
SYNTAX

#check the documentation for this
my $tablesAffected = [['GUS::Model::DoTS::SAGETagFeature', 'inserts a single row per row of result file'],['GUS::Model::DoTS::NALocation', 'inserts a row for each row of result file'],['GUS::Model::Core::Algorithm','inserts a single row for mapping method when not present']];

my $tablesDependedOn = [['GUS::Model::SRes::ExternalDatabaseRelease', 'Gets an existing external_database-release_id'],['GUS::Model::RAD::SAGETag', 'Gets existing sage tag rows for each row in the input file'],['GUS::Model::DoTS::NASequence', 'Gets an existing na_sequence_id for subject sequence']];

my $howToRestart = <<PLUGIN_RESTART;
Explicit restart using the rownum printed in the STDOUT file. 
PLUGIN_RESTART

my $failureCases = <<PLUGIN_FAILURE_CASES;
no ExternalDatabaseRelease, SAGETag, or NASequence rows corresponding to previously entered dbRelId,tags, or subject sequences.File incorrectly formatted.
PLUGIN_FAILURE_CASES

my $notes = <<PLUGIN_NOTES;
SAGETag and NASequence rows must have been previously entered. Input file must be in the correct format. ExternalDatabaseRelease row for dbname = RAD.SAGETag and dbrelver = continuous must exist. 
PLUGIN_NOTES

my $documentation = {purposeBrief => $purposeBrief,
		     purpose => $purpose,
		     syntax => $syntax,
		     tablesAffected => $tablesAffected,
		     tablesDependedOn => $tablesDependedOn,
		     howToRestart => $howToRestart,
		     failureCases => $failureCases,
		     notes => $notes
		    };

return ($documentation);

}


#############################################################################
# Create a new instance of a SageResultLoader object
#############################################################################

sub new {
  my ($class) = @_;
  my $self = {};
  bless($self,$class);

  my $documentation = &getDocumentation();
  my $arguments     = &getArgumentsDeclaration();

  my $configuration = {requiredDbVersion => 3.5,
	               cvsRevision => '$Revision$', # cvs fills this in!
		       name => ref($self),
		       revisionNotes => 'make consistent with GUS 3.5',
		       argsDeclaration   => $arguments,
		       documentation     => $documentation
		       };

     $self->initialize($configuration);

  return $self;
}

########################################################################
# Main Program
########################################################################

sub run {
  my ($self) = @_;

  $self->logArgs();
  $self->logAlgInvocationId();
  $self->logCommit();

  $self->checkFileFormat();

  $self->getExternalDbRelease();

  $self->getPredAlgId();

  my $numFeatures = $self->processFile();

  my $resultDescrip = "$numFeatures rows inserted into SageTagFeature";

  $self->setResultDescr($resultDescrip);
  $self->log($resultDescrip);
}

sub checkFileFormat {
  my ($self) = @_;

  open (FILE, $self->getArg('tagToSeqFile'));

  while (<FILE>) {
    chomp;
    if ($_ !~ /^\d+\smatched\sagainst\s\d+\sfrom\s\d+\sto\s\d+\son\s[forward|reverse]/) {
      $self->userError("Check file format - format incorrect for at least one line in $self->getArg('tagToSeqFile')\n");
    }
  }
}


sub getExternalDbRelease {
  my ($self) = @_;

  my $dbName = "RAD.SAGETag";
  my $dbVersion = "continuous";

  my $dbRlsId = $self->getExtDbRlsId($dbName, $dbVersion);

  $self->{'extDbRls'} = $dbRlsId;
}

sub getPredAlgId {
  my ($self) = @_;

  my $name = "tagToSeq";
  my $desc = "uses Suffix::Array::match to find exact matches of tag to seq db";

  my $alg = GUS::Model::Core::Algorithm->new({'name' => $name,'description'=>$desc});

  if (! $alg->retrieveFromDB()) {
    $alg->submit();
  }

  my $id = $alg->getId();

  $self->{'algId'} = $id;
}

sub processFile {
  my ($self) = @_;

  my $processed = $self->getArg('restart') ? $self->getArg('restart') : 0;

  my $row;

  open (FILE, $self->getArg('tagToSeqFile'));

  while (<FILE>) {
    chomp;
    $row++;
    next if ($processed >= $row);
    my @arr = split (/\s/,$_);

    my $orient = $arr[9] eq 'reverse' ? 1 : 0;

    my %args = ('compElemId'=>$arr[0],'naSeqId'=>$arr[3],'start'=>$arr[5],'end'=>$arr[7],'tagOrient'=>$orient);

    my $sageTagFeat = $self->makeSageTagFeat(\%args);

    $self->makeNaLoc($sageTagFeat,\%args);

    my $submitted = $sageTagFeat->submit();

    $processed++;
    $self->logData("processed file row number $processed with $submitted insertions into db\n");

    $sageTagFeat->undefPointerCache();
  }

  return $processed;
}

sub makeSageTagFeat {
   my ($self,$args) = @_;

   my $name = getNaSeqDesc($self,$args);

   my $sourceId = $args->{'compElemId'};

   my $naSeqId = $args->{'naSeqId'};

   my $extDbRls = $self->{'extDbRls'};

   my $algId = $self->{'algId'};

   my $sageTagFeat = GUS::Model::DoTS::SAGETagFeature->new({'name'=>$name,'source_id'=>$sourceId,'na_sequence_id'=>$naSeqId,'external_database_release_id'=>$extDbRls,'prediction_algorithm_id'=>$algId});

   return $sageTagFeat;
}

sub makeNaLoc {
  my ($self,$sageTagFeat,$args) = @_;

  my $start = $args->{'start'};

  my $end = $args->{'end'};

  my $isReversed = $args->{'tagOrient'};

  my $naLoc = GUS::Model::DoTS::NALocation->new({'start_min'=>$start,'start_max'=>$start,'end_min'=>$end,'end_max'=>$end,'is_reversed'=>$isReversed});

  $naLoc->setParent($sageTagFeat);
}


sub getNaSeqDesc {
  my ($self,$args) = @_;

  my $naSeqId = $args->{'naSeqId'};

  my $naSeq = GUS::Model::DoTS::NASequence->new({'na_sequence_id'=>$naSeqId});

  my @doNotRet = 'sequence';

  $naSeq->retrieveFromDB(\@doNotRet);

  if (! $naSeq) {
    $self->userError("Subject na_sequence_id, $naSeqId, not in database\n");
  }

  my $id = $naSeq->getId();

  my $desc = $naSeq->getDescription();

  my $name = substr($desc,0,30);

  my $taxon = $naSeq->getTaxonId();

  if (! $name) {
    $name = 'unknown';
  }

  return $name;
}
