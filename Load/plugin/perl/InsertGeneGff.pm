package ApiCommonData::Load::Plugin::InsertGeneGff;

@ISA = qw( GUS::PluginMgr::Plugin); 

use strict;

use GUS::PluginMgr::Plugin;
use lib "$ENV{GUS_HOME}/lib/perl";
use GUS::Model::ApiDB::GeneGff;


my $purposeBrief = <<PURPOSEBRIEF;
Populate the GeneGff table from a GFF file
PURPOSEBRIEF

my $purpose = <<PLUGIN_PURPOSE;
Populate the GeneGff table from a GFF file
PLUGIN_PURPOSE

my $tablesAffected =
	[['ApiDB.GeneGff', ''],
];

my $tablesDependedOn = [];


my $howToRestart = <<PLUGIN_RESTART;
There is no restart method.
PLUGIN_RESTART

my $failureCases = <<PLUGIN_FAILURE_CASES;
There are no known failure cases.
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
   stringArg({ name => 'gffFile',
	       descr => 'gff data file',
	       constraintFunc=> undef,
	       reqd  => 1,
	       isList => 0,
	       mustExist => 1,
	     }),
   stringArg({ name => 'projectName',
	       descr => 'EuPathDB component project',
	       constraintFunc=> undef,
	       reqd  => 1,
	       isList => 0,
	     }),
  ];


sub new {
    my ($class) = @_;
    my $self = {};
    bless($self,$class); 


    $self->initialize({requiredDbVersion => 4.0,
		       cvsRevision => '$Revision$', # cvs fills this in!
		       name => ref($self),
		       argsDeclaration => $argsDeclaration,
		       documentation => $documentation
		      });

    return $self;
}

sub run {
    my ($self) = @_; 

    my $gffFile = $self->getArg('gffFile');
    my $projectName = $self->getArg('projectName');

    open(GFF, "<", $gffFile) or die "Cannot open file $gffFile for reading: $!";
    my ($currentGene, $currentContent, $lineCount, $insertCount);
    $self->getDb()->manageTransaction(0,'begin');

    while (<GFF>) {

      # check for gene record
      if (/\tgene\t.*\sID "*(\S*?)"* /) {

	# write record for previous gene (if any)
	if ($currentGene) {
	  my $geneGff
	    = GUS::Model::ApiDB::GeneGff->new({
					       source_id => $currentGene,
					       project_id => $projectName,
					       table_name => "gff_record",
					       row_count => 1,
					       content => $currentContent,
					      });
	  $geneGff->submit();
	  if ($insertCount++ % 1000 == 0) {
	    $self->getDb()->manageTransaction(0,'commit');
	    $self->getDb()->manageTransaction(0,'begin');
	  }
	}

	# reset info for next gene
	$currentGene = $1;
	$currentContent = "";
	$lineCount = 0;
      }

      $currentContent .= $_;
      $lineCount++;
    }

    # write record for final gene (unless there were none)
    if ($currentGene) {
      my $geneGff
	= GUS::Model::ApiDB::GeneGff->new({
					   source_id => $currentGene,
					   project_id => $projectName,
					   table_name => "gff_record",
					   row_count => 1,
					   content => $currentContent,
					  });
      $geneGff->submit();
      $insertCount++;
    }

    $self->getDb()->manageTransaction(0,'commit');
    $self->getDb()->manageTransaction(0,'begin');

    close GFF;

    return "loaded GFF3 records for $insertCount genes";
}

sub undoTables {
  my ($self) = @_;

  return ('ApiDB.GeneGff');
}



1;
