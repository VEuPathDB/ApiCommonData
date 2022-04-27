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
 
 my $rowCount = 0;
 open(my $data, '<', $fileName) || die "Could not open file $fileName: $!";
 while (my $line = <$data>) {
   my $rowCount++;
   chomp $line;
   my @values = split ("\t", $line);
   my $id = $values[0];
   my $name = $values[1];
   my $projectName = $values[2];
   my $row = GUS::Model::ApiDB::LegacyDataset->new({dataset_presenter_id => $id,
                                                     dataset_presenter_name => $name,
                                                     project_name => $projectName,
                                                     external_database_release_id => $extDbRlsId,
                                                     });
   $row->submit();
 }
 print "$rowCount rows added.\n"
}


 



sub undoTables {
  my ($self) = @_;

  return ('ApiDB.LegacyDataset'
     );
}

1;
