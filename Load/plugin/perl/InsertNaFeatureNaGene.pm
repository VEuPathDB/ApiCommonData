#######################################################################
##                 InsertNaFeatureNaGene.pm
##
## Creates new entries in the tables DoTS.NAGene and DoTS.NAFeatureNAGene
## to external resources that are found in a tab delimited
## file of the form gene na_feature_id, alias
##
#######################################################################

package ApiCommonData::Load::Plugin::InsertNaFeatureNaGene;
@ISA = qw( GUS::PluginMgr::Plugin);

use strict 'vars';

use GUS::PluginMgr::Plugin;
use lib "$ENV{GUS_HOME}/lib/perl";
use FileHandle;
use Carp;
use ApiCommonData::Load::Util;
use GUS::Model::DoTS::NAGene;
use GUS::Model::DoTS::GeneFeature;
use GUS::Model::DoTS::NAFeatureNAGene;

my $purposeBrief = <<PURPOSEBRIEF;
Creates new entries in tables DoTS.NAGene and DoTS.NAFeatureNAGene.
PURPOSEBRIEF

my $purpose = <<PLUGIN_PURPOSE;
Takes in a tab delimited file and creates new entries in tables in tables DoTS.NAGene and DoTS.NAFeatureNAGene.
PLUGIN_PURPOSE

my $tablesAffected =
	[[' DoTS.NAGene', 'The entries representing the new links to the external datasets will go here.'],['DoTS.NAFeatureNAGene', 'The entries representing the new NaGeneNAFeature mappings are created here.']];

my $tablesDependedOn = [['DoTS.NAFeature', 'The genes to be linked to external datasets are found here.']];

my $howToRestart = <<PLUGIN_RESTART;
There is currently no restart method.
PLUGIN_RESTART

my $failureCases = <<PLUGIN_FAILURE_CASES;
PLUGIN_FAILURE_CASES

my $notes = <<PLUGIN_NOTES;

PLUGIN_NOTES

my $documentation = { purpose=>$purpose,
		      purposeBrief=>$purposeBrief,
		      tablesAffected=>$tablesAffected,
		      tablesDependedOn=>$tablesDependedOn,
		      howToRestart=>$howToRestart,
		      failureCases=>$failureCases,
		      notes=>$notes
		    };


my $argsDeclaration = 
  [
   fileArg({name => 'MappingFile',
	  descr => 'pathname for the file containing the mapping data',
	  constraintFunc => undef,
	  reqd => 1,
	  isList => 0,
	  mustExist => 1,
	  format => 'Two column tab delimited file: dots.GeneFeature.source_id ,alias'
        }),
  ];


sub new {
    my ($class) = @_;
    my $self = {};
    bless($self,$class);


    $self->initialize({requiredDbVersion => 3.5,
		       cvsRevision => '$Revision: 22200 $', # cvs fills this in!
		       name => ref($self),
		       argsDeclaration => $argsDeclaration,
		       documentation => $documentation
		      });

    return $self;
}

sub run {
  my ($self) = @_;

  my $mappingFile = $self->getArg('MappingFile');

  my $lineCt = 0;

  open (XREFMAP, "$mappingFile") ||
                    die "Can't open the file $mappingFile.  Reason: $!\n";

  while (<XREFMAP>) {
    chomp;
    next unless $_;
    $self->undefPointerCache(); #if at bottom, not always hit

    my @vals = split(/\t/, $_);

    my $sourceId = $vals[0];
    my $alias = $vals[1];

    my $naFeatureNaGene = $self->makeNaFeatureNaGene($sourceId, $alias);
    $naFeatureNaGene->submit();

    $lineCt++;
  }

  close (XREFMAP);

  return "Finished processing Mapping file, number of lines: $lineCt \n";
}

sub makeNaFeatureNaGene {
  my ($self, $sourceId, $alias) = @_;

  my $naGene = $self->_getNAGeneId($alias);

  my $geneFeature = GUS::Model::DoTS::GeneFeature->new({source_id => $sourceId});

  unless($geneFeature->retrieveFromDB()) {
    $self->userError("No Dots.GeneFeature retrieved from source_id: $sourceId");
  }

  my $naFeatureNaGene = GUS::Model::DoTS::NAFeatureNAGene->new();

  $naFeatureNaGene->setParent($geneFeature);
  $naFeatureNaGene->setParent($naGene);

  return $naFeatureNaGene
}


sub _getNAGeneId {
  my ($self, $alias) = @_;

  my $naGene = GUS::Model::DoTS::NAGene->new({name => $alias});

  unless ($naGene->retrieveFromDB()){
    $naGene->setIsVerified(0);
  }

  return $naGene;
}

sub undoTables{

  my ($self) = @_;

  return ('DoTS.NAFeatureNAGene',
	  'DoTS.NAGene',
	 );
}

1;
