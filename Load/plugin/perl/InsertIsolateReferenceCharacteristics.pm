package ApiCommonData::Load::Plugin::InsertIsolateReferenceCharacteristics;
@ISA = qw(GUS::PluginMgr::Plugin);

use strict;
use CBIL::Util::Disp;
use GUS::PluginMgr::Plugin;


use GUS::Model::Study::Characteristic;
use SRes::OntologyTerm;

use GUS::Supported::Util;


my $argsDeclaration =
  [
   fileArg({name           => 'accFile',
	    descr          => 'file with accessions of reference',
	    reqd           => 1,
	    mustExist      => 1,
	    format         => 'Tab file with header',
	    constraintFunc => undef,
	    isList         => 0, }),
   stringArg({name => 'extDbSpec',
	      descr => 'External database of isolates loaded from a dataset|version',
	      constraintFunc=> undef,
	      reqd  => 1,
	      isList => 0
	     }),
];

my $purpose = <<PURPOSE;
Add isReferenceIsolate characteristic for reference isolates.
PURPOSE

my $purposeBrief = <<PURPOSE_BRIEF;
Add isReferenceIsolate characteristic for reference isolates.
PURPOSE_BRIEF

my $notes = <<NOTES;
NOTES

my $tablesAffected = <<TABLES_AFFECTED;
SRes::OntologyTerm
TABLES_AFFECTED

my $tablesDependedOn = <<TABLES_DEPENDED_ON;
SRes::OntologyTerm
Study::Characteristic
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

  my $extDbRlsSpec = $self->getArg('extDbSpec');
  my $extDbRlsId = $self->getExtDbRlsId($extDbRlsSpec);

  my $sql =
    "SELECT protocol_app_node_id, name
     FROM Study.protocolAppNode
     WHERE external_database_release_id = $extDbRlsId";

  my %popsets;
  my $dbh = $self->getQueryHandle();
  my $sh  = $dbh->prepare($sql);
  $sh->execute();

  while (my ($id,$name) = $sh->fetchrow_array()){
    $popsets{$name} = $id;
  }


  # make ontology term
  my $isRef= GUS::Model::SRes::OntologyTerm->new({name=>'isReferenceIsolate'});
  $isRef->submit();

  my $qualifierId = $isRef->getId();

  my $configFile = $self->getArg('accFile');
  open (IN, $configFile);
  while (<IN>){
    chomp;
    my $panId = $popsets{$_};
    unless ($panId) {
      $self->log("Accession ID not found in database.");
      next;
    }
    my $characteristic = 
      GUS::Model::Study::Characteristic->new({protocol_app_node_id => $panId,
					      qualifier_id => $qualifierId,
					      value => 1
					     });
    $characteristic->submit();
  }

