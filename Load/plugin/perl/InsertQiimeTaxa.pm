package ApiCommonData::Load::Plugin::InsertQiimeTaxa;
@ISA = qw( GUS::PluginMgr::Plugin);

use strict 'vars';

use GUS::PluginMgr::Plugin;
use lib "$ENV{GUS_HOME}/lib/perl";
use FileHandle;
use Carp;
use GUS::Supported::Util;

use GUS::Model::ApiDB::QiimeTaxa;
use GUS::Model::DoTS::ExternalNASequence;
use GUS::Model::SRes::ExternalDatabase;
use GUS::Model::SRes::ExternalDatabaseRelease;
use Data::Dumper;

my $purposeBrief = <<PURPOSEBRIEF;
Insert non Genbank sequenece data from a greengenes assignment file. 
PURPOSEBRIEF

my $purpose = <<PURPOSE;
Insert non genbank sequence data from a greengenes assignment file. 
PURPOSE

my $tablesAffected = [
  ['ApiDB.QiimeTaxa',     'One row inserted per Taxa string row']
];

my $tablesDependedOn = [
  ['DoTS.ExternalNASequence', 'get the na_sequence_id for each row']
];

my $howToRestart = "There is currently no restart method.";

my $failureCases = "There are no know failure cases.";

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
    stringArg({name           => 'extDbName',
               descr          => 'the external database name to tag the data with.',
               reqd           => 1,
               constraintFunc => undef,
               isList         => 0,
             }),
    stringArg({name           => 'extDbRlsVer',
               descr          => 'the version of the external database to tag the data with.',
               reqd           => 1,
               constraintFunc => undef,
               isList         => 0,
             }),
    fileArg({  name           => 'inputFile',
               descr          => 'file containing the data',
               constraintFunc => undef,
               reqd           => 1,
               mustExist      => 1,
               isList         => 0,
               format         =>'Tab-delimited.'
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

  my ($self) = @_;
  my $dbiDb = $self->getDb();
  $dbiDb->setMaximumNumberOfObjects(1000000);

  my $extDbRlsId = $self->getExtDbRlsId($self->getArg('extDbName'), $self->getArg('extDbRlsVer'));
  my $inputFile = $self->getArg('inputFile');

  open(IN, "<$inputFile") or die "unable to open input file : $!";
  
  my $count = 0;
  while(my $line =<IN>) {
    $line =~s/\n|\r//g;
    my ($source_id, $taxa_string) = split("\t", $line);

    

    my $qiime_taxa = GUS::Model::ApiDB::QiimeTaxa->new({
                                                        'taxa_string'                               => $taxa_string,
                                                        'source_id'                                  => $source_id,
                                                        'external_database_release_id' =>$extDbRlsId
                                                       });
    
    unless ($qiime_taxa->retrieveFromDB()) {
      $qiime_taxa->submit;
      $self->undefPointerCache() if $count++ % 1000 == 0;
    }
  } 

}

sub undoTables {
  my ($self) = @_;

  return ('ApiDB.QiimeTaxa',
	 );
}

1;
