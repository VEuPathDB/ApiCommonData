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
	  format => 'Two column tab delimited file: dots.nafeature na_feature_id,alias'
        }),
  ];


sub new {
    my ($class) = @_;
    my $self = {};
    bless($self,$class);


    $self->initialize({requiredDbVersion => 3.5,
		       cvsRevision => '$Revision: 15988 $', # cvs fills this in!
		       name => ref($self),
		       argsDeclaration => $argsDeclaration,
		       documentation => $documentation
		      });

    return $self;
}

sub run {
  my ($self) = @_;

  my $mappingFile = $self->getArg('MappingFile');

  my $msg = $self->getMapping($mappingFile);

  return $msg;

}

sub getMapping {
  my ($self, $mappingFile) = @_;

  my $lineCt = 0;

  open (XREFMAP, "$mappingFile") ||
                    die "Can't open the file $mappingFile.  Reason: $!\n";

  while (<XREFMAP>) {
    $self->undefPointerCache(); #if at bottom, not always hit

    next if /^(\s)*$/;
    chomp;

    my @vals = split(/\t/, $_);

    my $na_feature_id = $vals[0];

    my $primary_name = $vals[1];

    $self->makeNaFeatureNaGene($na_feature_id,$primary_name);
    
    $lineCt++;
  }

  close (XREFMAP);

  my $msg = "Finished processing Mapping file, number of lines: $lineCt \n";

  return $msg;
}

sub makeNaFeatureNaGene {
  my ($self, $na_feature_id, $primary_name) = @_;
  
  my $geneID = $self->_getNAGeneId($primary_name);;

  my $gene = GUS::Model::DoTS::NAFeatureNAGene->new({
				na_gene_id => $geneID,
				na_feature_id => $na_feature_id,
			       });

  $gene->submit() unless $gene->retrieveFromDB();

}


sub _getNAGeneId {   
  my ($self, $geneName) = @_;

  $self->{geneNameIds} = {} unless $self->{geneNameIds};

  if (!$self->{geneNameIds}->{$geneName}) {

    my $gene = GUS::Model::DoTS::NAGene->new({name => $geneName});
    unless ($gene->retrieveFromDB()){
      $gene->setIsVerified(0);
      $gene->submit();
    }
    $self->{geneNameIds}->{$geneName} = $gene->getId();
  }
  return $self->{geneNameIds}->{$geneName};
}

sub undoTables{

  my ($self) = @_;

  return ('DoTS.NAFeatureNAGene',
	  'DoTS.NAGene',
	 );
}

1;
