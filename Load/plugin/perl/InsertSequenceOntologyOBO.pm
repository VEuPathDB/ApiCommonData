#######################################################################
##                   LoadSequenceOnotolgyOBO.pm
##
## Plug-in to load Sequence Ontology from a tab delimited file.
## $Id: InsertSequenceOntology.pm 3400 2005-09-06 19:10:34Z jldommer $
##
## Drafted from the old LoadSequenceOntologyPlugin, Oct, 2005 E.R.
#######################################################################

package ApiComplexa::DataLoad::Plugin::InsertSequenceOntologyOBO;
@ISA = qw(GUS::PluginMgr::Plugin);
 
use strict;

use FileHandle;
use GUS::ObjRelP::DbiDatabase;
use GUS::Model::SRes::SequenceOntology;
use GUS::PluginMgr::Plugin;

$| = 1;


my $argsDeclaration =
[

 fileArg({name => 'inputFile',
	  descr => 'name of the SO OBO file (usually, so.obo)',
	  constraintFunc => undef,
	  reqd => 1,
	  isList => 0,
	  mustExist => 1,
	  format => 'Text'
        }),

 stringArg({name => 'soVersion',
	    descr => 'version of Sequence Ontology',
	    constraintFunc => undef,
	    reqd => 1,
	    isList => 0
	   }),

 stringArg({name => 'soCvsVersion',
	    descr => 'cvs version of Sequence Ontology',
	    constraintFunc => undef,
	    reqd => 1,
	    isList => 0
	   })

 ];


my $purposeBrief = <<PURPOSEBRIEF;
Inserts the Sequence Ontology from so.obo file.
PURPOSEBRIEF

my $purpose = <<PLUGIN_PURPOSE;
Extracts the id, name, and def fields from a so.obo file and inserts new entries into into the SRes.SequenceOntology table in the form so_id, ontology_name, so_version, so_cvs_version, term_name, definition.
PLUGIN_PURPOSE

my $tablesAffected = [
['SRes.SequenceOntology','New SO entries are placed in this table']
];

my $tablesDependedOn = [];

my $howToRestart = <<PLUGIN_RESTART;
This plugin can be restarted.  Before it submits an SO term, it checks for its existence in the database, skipping it if it is already there.
PLUGIN_RESTART

my $failureCases = <<PLUGIN_FAILURE_CASES;
unknown
PLUGIN_FAILURE_CASES

my $notes = <<PLUGIN_NOTES;
This plugin parses OBO format and is valid for any version of so.obo.  It replaces the older versions of this plugin which used the so.definition file.
PLUGIN_NOTES

my $documentation = {purposeBrief => $purposeBrief,
		     purpose => $purpose,
		     tablesAffected => $tablesAffected,
		     tablesDependedOn => $tablesDependedOn,
		     howToRestart => $howToRestart,
		     failureCases => $failureCases,
		     notes => $notes
		    };


sub new {
    my ($class) = @_;
    my $self = {};
    bless($self, $class);

    $self->initialize({requiredDbVersion => 3.5,
		       cvsRevision =>  '$Revision: 3413 $',
		       name => ref($self),
		       argsDeclaration   => $argsDeclaration,
		       documentation     => $documentation
		      });

    return $self;
}

sub run {
    my ($self) = @_;

    my $obo;
    my $type;
    my $count= 0;

    my $soFile = $self->getArg('inputFile');

    open(SO_FILE, $soFile);

    while (<SO_FILE>){
      if (/^\n/) {
        unless ($type ne 'Term') {
           my $soTerm = $self->makeSequenceOntology($obo);
              $soTerm->submit() unless $soTerm->retrieveFromDB();
              $count++;
                  if($count % 100 == 0){
                      $self->log("Submitted $count terms");
                  }
        }
        undef $obo; #may have left over defs.
        undef $type;
      }
      else {
        if (/\[(Term)\]/ || /\[(Typedef)\]/) {
           $type = $1; 
        }
        my ($nam,$val) = split(/\:\s/,$_,2);
        $obo->{$nam} = $val;
      }
   }
   return "Inserted $count terms into SequenceOntology";
}

sub makeSequenceOntology {
   my ($self, $obo) = @_;

   if (!$obo->{'name'} || !$obo->{'id'}) {
      $self->error("Invalid OBO File: missing term name or so id");
   }

   my $definition = $obo->{'def'};
   if ($definition eq '') {$definition = ' '};

   my $soTerm = GUS::Model::SRes::SequenceOntology->
     new({'so_id' => $obo->{'id'},
	  'ontology_name' => 'sequence',
	  'so_version' => $self->getArg('soVersion'),
	  'so_cvs_version' => $self->getArg('soCvsVersion'),
	  'term_name' => $obo->{'name'},
	  'definition' => $definition });
 
   return $soTerm;
}


1;
