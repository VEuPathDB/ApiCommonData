package ApiCommonData::Load::Plugin::CreateGenesForGeneFeatures;
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
@ISA = qw(GUS::PluginMgr::Plugin);


use strict;
use GUS::PluginMgr::Plugin;
use GUS::Model::DoTS::GeneFeature;
use GUS::Model::DoTS::GeneInstance;
use GUS::Model::DoTS::Gene;

$| = 1;

# ---------------------------------------------------------------------------
# Load Arguments
# ---------------------------------------------------------------------------

sub getArgumentsDeclaration{
  my $argsDeclaration =
    [

     fileArg({name => 'file',
	      descr => 'file containing the gene feature groups',
	      constraintFunc=> undef,
	      reqd  => 1,
	      isList => 0,
	      mustExist => 1,
	      format => 'cluster_1009: [5] (TGRH_093550, TGVEG_101000, TGME49_115860, TGME49_115870, TGRH_093560)'
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
Plugin to create genes for the gene features in the input file
PURPOSEBRIEF

my $purpose = <<PLUGIN_PURPOSE;
Plugin to create genes for the gene features in the input file
PLUGIN_PURPOSE

my $syntax = <<SYNTAX;
Standard plugin syntax.
SYNTAX

#check the documentation for this
my $tablesAffected = [['GUS::Model::DoTS::Gene', 'inserts a single row per row of input file'],['GUS::Model::DoTS::GeneInstance', 'inserts a row for each genefeature from input file']];

my $tablesDependedOn = [['GUS::Model::DoTS::GeneFeature', 'simply grouping these into genes']];

my $howToRestart = <<PLUGIN_RESTART;
#Explicit restart using the rownum printed in the STDOUT file. 
PLUGIN_RESTART

my $failureCases = <<PLUGIN_FAILURE_CASES;
PLUGIN_FAILURE_CASES

my $notes = <<PLUGIN_NOTES;
Requires input file in the correct format and all genefeatures to be found ... source_ids from genefeatures must be unique
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
	               cvsRevision => '$Revision: 38813 $', # cvs fills this in!
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

  $self->checkFileFormat();

  my $numFeatures = $self->processFile();

  my $resultDescrip = "$numFeatures rows inserted into gene";

  $self->setResultDescr($resultDescrip);
  $self->log($resultDescrip);
}

sub checkFileFormat {
  my ($self) = @_;

  open (FILE, $self->getArg('file'));

  while (<FILE>) {
    if ($_ !~ /^cluster.*?\(.*\)/) {
      $self->userError("Check file format - format incorrect for at least one line in ".$self->getArg('file')."\n$_");
    }
  }
}

sub processFile {
  my ($self) = @_;

  my $processed = $self->getArg('restart') ? $self->getArg('restart') : 0;

  my $row;

  open (FILE, $self->getArg('file'));

  while (<FILE>) {
    chomp;
    $row++;
    next if ($processed >= $row);

    if(/^(cluster_\d+):.*?\((.*)\)/){
      my @gf = split(", ",$2);
      my $gene = $self->makeGeneAndInstances($1,\@gf);
      
      my $submitted = $gene->submit();

      $processed++;
      $self->logData("processed file row number $processed with $submitted insertions into db\n");
      
      $gene->undefPointerCache();
    }else{
      $self->userError("Check file format - format incorrect for at least one line in ".$self->getArg('file')."\n");
    }
  }

  return $processed;
}

sub makeGeneAndInstances {
   my ($self,$cluster,$gf) = @_;

   my $gene = GUS::Model::DoTS::Gene->new();

   foreach my $gfid (@$gf){
     my $geneFeat = GUS::Model::DoTS::GeneFeature->new({'source_id' => $gfid});
     if($geneFeat->retrieveFromDB()){
       my $geneInstance = GUS::Model::DoTS::GeneInstance->new({'is_reference' => 0});
       $geneInstance->setParent($gene);
       $geneInstance->setParent($geneFeat);
     }else{
      $self->userError("Unable to retrieve geneFeature $gfid from db\n");
     }
   }

   return $gene;
}

sub undoTables {
  my ($self) = @_;

  return ('DoTS.GeneInstance',
	  'DoTS.Gene',
	 );
}
