package ApiCommonData::Load::Plugin::InsertAnalyisMethod;
@ISA = qw(GUS::PluginMgr::Plugin);
 
use strict;

use FileHandle;
use GUS::ObjRelP::DbiDatabase;
use GUS::Model::ApiDB::AnalysisMethod;
use GUS::PluginMgr::Plugin;

$| = 1;


my $argsDeclaration =
[

 stringArg({name => 'name',
	    descr => '',
	    constraintFunc => undef,
	    reqd => 1,
	    isList => 0
	   }),

 stringArg({name => 'version',
	    descr => '',
	    constraintFunc => undef,
	    reqd => 1,
	    isList => 0
	   }),

 stringArg({name => 'input',
	    descr => '',
	    constraintFunc => undef,
	    reqd => 1,
	    isList => 0
	   }),

 stringArg({name => 'output',
	    descr => '',
	    constraintFunc => undef,
	    reqd => 1,
	    isList => 0
	   }),

 stringArg({name => 'parameters',
	    descr => '',
	    constraintFunc => undef,
	    reqd => ,
	    isList => 0
	   }),

 stringArg({name => 'description',
	    descr => '',
	    constraintFunc => undef,
	    reqd => 1,
	    isList => 0
	   }),

 stringArg({name => 'pubmedId',
	    descr => '',
	    constraintFunc => undef,
	    reqd => ,
	    isList => 0
	   }),

 stringArg({name => 'citation',
	    descr => 'the citation provided by ncbi for the pubmed_id',
	    constraintFunc => undef,
	    reqd => ,
	    isList => 0
	   }),

 stringArg({name => 'url',
	    descr => '',
	    constraintFunc => undef,
	    reqd => ,
	    isList => 0
	   }),

 stringArg({name => 'credits',
	    descr => '',
	    constraintFunc => undef,
	    reqd => ,
	    isList => 0
	   }),

 ];


my $purposeBrief = <<PURPOSEBRIEF;
Insert a description of an analysis method.
PURPOSEBRIEF

my $purpose = <<PLUGIN_PURPOSE;
Insert a description of an analysis method.
PLUGIN_PURPOSE

my $tablesAffected = [
['ApiDB.AnalysisMethod','One row is added to this table']
];

my $tablesDependedOn = [];

my $howToRestart = <<PLUGIN_RESTART;
This plugin cannot be restarted.
PLUGIN_RESTART

my $failureCases = <<PLUGIN_FAILURE_CASES;
unknown
PLUGIN_FAILURE_CASES

my $notes = <<PLUGIN_NOTES;
This plugin is typically called to document the methods used in a workflow step.It assumes that the pubmed_id has been resolved into a citation previously.
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

    my $name = $self->getArg('name');
    my $version = $self->getArg('version');
    my $input = $self->getArg('input');
    my $output = $self->getArg('output');
    my $parameters = $self->getArg('parameters');
    my $description = $self->getArg('description');
    my $pubmed_id = $self->getArg('pubmedId');
    my $citation_string = $self->getArg('citation');
    my $url = $self->getArg('url');
    my $credits = $self->getArg('credits');

   my $am = GUS::Model::ApiDB::AnalysisMethod->
     new(
	 {'name' => $name,
	 'version' => $version,
	 'input' => $input,
	 'output' => $output,
	 'parameters' => $parameters,
	 'description' => $description,
	 'pubmed_id' => $pubmed_id,
	 'citation_string' => $citation_string,
	 'url' => $url,
	 'credits' => $credits}
	);

    $am->submit();
   }
   return "Inserted 1 method into AnalysisMethod";
}

sub undoTables {
  my ($self) = @_;

  return ('ApiDB.AnalysisMethod',
         );
}

1;
