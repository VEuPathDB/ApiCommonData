package ApiCommonData::Load::Plugin::InsertPlatformReporter;
@ISA = qw(GUS::PluginMgr::Plugin);

use strict;

use lib "$ENV{GUS_HOME}/lib/perl";

use GUS::PluginMgr::Plugin;

use Bio::SeqIO;

use GUS::Model::Platform::ArrayDesign;
use GUS::Model::Platform::Reporter;

my $argsDeclaration =
[
   fileArg({name           => 'inputFile',
	    descr          => 'Fasta File for array probes',
	    reqd           => 1,
	    mustExist      => 1,
	    format         => 'fasta',
	    constraintFunc => undef,
	    isList         => 0, }),

   stringArg({name => 'extDbSpec',
	      descr => 'External database from whence this data came|version',
	      constraintFunc=> undef,
	      reqd  => 1,
	      isList => 0
	     }),

   stringArg({name => 'arrayDesignName',
	      descr => 'Name of the ReporterSet;  Will be added if it does not already exist',
	      constraintFunc=> undef,
	      reqd  => 1,
	      isList => 0
	     }),
];

my $purpose = <<PURPOSE;
Insert Reporters into Platform Schema
PURPOSE

my $purposeBrief = <<PURPOSE_BRIEF;
Insert Reporters into Platform Schema
PURPOSE_BRIEF

my $notes = <<NOTES;
NOTES

my $tablesAffected = <<TABLES_AFFECTED;
TABLES_AFFECTED

my $tablesDependedOn = <<TABLES_DEPENDED_ON;
TABLES_DEPENDED_ON

  my $howToRestart = <<RESTART;
There are no restart facilities for this plugin
RESTART

my $failureCases = <<FAIL_CASES;
FAIL_CASES

my $documentation = { purpose          => $purpose,
		      purposeBrief     => $purposeBrief,
		      notes            => $notes,
		      tablesAffected   => $tablesAffected,
		      tablesDependedOn => $tablesDependedOn,
		      howToRestart     => $howToRestart,
		      failureCases     => $failureCases };

sub new {
  my ($class) = @_;
  my $self = {};
  bless($self,$class);

  $self->initialize({ requiredDbVersion => 4.0,
		      cvsRevision       => '$Revision$',
		      name              => ref($self),
		      argsDeclaration   => $argsDeclaration,
		      documentation     => $documentation});

  return $self;
}

sub run {
  my ($self) = @_;

  my $fsaFile = $self->getArg('inputFile');

  my $arrayDesignName = $self->getArg('arrayDesignName');

  my $extDbSpec = $self->getArg('extDbSpec');
  my $extDbRlsId = $self->getExtDbRlsId($extDbSpec);
  my $version;
  if ($extDbSpec =~ /(.+)\|(.+)/) {
      $version = $2
  }

  my $arrayDesign = GUS::Model::Platform::ArrayDesign->new({name => $arrayDesignName,
                                                            version => $version,
                                                            external_database_release_id => $extDbRlsId});  
  $arrayDesign->retrieveFromDB();

  my $fsa  = Bio::SeqIO->new(-file => $fsaFile,
                             -format => 'fasta');


  my $count;
  while ( my $seq = $fsa->next_seq() ) {
    my $primaryId = $seq->primary_id();
    my $sequence = $seq->seq();

    my $reporter = GUS::Model::Platform::Reporter->new({source_id => $primaryId,
                                                        external_database_release_id => $extDbRlsId,
                                                        sequence => $sequence,
                                                       });

    $reporter->setParent($arrayDesign);
    $reporter->submit() unless $reporter->retrieveFromDB();;

    $self->undefPointerCache();
    $count++;
  }  

  $fsa->close();

  return("Loaded $count rows into Platform::Reporter");
}


sub undoTables {
  my ($self) = @_;

    return ( 
      'Platform.Reporter',
      'Platform.ArrayDesign',
        );
}

1;
