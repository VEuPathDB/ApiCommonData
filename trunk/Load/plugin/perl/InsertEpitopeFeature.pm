package ApiCommonData::Load::Plugin::InsertEpitopeFeature;
@ISA = qw(GUS::PluginMgr::Plugin);

use strict;

use FileHandle;
use GUS::Model::DoTS::EpitopeFeature;
use GUS::Model::DoTS::AALocation;
use GUS::Model::DoTS::TranslatedAASequence;
use GUS::Model::DoTS::MotifAASequence;
use GUS::PluginMgr::Plugin;


my $purposeBrief = <<PURPOSEBRIEF;
Inserts epitope data from a tab delimited file.
PURPOSEBRIEF

my $purpose = <<PLUGIN_PURPOSE;
Takes a file containing the source ids of the epitopes and the proteins that contain them and the start, end, and name of the epitope within the sequence.  This data is entered into the EpitopeFeature and AALocation tables to provide a mapping of the epitope on the proteins, and the EpitopeFeature is then linked to the MotifAASequence containing the epitope.
PLUGIN_PURPOSE

my $tablesAffected = [['DoTS::EpitopeFeature','The information on the epitope and the links to the AA sequence are made here.'],['DoTS::AALocation','The start and end location of the eptiope on the given sequence is located here.']];

my $tablesDependedOn = [['DoTS::TranslatedAASequence','The sequence that the epitope is found in must be in this table.'],['DoTS::MotifAASequence','The epitope sequences must exist here.']];

my $howToRestart = <<PLUGIN_RESTART;
Provide the restart flag with the algInvocation number of the run that failed.
PLUGIN_RESTART

my $failureCases = <<PLUGIN_FAILURE_CASES;
unknown
PLUGIN_FAILURE_CASES

my $notes = <<PLUGIN_NOTES;
The plugin will take in a file of the form:
AASeq_sourceid   IEDB ID   Epitope Name   start    end   is on BLAST hit   found all epitopes in set on sequence
PLUGIN_NOTES

my $documentation = {purposeBrief => $purposeBrief,
		     purpose => $purpose,
		     tablesAffected => $tablesAffected,
		     tablesDependedOn => $tablesDependedOn,
		     howToRestart => $howToRestart,
		     failureCases => $failureCases,
		     notes => $notes
		    };


my $argsDeclaration =
[

 fileArg({name => 'inputFile',
	  descr => 'name of the file to load',
	  constraintFunc => undef,
	  reqd => 1,
	  isList => 0,
	  mustExist => 1,
	  format => 'tab delimited'
        }),
 stringArg({name => 'extDbRelSpec',
	    descr => 'The external database specifications for the epitope data in the form "name|version"',
	    constraintFunc => undef,
	    reqd => 1,
	    isList => 0
	   }),
 stringArg({name => 'seqExtDbRelSpec',
	    descr => 'The external database specifications for the aa sequences in which the motif is found, in the form "name|version"',
	    constraintFunc => undef,
	    reqd => 1,
	    isList => 0
	   }),
 stringArg({name => 'restart',
	    descr => 'a list of algInvocation numbers for runs that failed',
	    constraintFunc => undef,
	    reqd => 0,
	    isList => 1
	   }),
 ];

sub new {
    my ($class) = @_;
    my $self = {};
    bless($self, $class);

    $self->initialize({requiredDbVersion => 3.5,
		       cvsRevision =>  '$Revision$',
		       name => ref($self),
		       argsDeclaration   => $argsDeclaration,
		       documentation     => $documentation
		      });

    return $self;
}

sub run{
  my ($self) = @_;
  my $skipped = 0;
  my $added = 0;
  my %done;
  my $file = $self->getArg('inputFile');

  my $epiExtDbRls = $self->getExtDbRlsId($self->getArg('extDbRelSpec')) || die "Couldn't retrieve external database info for epitopes!\n";

  my $seqExtDbRls = $self->getExtDbRlsId($self->getArg('seqExtDbRelSpec')) || die "Couldn't retrieve sequence external database!\n";

  my $restart = $self->getArg('restart');

  if($restart){
    my $restartIds = join(",",@$restart);
    %done = $self->restart($restartIds, \%done);
    $self->log("Restarting with algorithm invocation IDs: $restartIds");
  }

  open(MAP, $file);

  while (<MAP>){
    next if /^(\s)*$/;
    chomp;

    my @data = split('\t',$_);

    unless(%done->{$data[0]}){

      my $aaSeqId = $self->getAaSeqId($data[0], $seqExtDbRls);

      if($aaSeqId){

	$data[0] = $aaSeqId;

	my $epitope = $self->createEpitopeEntry(\@data, $epiExtDbRls);
	my $aaLocation = $self->createAALocation($data[3], $data[4]);

	$$epitope->addChild($$aaLocation);
	$$epitope->submit();
	$added++;
      }else{
	$skipped++;
	$self->undefPointerCache();
	next;
      }
    }
      $self->undefPointerCache();
  }

  my $msg = "Added $added new features.  Skipped $skipped features because source ID was not found.";

  return $msg;
}

sub getAaSeqId{
  my($self, $sourceId, $seqExtDbRls) = @_;
  my $aaSeqId;

  my $aaSeq = GUS::Model::DoTS::TranslatedAASequence->new({source_id => $sourceId,
							   external_database_release_id => $seqExtDbRls,
							  });

  if($aaSeq->retrieveFromDB()){
    $aaSeqId = $aaSeq->getId();
  }else{
    $self->log("Translated AA Sequence $sourceId not found");
  }

  return $aaSeqId;
}

sub createEpitopeEntry{
  my ($self, $data, $epiExtDbRls) = @_;

  my $motifId = $self->getMotifId($$data[1]);

  my $type = $self->getType($$data[5],$$data[7]);

  my $epitope = GUS::Model::DoTS::EpitopeFeature->new({aa_sequence_id => $$data[0],
						       source_id => $$data[1],
						       description => $$data[2],
						       motif_aa_sequence_id => $motifId,
						       type => $type,
						       external_database_release_id => $epiExtDbRls,
						       score => $$data[6],
						       is_predicted => 0
						      });

return \$epitope;
}

sub createAALocation{
  my ($self, $start, $end) = @_;

  my $aaLocation = GUS::Model::DoTS::AALocation->new({start_min => $start,
						      start_max => $start,
						      end_min => $end,
						      end_max => $end,
						     });

  return \$aaLocation;

}

sub getMotifId{
  my ($self,$sourceId) = @_;
  my $motifId;

  my $motif = GUS::Model::DoTS::MotifAASequence->new({source_id => $sourceId});

  if($motif->retrieveFromDB()){
    $motifId = $motif->getId();
  }else{
    die "Epitope '$sourceId' not found in DoTS.MotifAASequence.  Please use GUS::Supported::Plugin::LoadFastaSequences to insert it.";
  }

  return $motifId;
}

sub getType{
  my ($self, $onBlastHit, $foundFullSet) = @_;
  my $type;

  if($onBlastHit){
    if($foundFullSet){
      $type = "Full Set On Blast Hit";
    }else{
      $type = "Not Full Set On Blast Hit";
    }
  }else{
    if($foundFullSet){
      $type = "Full Set Not on Blast Hit";
    }else{
      $type = "Not Full Set Not on Blast Hit";
    }
  }

  return $type;
}

sub restart{
  my ($self, $restartIds, $done) = @_;

  my $sql = "SELECT source_id FROM DoTS.PredictedAAFeature WHERE row_alg_invocation_id IN ($restartIds)";

  my $qh = $self->getQueryHandle();
  my $sth = $qh->prepareAndExecute($sql);

    while(my ($id) = $sth->fetchrow_array()){
	$$done{$id}=1;
    }
    $sth->finish();

  return $done;
}

# ----------------------------------------------------------------------

sub undoTables {
  my ($self) = @_;

  return ('DoTS.AALocation',
	  'DoTS.EpitopeFeature',
	 );
}

1;
