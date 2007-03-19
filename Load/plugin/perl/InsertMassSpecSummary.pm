package ApiCommonData::Load::Plugin::InsertMassSpecSummary;
@ISA = qw( GUS::PluginMgr::Plugin);

use strict;

use GUS::PluginMgr::Plugin;
use lib "$ENV{GUS_HOME}/lib/perl";
use GUS::Model::DoTS::ExternalNASequence;
use GUS::Model::RAD::ElementNASequence;
use Data::Dumper;


my $purposeBrief = <<PURPOSEBRIEF;
Insert mass spec data from a tab file.  The tab file has the the columns of ApiDB.MassSpecSummary, substituting a gene source_id for aa_sequence_id
PURPOSEBRIEF

my $purpose = <<PLUGIN_PURPOSE;
Insert mass spec data from a tab file.  The tab file has the data columns of ApiDB.MassSpecSummary, substituting a gene source_id for aa_sequence_id
PLUGIN_PURPOSE

my $tablesAffected =
	[['DoTS.MassSpecSummary', ''],
];


my $tablesDependedOn = [];


my $howToRestart = <<PLUGIN_RESTART;
There is currently no restart method.
PLUGIN_RESTART

my $failureCases = <<PLUGIN_FAILURE_CASES;
There are no known failure cases.
PLUGIN_FAILURE_CASES

my $notes = <<PLUGIN_NOTES;
Here are the tab file columns:
 GENE_SOURCE_ID
 DEVELOPMENTAL_STAGE
 IS_EXPRESSED
 NUMBER_OF_SPANS
 SEQUENCE_COUNT
 SPECTRUM_COUNT
 AA_SEQ_PERCENT_COVERED
 AA_SEQ_LENGTH
 AA_SEQ_MOLECULAR_WEIGHT
 AA_SEQ_PI
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
   stringArg({name => 'extDbName',
	      descr => 'the external database name to tag the data with.',
	      reqd => 1,
	      constraintFunc => undef,
	      isList => 0,
	     }),
   stringArg({name => 'extDbRlsVer',
	      descr => 'the version of the external database to tag the data with.',
	      reqd => 1,
	      constraintFunc => undef,
	      isList => 0,
	     }),
     fileArg({name => 'inputFile',
	      descr => 'file containing the data',
	      constraintFunc=> undef,
	      reqd  => 1,
	      mustExist => 1,
	      isList => 0,
	      format=>'Tab-delimited.  See ApiDB.MassSpecSummary for columns'
	     }),

  ];


sub new {
    my ($class) = @_;
    my $self = {};
    bless($self,$class); 


    $self->initialize({requiredDbVersion => 3.5,
		       cvsRevision => '$Revision$', # cvs fills this in!
		       name => ref($self),
		       argsDeclaration => $argsDeclaration,
		       documentation => $documentation
		      });

    return $self;
}

sub run {
  my ($self) = @_; 

  my $extDbRlsId = $self->getExtDbRlsId($self->getArg('extDbName'),
					$self->getArg('extDbRlsVer'));

  die "Couldn't find external_database_release_id" unless $extDbRlsId;

  my $inputFile = $self->getArg('inputFile');

  open(FILE, $inputFile) || $self->error("couldn't open file '$inputFile' for reading");

  my $count = 0;
  while (FILE) {
    my @data = split(/\t/);
    scalar(@data) == 10 || $self->error("wrong number of columns in line: '$_'");

    my $aaSeqId = 
      ApiCommonData::Load::Util::getAASeqIdFromGeneId($self, $data[0]);

    my $objArgs = {
		   aa_sequence_id => $aaSeqId,
		   developmental_stage => $data[1],
		   is_expressed => $data[2],
		   number_of_spans => $data[3],
		   sequence_count => $data[4],
		   spectrum_count => $data[5],
		   aa_seq_percent_covered => $data[6],
		   aa_seq_length => $data[7],
		   aa_seq_molecular_weight => $data[8],
		   aa_seq_pi		   => $data[9],
		  };
    my $mss = GUS::Model::ApiDB::MassSpecSummary->new($objArgs);
    $mss->submit();
    $count++;
  }

  return "Inserted $count rows";
}

sub undoTables {
  my ($self) = @_;

  return ('ApiDB.MassSpecSummary');
}



1;
