package ApiCommonData::Load::Plugin::InsertGeneNamesFromTabFile;
@ISA = qw(GUS::PluginMgr::Plugin);

#######################################
#    InsertGeneNamesFromTabFile.pm
#  
#   Plugin to load GeneName numbers from a
#   variety of tab delimited files. 
#  
#
# Vishal Nayak, Nov, 2010
#######################################

use strict;

use DBI;
use CBIL::Util::Disp;
use GUS::PluginMgr::Plugin;
use ApiCommonData::Load::Util;
use GUS::Model::DoTS::Gene;
use GUS::Model::ApiCommonData::GeneName;
use Data::Dumper;

# ----------------------------------------------------------
# Load Arguments
# ----------------------------------------------------------

sub getArgsDeclaration {
my $argsDeclaration  =
[
stringArg({name => 'geneNameFile',
         descr => 'path and filename for the data file',
         constraintFunc=> undef,
         reqd  => 1,
         isList => 0,
        }),
stringArg({ name => 'genomeDbName',
		 descr => 'externaldatabase name for genome sequences scanned',
		 constraintFunc=> undef,
		 reqd  => 1,
		 isList => 0
	 }),
stringArg({ name => 'genomeDbVer',
	  descr => 'externaldatabaserelease version used for genome sequences scanned',
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

my $description = <<NOTES;
Application to load gene names from tab-delimited files.  The files contain the source_id and the gene name. 
NOTES

my $purpose = <<PURPOSE;
Load Gene Names from tab-delimited files.
PURPOSE

my $purposeBrief = <<PURPOSEBRIEF;
Load Gene Names.
PURPOSEBRIEF

my $syntax = <<SYNTAX;
SYNTAX

my $notes = <<NOTES;
NOTES

my $tablesAffected = <<AFFECT;
ApiDB.GeneName
AFFECT

my $tablesDependedOn = <<TABD;
DoTS.Gene
TABD

my $howToRestart = <<RESTART;
The submit does a retrieveFromDb test for the new value to avoid duplicates, so you can restart simply by restatring in the middle of a run.
RESTART

my $failureCases = <<FAIL;
FAIL

my $documentation = {purpose=>$purpose, purposeBrief=>$purposeBrief,tablesAffected=>$tablesAffected,tablesDependedOn=>$tablesDependedOn,howToRestart=>$howToRestart,failureCases=>$failureCases,notes=>$notes};

return ($documentation);

}


#*****************************************************
#Let there be objects!
#*****************************************************
sub new {
   my $class = shift;
   my $self = {};
   bless($self, $class);
                                                                                                                             
      my $documentation = &getDocumentation();
                                                                                                                             
      my $args = &getArgsDeclaration();
                                                                                                                             
      $self->initialize({requiredDbVersion => 3.5,
                     cvsRevision => '$Revision: 30461 $',
                     name => ref($self),
                     argsDeclaration   => $args,
                     documentation     => $documentation
                    });
   return $self;
}


###############################################################
#Main Routine
##############################################################

sub run{
  my $self = shift;

  my $genomeReleaseId = $self->getExtDbRlsId($self->getArg('genomeDbName'),
						 $self->getArg('genomeDbVer')) || $self->error("Can't find external_database_release_id for genome");
  my $tabFile = $self->getArg('geneNameFile');

  my $processed;

  open(FILE,$tabFile) || $self->error("$tabFile can't be opened for reading");

  while(<FILE>){
      next if (^\s*$);

      my ($sourceId, $product) = split(/\t/,$_);

      my $preferred = 0;

      my $gene = GUS::Model::DoTS::Gene->new({name => $sourceId});
	       
      if($gene->retrieveFromDB()){
	  my $geneName = $gene->getChild("GUS::Model::ApiDB::GeneName");

	  $preferred = 1 unless $geneName->retrieveFromDB();

	  my $geneId = $gene->getGeneId();	       
    
	  $self->makeGeneName($genomeReleaseId,$geneId,$geneName,$preferred);
  
	  $processed++;
      }else{
	  $self->warn("Gene with source id: $sourceId cannot be found");
      }  
  }        


  $self->undefPointerCache();

  return "$processed gene names parsed and loaded";	  
  
}

sub makeGeneName {
  my ($self,$genomeReleaseId,$geneId,$name,$preferred) = @_;

  my $geneName = GUS::Model::ApiDB::GeneName->new({'gene_id' => $geneId,
						    'external_database_release_id' => $genomeReleaseId,
						     'name' => $name,
						     'is_preferred' => $preferred});

  $geneName->submit() unless $geneName->retrieveFromDB();
}


sub undoTables {
  return ('ApiDB.GeneName',
	 ); 
}

return 1;

