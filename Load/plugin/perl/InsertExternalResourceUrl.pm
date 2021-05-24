package ApiCommonData::Load::Plugin::InsertExternalResourceUrl;
@ISA = qw(GUS::PluginMgr::Plugin);

use strict;
use warnings;

use GUS::PluginMgr::Plugin;
use GUS::Model::ApiDB::ExternalResourceUrl;

sub getArgsDeclaration {
  my $argsDeclaration  =
    [
     stringArg({ name => 'inputFile',
		 descr => 'file of URLs',
		 constraintFunc=> undef,
		 reqd  => 1,
		 isList => 0,
		 mustExist => 1,
	       }),
     stringArg({ name => 'core_version',
		 descr => 'the version of core release.',
		 constraintFunc=> undef,
		 reqd  => 1,
		 isList => 0
	       })
    ];

  return $argsDeclaration;
}


sub getDocumentation {

  my $description = <<DESCR;
Insert External Resource Urls from a file of URLs.
Example: https://github.com/Ensembl/ensembl-webcode/blob/release/99/conf/ini-files/DEFAULTS.ini#L234
DESCR

  my $purpose = <<PURPOSE;
Insert External Resource Urls from a file of URLs.
Example: https://github.com/Ensembl/ensembl-webcode/blob/release/99/conf/ini-files/DEFAULTS.ini#L234
PURPOSE

  my $purposeBrief = <<PURPOSEBRIEF;
Insert External Resource Urls from a file of URLs.
Example: https://github.com/Ensembl/ensembl-webcode/blob/release/99/conf/ini-files/DEFAULTS.ini#L234
PURPOSEBRIEF

  my $notes = <<NOTES;
NOTES

  my $tablesAffected = <<AFFECT;
ApiDB.ExternalResourceUrl
AFFECT

  my $tablesDependedOn = <<TABD;

TABD

  my $howToRestart = <<RESTART;
No restart provided. Must undo and reload.
RESTART

  my $failureCases = <<FAIL;
FAIL

  my $documentation = { purpose          => $purpose,
                        purposeBrief     => $purposeBrief,
                        tablesAffected   => $tablesAffected,
                        tablesDependedOn => $tablesDependedOn,
                        howToRestart     => $howToRestart,
                        failureCases     => $failureCases,
                        notes            => $notes
                      };

  return ($documentation);
}


sub new {
  my $class = shift;
  my $self = {};
  bless($self, $class);

  my $documentation = &getDocumentation();

  my $args = &getArgsDeclaration();

  my $configuration = { requiredDbVersion => 4.0,
                        cvsRevision => '$Revision$',
                        name => ref($self),
                        argsDeclaration => $args,
                        documentation => $documentation
                      };

  $self->initialize($configuration);

  return $self;
}


sub run {
  my $self = shift;

  my $file = $self->getArg('inputFile');

  my $core_version = $self->getArg('core_version');

  $self->processFileAndInsertExternalResourceUrl($file, $core_version);

  return "Processed $file.";
}



sub processFileAndInsertExternalResourceUrl {
  my ($self, $file, $core_version) = @_;

  open (FILE, $file) or die "Cannot open file $file for reading: $!";

  my $count = 0; 

  while (<FILE>){
    chomp;

    my ($database_name,$id_url) = split("\t", $_);

    my $externalResourceUrl = GUS::Model::ApiDB::ExternalResourceUrl->new({
                                                            core_version => $core_version,
                                                            database_name => $database_name,
                                                            id_url => $id_url,
                                                           });
    $externalResourceUrl->submit();
    $count++;
    $self->undefPointerCache() if $count % 1000 == 0;
  }
  close (FILE);

  $self->log("Inserted $count external resource Urls from $file");

}


sub undoTables {
  my ($self) = @_;

  return ('ApiDB.ExternalResourceUrl');
}


return 1;
