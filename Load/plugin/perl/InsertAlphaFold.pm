package ApiCommonData::Load::Plugin::InsertAlphaFold;
@ISA = qw(GUS::PluginMgr::Plugin);

use strict;
use GUS::PluginMgr::Plugin;
use GUS::Supported::Util;
use GUS::Model::ApiDB::AlphaFold;
#use GUS::Model::ApiDB::PhenotypeResult;
#use GUS::Model::ApiDB::NaFeaturePhenotypeModel;
#use GUS::Model::SRes::OntologyTerm;
use Data::Dumper;
use File::Temp qw/ tempfile /;

sub getArgsDeclaration {
    my $argsDeclaration  =
	[
	 
	 stringArg({ name => 'inputFile',
		     descr => 'accession_ids.txt file from AlphaFold',
		     constraintFunc=> undef,
		     reqd  => 1,
		     isList => 0,
		     mustExist => 1,
		   }),

   stringArg({name => 'extDbSpec',                                                                                                                                                                         
              descr => 'External database from whence this data came|version',
              constraintFunc=> undef,
              reqd  => 1,
              isList => 0
             }),
	];
    
    return $argsDeclaration;
}


sub getDocumentation {
    
    my $description = <<NOTES;
Load mappings between Uniprot ids and AlphaFold ids.
NOTES
	
	my $purpose = <<PURPOSE;
Load mappings between Uniprot ids and AlphaFold ids.
PURPOSE
	
	my $purposeBrief = <<PURPOSEBRIEF;
Load mappings between Uniprot ids and AlphaFold ids.
PURPOSEBRIEF
	
	my $syntax = <<SYNTAX;
SYNTAX
	
	my $notes = <<NOTES;
NOTES
	
	my $tablesAffected = <<AFFECT;
ApiDB.AlphaFold
AFFECT
	
	my $tablesDependedOn = <<TABD;
TABD
	
	my $howToRestart = <<RESTART;
There are no restart facilities for this plugin
RESTART
	
	my $failureCases = <<FAIL;
FAIL
	
	my $documentation = {purpose=>$purpose, purposeBrief=>$purposeBrief,tablesAffected=>$tablesAffected,tablesDependedOn=>$tablesDependedOn,howToRestart=>$howToRestart,failureCases=>$failureCases,notes=>$notes};
    
    return ($documentation);
}



sub new {
    my $class = shift;
    my $self = {};
    bless($self, $class);
    
    my $documentation = &getDocumentation();
    
    my $args = &getArgsDeclaration();
    
    $self->initialize({requiredDbVersion => 4.0,
		       cvsRevision => '$Revision$',
		       name => ref($self),
		       argsDeclaration   => $args,
		       documentation     => $documentation
		      });
    return $self;
}

sub run {
    my $self = shift;
   
    my $extDbSpec = $self->getArg('extDbSpec');
    my $extDbRlsId = $self->getExtDbRlsId($extDbSpec) or die "Couldn't find source db: $extDbSpec\n"; 
    print STDERR Dumper $extDbRlsId;

}

sub writeConfigFile {                                                                                                                                                                                      
  my ($self, $configFile, $inputFile, $extDbRlsId) = @_;

  my $modDate = uc(strftime("%d-%b-%Y", localtime));
  my $database = $self->getDb();
  my $projectId = $database->getDefaultProjectId();
  my $userId = $database->getDefaultUserId();
  my $groupId = $database->getDefaultGroupId();
  my $algInvocationId = $database->getDefaultAlgoInvoId();
  my $userRead = $database->getDefaultUserRead();
  my $userWrite = $database->getDefaultUserWrite();
  my $groupRead = $database->getDefaultGroupRead();
  my $groupWrite = $database->getDefaultGroupWrite();
  my $otherRead = $database->getDefaultOtherRead();
  my $otherWrite = $database->getDefaultOtherWrite();

  open(CONFIG, "> $configFile") or die "Cannot open file $configFile For writing:$!";

  print CONFIG "LOAD DATA
CHARACTERSET UTF8
INFILE '$inputFile'
APPEND
INTO TABLE ApiDB.AlphaFold
REENABLE DISABLED_CONSTRAINTS
FIELDS TERMINATED BY ','
TRAILING NULLCOLS
(
alphafold_id,
uniprot_id,
first_residue_index,
last_residue_index,
source_id,
alphafold_version,
external_database_release_id constant $extDbRlsId,
modification_date constant \"$modDate\",
user_read constant $userRead,
user_write constant $userWrite,
group_read constant $groupRead,
group_write constant $groupWrite,
other_read constant $otherRead,
other_write constant $otherWrite,
row_user_id constant $userId,
row_group_id constant $groupId,
row_project_id constant $projectId,
row_alg_invocation_id constant $algInvocationId
)\n";
  close CONFIG;
}



sub undoTables {
  my ($self) = @_;

  return ('ApiDB.NaFeaturePhenotypeModel','ApiDB.PhenotypeResult','ApiDB.PhenotypeModel');
}

1;
