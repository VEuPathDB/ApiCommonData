package ApiCommonData::Load::Plugin::InsertStudy;

@ISA = qw(GUS::PluginMgr::Plugin);

use GUS::Model::SRes::Contact;
use GUS::Model::Study::Study;

# ----------------------------------------------------------------------

use strict;
use GUS::PluginMgr::Plugin;

my $argsDeclaration =
  [

   stringArg({name           => 'name',
            descr          => 'Study Name',
            reqd           => 1,
            constraintFunc => undef,
            isList         => 0, }),

   stringArg({name           => 'extDbRlsSpec',
            descr          => 'External Database Spec for this study',
            reqd           => 1,
            constraintFunc => undef,
            isList         => 0, }),

   stringArg({name           => 'contactName',
            descr          => 'Contact Name - The plugin will try to retrieve',
            reqd           => 0,
            constraintFunc => undef,
            isList         => 0, }),
            
  ];


my $documentation = { purpose          => "",
                      purposeBrief     => "",
                      notes            => "",
                      tablesAffected   => "",
                      tablesDependedOn => "",
                      howToRestart     => "",
                      failureCases     => "" };

# ----------------------------------------------------------------------

sub new {
  my ($class) = @_;
  my $self = {};
  bless($self,$class);

  $self->initialize({ requiredDbVersion => 3.6,
                      cvsRevision       => '$Revision$',
                      name              => ref($self),
                      argsDeclaration   => $argsDeclaration,
                      documentation     => $documentation});

  return $self;
}

# ======================================================================

sub run {
  my ($self) = @_;

 my $contactName = $self->getArg('contactName');
 $contactName = "Not Assigned" unless($contactName);
 
 my $contact = GUS::Model::SRes::Contact->new({name => $contactName});
 $contact->retrieveFromDB();

 my $extDbRlsSpec = $self->getArg('extDbRlsSpec');
 
 my $extDbRlsId = $self->getExtDbRlsId($extDbRlsSpec);
 
 my $studyName = $self->getArg('name');
 my $study = GUS::Model::Study::Study->new({name => $studyName, 
                                            external_database_release_id => $extDbRlsId,
                                           }); 

 unless($study->retrieveFromDB()){
	$study->setParent($contact);
	$study->submit();
	return("Loaded 1 Study.Study with name $studyName.")
 }
 return("Study.Study with name $studyName and extDbRlsSpec $extDbRlsSpec already exists. Nothing was loaded");
}
	

sub undoTables {
  my ($self) = @_;

  return ('Study.Study'
     );
}

1;
