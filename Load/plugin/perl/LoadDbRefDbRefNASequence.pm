package ApiCommonData::Load::Plugin::LoadDbRefDbRefNASequence;

@ISA = qw(GUS::PluginMgr::Plugin);
 
use strict;
use warnings;

use GUS::PluginMgr::Plugin;

use GUS::Model::SRes::DbRef;
use GUS::Model::DoTS::DbRefNASequence;
use GUS::Model::SRes::ExternalDatabase;
use GUS::Model::SRes::ExternalDatabaseRelease;

sub new {
  my ($class) = @_;

  my $self = {};
  bless($self,$class);

my $purpose = <<PURPOSE;
Puts rows in DbRef and maps them to rows in NASequence from a mapping file
PURPOSE

my $purposeBrief = <<PURPOSE_BRIEF;
Maps rows in NASequence to rows in DbRef
PURPOSE_BRIEF

my $notes = <<NOTES;
NOTES

my $tablesAffected = <<TABLES_AFFECTED;
    [ ['DoTS::DbRef', ''],
      ['DoTS::DbRefNASequence', '']
    ];
TABLES_AFFECTED

my $tablesDependedOn = <<TABLES_DEPENDED_ON;
  [ ['DoTS::NASequenceImp','']];
TABLES_DEPENDED_ON

my $howToRestart = <<RESTART;
Must run undo plugin and then restart
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


my $argsDeclaration = 
[
 stringArg({name => 'mappingfile',
            descr => 'mapping file',
            reqd  => 1,
            constraintFunc=> undef,
            isList=> 0
            }),
 stringArg({name  => 'table',
            descr => 'table of sequences to which the external data are mapped, e.g. VirtualSequence',
            reqd  => 1,
            constraintFunc=> undef,
            isList=> 0
            }),
 stringArg({ name => 'seqExtDbName',
	     descr => 'dots.externaldatabase.name for the rows in NASequence',
	     reqd => 1,
	     constraintFunc => undef,
	     isList => 0
	    }),
 stringArg({name => 'seqExtDbRlsVer',
	    descr => 'dots.externaldatabaserelease.version for the rows in NASequence',
	    reqd => 1,
	    constraintFunc => undef,
	    isList => 0
	    }),
 stringArg({name => 'dbRefExtDbName',
	    descr => 'dots.externaldatabase.name for the rows in DbRef',
	    reqd => 1,
	    constraintFunc => undef,
	    isList => 0
	    }),
 stringArg({name => 'dbRefExtDbRlsVer',
	    descr => 'dots.externaldatabaserelease.version for the rows in dbRef',
	    reqd => 1,
	    constraintFunc => undef,
	    isList => 0
	    }),
 stringArg({name => 'pattern1',
            descr => 'source identifier pattern with parenthesis around the id to be stored for DbRef.primary_identifier, e.g. ^(SC_\d+)',
            reqd  => 1,
            constraintFunc=> undef,
            isList=> 0
            }),
 stringArg({name => 'pattern2',
            descr => 'identifier pattern for the NASequence attribute, e.g. (CH\d+)',
            reqd  => 1,
            constraintFunc=> undef,
            isList=> 0
            }),
 stringArg({name => 'seqAttribute',
            descr => 'column used to identify row in NASequence, e.g. source_id or na_sequence_id',
            reqd => 1,
            constraintFunc=> undef,
            isList=> 0
            })
];

  $self->initialize({requiredDbVersion => 3.5,
		     cvsRevision => '$Revision$', # cvs fills this in!
		     name => ref($self),
		     argsDeclaration   => $argsDeclaration,
		     documentation     => $documentation});


  return $self;
}


$| = 1;

sub run {

  my $self   = shift;

  my $fileHash = $self->makeFileHash();

  my $dbRefNum = scalar (keys %{$fileHash});

  my $dbRefRlsId = $self->getExternalDatabaseRelease($self->getArg('dbRefExtDbName'),$self->getArg('dbRefExtDbRlsVer'));

  my $seqRefRlsId = $self->getExternalDatabaseRelease($self->getArg('seqExtDbName'),$self->getArg('seqExtDbRlsVer'));

  my $rows = $self->processHash($fileHash,$dbRefRlsId,$seqRefRlsId);

  return "entered $rows DbRefNASequence rows for $dbRefNum dbRef identifiers";
}

sub makeFileHash {
  my ($self) = @_;

  my $file = $self->getArg('mappingfile');

  open (FILE,$file) || $self->userError("Can't open $file for reading");

  my $pattern1 = $self->getArg('pattern1');

  my $pattern2 = $self->getArg('pattern2');

  my %fileHash;

  while (<FILE>) {
    if (/$pattern1/) {
      my $dbRefIdent = $1;
      if (/$pattern2/) {
	my $seqIdent = $1;
	push (@{$fileHash{$dbRefIdent}},$seqIdent);
      }
      else {
	$self->userError("Unable to parse $_ for $pattern2\n");
      }
    }

    else {
      die "Unable to parse $_ for $pattern1\n";
    }
  }

  return \%fileHash
}


sub getExternalDatabaseRelease{

  my ($self, $name, $version) = @_;

  my $externalDatabase = GUS::Model::SRes::ExternalDatabase->new({"name" => $name});
  $externalDatabase->retrieveFromDB();

  if (! $externalDatabase->getExternalDatabaseId()) {
    $externalDatabase->submit();
  }
  my $externalDbId = $externalDatabase->getExternalDatabaseId();

  my $externalDatabaseRel = GUS::Model::SRes::ExternalDatabaseRelease->new ({'external_database_id'=>$externalDbId,'version'=>$version});

  $externalDatabaseRel->retrieveFromDB();

  if (! $externalDatabaseRel->getExternalDatabaseReleaseId()) {
    $externalDatabaseRel->submit();
  }
  my $externalDbRelId = $externalDatabaseRel->getExternalDatabaseReleaseId();

  return ($externalDbRelId);
}

sub processHash {
  my ($self,$fileHash,,$dbRefRlsId,$seqRefRlsId) = @_;

  my $rows = 0;

  foreach my $dbRefIdent (keys %{$fileHash}) {
    my $dbRefObj = $self->getDbRef($dbRefIdent,$dbRefRlsId);
    foreach my $seqIdent (@{$fileHash->{$dbRefIdent}}) {
      my $seqId = $self->getSeqId($seqIdent,$seqRefRlsId);
      my $dbRefNASeqObj = $self->getDbRefNASeq($seqId);
      $dbRefObj->addChild($dbRefNASeqObj);
    }
    my $rows += $dbRefObj->submit();
  }

  return $rows;
}

sub getDbRef {

  my ($self,$primaryId,$extDbRlsId) = @_;

  $self->log('Making DbRef row for $primaryId');

  my $lowercasePrimaryId = lc($primaryId);

  my $dbRef = GUS::Model::SRes::DbRef -> new ({'lowercase_primary_identifier'=>$lowercasePrimaryId, 'external_database_release_id'=>$extDbRlsId});
  $dbRef->retrieveFromDB();

  if ($dbRef->getPrimaryIdentifier() ne $primaryId) {
    $dbRef->setPrimaryIdentifier($primaryId);
  }

  return $dbRef;
}

sub getSeqId {
  my ($self, $ident, $dbRlsId) = @_;

  my $dbh = $self->getQueryHandle();

  my $table = $self->getArg('table');

  my $att = $self->getArg('seqAttribute');

  my $sql = "select na_sequence_id from dots.$table where external_database_release_id = ? and $att = ?";

  my $stmt = $dbh->prepare($sql);

  $stmt->execute($dbRlsId,$ident);

  my $naSeqId  = $stmt->fetchrow_array();

  $stmt->finish();

  return $naSeqId;
}


sub getDbRefNASeq {
  my ($self, $seqId);

  my $newDbRefNASeq = GUS::Model::DoTS::DbRefNASequence->new ({'na_sequence_id'=>$seqId});

  return $newDbRefNASeq;
}

sub undoTables {
  my ($self) = @_;

  return ('DoTS.DbRefNASequence',
	  'SRes.DbRef',
	 );
}




__END__

=pod
=head1 Description
B<LoadDbRefDbRefNASequence>  plug-in to ga that adds entries to SRes.DbRef and to the linking table DoTS.DbRefNASequence.

=head1 Purpose
B<LoadDbRefDbRefNASequence> adds entries to SRes.DbRef and to the linking table DoTS.DbRefNASequence.

=cut
