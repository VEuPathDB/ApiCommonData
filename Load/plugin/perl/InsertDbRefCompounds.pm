package ApiCommonData::Load::Plugin::InsertDbRefCompounds;

@ISA = qw(GUS::PluginMgr::Plugin);

# ---------------------------------------------------------------------------------------------------
# Plugin to handle Compound aliases, provided by data provider
# Creates new entries in the tables SRes.DbRef and ApiDB.DbRefCompound
# ----------------------------------------------------------------------------------------------------

use strict;
use warnings;

use GUS::PluginMgr::Plugin;
use GUS::Model::SRes::DbRef;
use GUS::Model::SRes::ExternalDatabaseRelease;
use GUS::Model::ApiDB::DbRefCompound;

# ----------------------------------------------------------
# Load Arguments
# ----------------------------------------------------------

sub getArgsDeclaration {
  my $argsDeclaration  =
    [
     stringArg({ name => 'aliasFile',
		 descr => 'file with aliases for compound IDs',
		 constraintFunc=> undef,
		 reqd  => 1,
		 isList => 0,
		 mustExist => 1,
	       }),
   stringArg({name => 'extDbName',
	      descr => 'the external database name with which to load the DBRefs.',
	      constraintFunc => undef,
	      reqd => 1,
	      isList => 0,
	     }),
   stringArg({name => 'extDbReleaseNumber',
	      descr => 'the version of the external database with which to load the DBRefs',
	      constraintFunc => undef,
	      reqd => 1,
	      isList => 0,
	     }),
    ];

  return $argsDeclaration;
}


# ----------------------------------------------------------
# Documentation
# ----------------------------------------------------------

sub getDocumentation {

  my $description = <<DESCR;
Plugin to load aliases to PubChem Compounds Substances out of a tab file, into ApiDB.DbRefCompound
DESCR

  my $purpose = <<PURPOSE;
Plugin to load aliases to PubChem Compounds Substances out of a tab file, into ApiDB.DbRefCompound
PURPOSE

  my $purposeBrief = <<PURPOSEBRIEF;
Plugin to load aliases to PubChem Compounds Substances out of a tab file, into ApiDB.DbRefCompound
PURPOSEBRIEF

  my $notes = <<NOTES;
NOTES

  my $tablesAffected = <<AFFECT;
ApiDB.DbRefCompound
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

# ----------------------------------------------------------

sub new {
  my $class = shift;
  my $self = {};
  bless($self, $class);

  my $documentation = &getDocumentation();
  my $args = &getArgsDeclaration();
  my $configuration = { requiredDbVersion => 3.6,
                        cvsRevision => '$Revision$',
                        name => ref($self),
                        argsDeclaration => $args,
                        documentation => $documentation
                      };
  $self->initialize($configuration);
  return $self;
}

# ----------------------------------------------------------

sub run {
  my $self = shift;
  my $count =0;

  my $dbRls = $self->getExtDbRlsId($self->getArg('extDbName'),  $self->getArg('extDbReleaseNumber'))
    || die "Couldn't retrieve external database!\n";

  my $aliasFile  = $self->getArg('aliasFile');
  open(FILE, "$aliasFile")  || die "Can't open the file $aliasFile.  Reason: $!\n";

  while(<FILE>) {
    my ($compound_id, $alias) = split(/\t/, $_);
    my %dbRef;

    # add alias in SRes.DbRef
    $dbRef{'external_database_release_id'} = $dbRls;

    #  $dbRef{'primary_identifier'} = $alias;
    #   Since the alias is not unique to the source_id, hence concatenating
    #   both, with '|', to make a unique primary_identifier, for SRes.DbRef
    $dbRef{'primary_identifier'} = $alias . '|' . $compound_id;

    my $newDbRef = GUS::Model::SRes::DbRef->new(\%dbRef);
    $newDbRef->submit() unless $newDbRef->retrieveFromDB();


    # add entry in linking table
    my $dbRefId = $newDbRef->getId();
    $self->insertDbRefCompound($compound_id, $dbRefId);

    $count ++;
    $self->log("Processed $count entries.\n");
  }

  close (FILE);
  $self->log("Finishing processing $count entries.\n");
}


sub insertDbRefCompound {
  my ($self, $compound_id, $db_ref_id)= @_;

  my $dbRefComp = GUS::Model::ApiDB::DbRefCompound->new({
							 compound_id => $compound_id,
							 db_ref_id     => $db_ref_id
							});

  $dbRefComp->submit() unless $dbRefComp->retrieveFromDB();
}


sub undoTables {
  my ($self) = @_;

  return ('ApiDB.DbRefCompound');
}


return 1;
