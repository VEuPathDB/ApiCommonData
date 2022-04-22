package ApiCommonData::Load::Plugin::InsertLegacyDataset;


@ISA = qw(GUS::PluginMgr::Plugin);

use GUS::Model::ApiDB::LegacyDataset;

# ----------------------------------------------------------------------

use strict;
use GUS::PluginMgr::Plugin;

my $argsDeclaration =
  [
   fileArg({name           => 'legacyDatasetFile',
            descr          => 'file for the sample data',
            reqd           => 1,
            mustExist      => 1,
            format         => '',
            constraintFunc => undef,
            isList         => 0, }),
   
   stringArg({name           => 'extDbRlsSpec',
            descr          => 'External Database Spec for this study',
            reqd           => 1,
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

  $self->initialize({ requiredDbVersion => 4.0,
                      cvsRevision       => '$Revision$',
                      name              => ref($self),
                      argsDeclaration   => $argsDeclaration,
                      documentation     => $documentation});

  return $self;
}

# ======================================================================

sub run {
  my ($self) = @_;

 my $extDbRlsSpec = $self->getArg('extDbRlsSpec');
 
 my $extDbRlsId = $self->getExtDbRlsId($extDbRlsSpec);
 
 my $fileName = $self->getArg('legacyDatasetFile');
 #my $study = GUS::Model::Study::Study->new({name => $studyName, 
 #                                           external_database_release_id => $extDbRlsId,
 #                                          }); 

 unless($study->retrieveFromDB()) {
   $study->submit();
   return("Loaded 1 Study.Study with name $studyName.")
 }

 return("Study.Study with name $studyName and extDbRlsSpec $extDbRlsSpec already exists. Nothing was loaded");
}

sub undoTables {
  my ($self) = @_;

  return ('ApiDB.LegacyDataset'
     );
}

1;
