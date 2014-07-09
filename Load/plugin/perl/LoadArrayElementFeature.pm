package ApiCommonData::Load::Plugin::LoadArrayElementFeature;
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
  # GUS4_STATUS | dots.gene                      | manual | unreviewed
die 'This file has broken or unreviewed GUS4_STATUS rules.  Please remove this line when all are fixed or absent';
#^^^^^^^^^^^^^^^^^^^^^^^^^ End GUS4_STATUS ^^^^^^^^^^^^^^^^^^^^
@ISA = qw(ApiCommonData::Load::Plugin::LoadExpressionFeature);



use strict;
use GUS::PluginMgr::Plugin;

use GUS::Model::DoTS::NALocation;
use GUS::Model::Core::Algorithm;
use GUS::Model::SRes::ExternalDatabase;
use GUS::Model::SRes::ExternalDatabaseRelease;

use GUS::Model::DoTS::NASequence;
use GUS::Model::DoTS::ExternalNASequence;

use ApiCommonData::Load::Plugin::LoadExpressionFeature;
use Bio::Tools::GFF;
use Bio::SeqFeature::Gene::Exon;

$| = 1;

# ---------------------------------------------------------------------------
# Load Arguments
# ---------------------------------------------------------------------------

sub getArgumentsDeclaration{
  my $argsDeclaration =
    [

     fileArg({name => 'fileName',
	      descr => 'full path of file containing results of the analysis',
	      constraintFunc=> undef,
	      reqd  => 1,
	      isList => 0,
	      mustExist => 1,
	      format => 'gff2 file format'      
	     }),

     integerArg({name  => 'restart',
		 descr => 'The last line number from the file processed, read from the STDOUT file.',
		 constraintFunc=> undef,
		 reqd  => 0,
		 isList => 0
		}),

     stringArg({name => 'extDbSpec',
		descr => 'External Database Spec.  Will be created if not retrieved',
		constraintFunc => undef,
		reqd => 1,
		isList => 0
	       }),

    ];


  return $argsDeclaration;
}



# --------------------------------------------------------------------------
# Documentation
# --------------------------------------------------------------------------

sub getDocumentation {

my $purposeBrief = <<PURPOSEBRIEF;
Plug_in to populate DoTS.ArrayElementFeature
PURPOSEBRIEF

my $purpose = <<PLUGIN_PURPOSE;
plug_in that inserts Suffix::Array::match mapping results into DoTS.ArrayElementFeature and DoTS.NALocation.
PLUGIN_PURPOSE

my $syntax = <<SYNTAX;
Standard plugin syntax.
SYNTAX

#check the documentation for this
my $tablesAffected = [['GUS::Model::DoTS::NAFeature', 'inserts a single row per row of result file.  ArrayElementFeature'],['GUS::Model::DoTS::NALocation', 'inserts a row for each row of result file'],['GUS::Model::Core::Algorithm','inserts a single row for mapping method when not present']];

my $tablesDependedOn = [['GUS::Model::SRes::ExternalDatabaseRelease', 'Gets an existing external_database-release_id'],['GUS::Model::DoTS::NASequence', 'Gets an existing na_sequence_id for subject sequence']];

my $howToRestart = <<PLUGIN_RESTART;
Explicit restart using the rownum printed in the STDOUT file. 
PLUGIN_RESTART

my $failureCases = <<PLUGIN_FAILURE_CASES;
no ExternalDatabaseRelease, NASequence rows corresponding to previously entered dbRelId,tags, or subject sequences.File incorrectly formatted.
PLUGIN_FAILURE_CASES

my $notes = <<PLUGIN_NOTES;
SAGETag and NASequence rows must have been previously entered. Input file must be in the correct format.
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

  my $configuration = {requiredDbVersion => 3.6,
	               cvsRevision => '$Revision$', # cvs fills this in!
		       name => ref($self),
		       revisionNotes => 'make consistent with GUS 3.6',
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


  $self->getExternalDbRelease();

  $self->getPredAlgId();



  my $naSequencesMap = $self->getNaSequenceMapping();

  my ($numFeatures,$numLocations) = $self->processFile($naSequencesMap);

  my $resultDescrip = "$numLocations rows inserted into DoTS.NALocation";

  $self->setResultDescr($resultDescrip);
  $self->log($resultDescrip);

  $resultDescrip = "$numFeatures rows inserted into DoTS.ArrayElementFeature";

  $self->setResultDescr($resultDescrip);
  $self->log($resultDescrip);
  
}



sub processFile {
  my ($self, $naSequenceIds) = @_;

  my $processedLines = $self->getArg('restart') ? $self->getArg('restart') : 0;

  my $processedFeatures = 0;

  my %prevSourceIds;

  my $row;
  my $gffIO = Bio::Tools::GFF->new(-file => $self->getArg('fileName'),
				   -gff_version => 2
				  ) or $self->userError("Could not open gff file for reading.\n");

  while (my $feature = $gffIO->next_feature()) {

    chomp;
    $row++;
    next if ($processedLines >= $row);


    my $orient = $feature->strand == -1 ? 1 : 0;

    my $naSeqId = $naSequenceIds->{$feature->seq_id};
    $self->error("No NaSequenceId found for ".$feature->seq_id) unless($naSeqId);
  
    my ($sourceId) = $feature->get_tag_values("ID") if $feature->has_tag("ID");

    my ($name) = $feature->get_tag_values("Name") if $feature->has_tag("Name");

    my ($exonOrder) = $feature->get_tag_values("ExonOrder") if $feature->has_tag("ExonOrder");

    my %args = ('sourceId'=>$sourceId,'naSeqId'=>$naSeqId, 'start'=>$feature->start(),'end'=>$feature->end(),'tagOrient'=>$orient,'name'=>$name,'exonOrder'=>$exonOrder);

    my $feature = $self->makeFeature(\%args);

    $self->makeNaLoc($feature,\%args);

    my $submitted = $feature->submit();

    $processedLines++;

    if(!($prevSourceIds{$sourceId})){
	$processedFeatures++;

    }

    $prevSourceIds{$sourceId} = $sourceId;
    $feature->undefPointerCache();

    if($processedLines % 500 == 0) {
      $self->logData("processed file row number $processedLines with $submitted insertions into db\n");
    }
  }



  return ($processedFeatures, $processedLines);
}





sub makeFeature {
   my ($self,$args) = @_;

 
   my $class = "GUS::Model::DoTS::ArrayElementFeature";

   eval "require $class";

   if($@) {
     $self->error("Could not find GUS Model object for ArrayElementFeature.\n$@");
   }

   my $name = $args->{'name'};

   my $sourceId = $args->{'sourceId'};

   my $naSeqId = $args->{'naSeqId'};

   my $extDbRls = $self->{'extDbRls'};

   my $algId = $self->{'algId'};

   my $feature = eval {
     $class->new({'name'=>$name,'source_id'=>$sourceId,'na_sequence_id'=>$naSeqId,'external_database_release_id'=>$extDbRls,'prediction_algorithm_id'=>$algId});
   };

   if(!($feature->retrieveFromDB())){
       if($@) {
	   $self->error("Could not create a new object for class $class\n$@");
       }
   }
   return $feature;
}


sub makeNaLoc {
  my ($self, $feature, $args) = @_;

  my $start = $args->{'start'};

  my $end = $args->{'end'};

  my $isReversed = $args->{'tagOrient'};

  my $exonOrder = $args->{'exonOrder'};

  my $naLoc = GUS::Model::DoTS::NALocation->new({'start_min'=>$start,'start_max'=>$start,'end_min'=>$end,'end_max'=>$end,'is_reversed'=>$isReversed,'loc_order'=>$exonOrder});

  $naLoc->setParent($feature);
}


sub undoTables {
  my ($self) = @_;

  return ('DoTS.NALocation',
	  'DoTS.ArrayElementFeature',
	 );
}


1;
