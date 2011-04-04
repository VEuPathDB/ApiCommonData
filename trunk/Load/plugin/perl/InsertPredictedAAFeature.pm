#$Id$
#TODO: Test restart method
package ApiCommonData::Load::Plugin::InsertPredictedAAFeature;
@ISA = qw(GUS::PluginMgr::Plugin);

use strict;

use FileHandle;
use GUS::Model::DoTS::PredictedAAFeature;
use GUS::Model::DoTS::AALocation;
use GUS::Model::DoTS::TranslatedAASequence;
use GUS::PluginMgr::Plugin;
use ApiCommonData::Load::Util;


my $purposeBrief = <<PURPOSEBRIEF;
Inserts predicted aa features from a tab delimited.
PURPOSEBRIEF

my $purpose = <<PLUGIN_PURPOSE;
Inserts predicted aa features from a tab delimited file containing the source ID in the first column and, optionally, the location start and stop in the second and third columns respectively.  The data is loaded into the PredictedAASequence table and, optionally, into the AALocation table.
PLUGIN_PURPOSE

my $tablesAffected = [['DoTS::PredictedAAFeature','The links to the AA sequence are made here.'],['DoTS::AALocation','The start and end location of the feature on the given sequence is located here.']];

my $tablesDependedOn = ['DoTS::TranslatedAASequence','The sequence that the featutre is found in must be in this table.'];

my $howToRestart = <<PLUGIN_RESTART;
Provide the restart flag with the algInvocation number of the run that failed.
PLUGIN_RESTART

my $failureCases = <<PLUGIN_FAILURE_CASES;
unknown
PLUGIN_FAILURE_CASES

my $notes = <<PLUGIN_NOTES;
This plugin takes a tab delimited file of the form: source_id   (start_location)   (end_location)
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
	  format => 'tab delimited: source_id   (startLocation)  (endLocation)'
        }),

 booleanArg ({name => 'addLocation',
	      descr => 'Set this to add locations to the PredictedAAFeatures.  If not set, the features will be entered without location data.',
	      reqd => 0,
	      default =>0
	     }),

 stringArg({name => 'description',
	    descr => 'a short description of the motif',
	    constraintFunc => undef,
	    reqd => 0,
	    isList => 0
	   }),

 stringArg({name => 'category',
	    descr => 'category into which the sequences containing the motif fall, ex: secretome, proteome, etc.',
	    constraintFunc => undef,
	    reqd => 0,
	    isList => 0
	   }),

 stringArg({name => 'extDbRelSpec',
	    descr => 'The external database specifications for the motif data in the form "name|version"',
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
  my($self) = @_;
  my $added = 0;
  my $skipped = 0;
  my %done;
  my $start;
  my $end;

  my $extDbRls = $self->getExtDbRlsId($self->getArg('extDbRelSpec'))
      || die "Couldn't retrieve external database!\n";

  my $restart = $self->getArg('restart');

  if($restart){
    my $restartIds = join(",",@$restart);
    %done = $self->restart($restartIds);
    $self->log("Restarting with algorithm invocation IDs: $restartIds");
  }


  my $file = $self->getArg('inputFile');
  open (FILE, "<$file") or $self->error("Couldn't open file '$file': $!\n");

  while(<FILE>){
    chomp;

    my @data = split(/\t/, $_);

    my $sourceId = $data[0];

    unless(%done->{$sourceId}){

      my $aaSeqId = &ApiCommonData::Load::Util::getAASeqIdFromGeneId($self,$sourceId);

      if($aaSeqId){

	my $newPredAAFeat = $self->createPredictedAAFeature($extDbRls, $sourceId, $aaSeqId);

      if($self->getArg('addLocation')){
	$start = $data[1];
	$end = $data[2];

	my $newAALoc = $self->createAALocation($start, $end);

	$$newPredAAFeat->addChild($$newAALoc);
      }

	$$newPredAAFeat->submit();
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


sub createPredictedAAFeature{
  my ($self, $extDbRls, $sourceId, $aaSeqId) = @_;

  my $category = $self->getArg('category');

  my $aaFeature = GUS::Model::DoTS::PredictedAAFeature->new({external_database_release_id => $extDbRls,
							     aa_sequence_id => $aaSeqId,
							     source_id => $sourceId,
							     name=> $category,
							     is_predicted => 1,
							     subclass_view => "PredictedAAFeature",
							    });

  return \$aaFeature;
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

sub restart{
  my ($self, $restartIds) = @_;
  my %done;

  my $sql = "SELECT source_id FROM DoTS.PredictedAAFeature WHERE row_alg_invocation_id IN ($restartIds)";

  my $qh = $self->getQueryHandle();
  my $sth = $qh->prepareAndExecute($sql);

    while(my ($id) = $sth->fetchrow_array()){
	$done{$id}=1;
    }
    $sth->finish();

  return %done;
}

# ----------------------------------------------------------------------

sub undoTables {
  my ($self) = @_;

  return ('DoTS.AALocation',
	  'DoTS.PredictedAAFeature',
	 );
}
