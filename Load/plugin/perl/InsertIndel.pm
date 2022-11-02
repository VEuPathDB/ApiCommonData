package ApiCommonData::Load::Plugin::InsertIndel;

@ISA = qw(GUS::PluginMgr::Plugin);

use GUS::Model::ApiDB::Indel;
use GUS::PluginMgr::Plugin;
use strict;
# ----------------------------------------------------------------------
my $argsDeclaration =
  [
   fileArg({name           => 'IndelFile',
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

   stringArg({name           => 'genomeExtDbRlsSpec',
            descr          => 'External Database Spec for this genome',
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
 my $genomeExtDbRlsSpec = $self->getArg('genomeExtDbRlsSpec');
 
 my $extDbRlsId = $self->getExtDbRlsId($extDbRlsSpec);
 my $genomeExtDbRlsId = $self->getExtDbRlsId($genomeExtDbRlsSpec);

 my $fileName = $self->getArg('IndelFile');
 my $rowCount = 0;

 my $dbh = $self->getQueryHandle();

 my $sh = $dbh->prepare("select source_id, na_sequence_id from dots.nasequenceimp where external_database_release_id = $genomeExtDbRlsId");
 $sh->execute();
 
 my (%genomeIdHash, $sourceId, $naSequenceId);

 while(($sourceId, $naSequenceId) = $sh->fetchrow_array()) {
     $genomeIdHash{$sourceId} = $naSequenceId
 }

 open(my $data, '<', $fileName) || die "Could not open file $fileName: $!";
 while (my $line = <$data>) {
     my $rowCount++;
     chomp $line;
     my ($name, $seqId, $refpos, $shift) = split(/\t/, $line);
     my $naSeqId = $genomeIdHash{$seqId};
     if (!$naSeqId) {
	 die "$seqId not found in database";
     }
     else {
	 my $row = GUS::Model::ApiDB::Indel->new({sample_name => $name,
                                                     na_sequence_id => $naSeqId,
                                                     location => $refpos,
                                                     shift => $shift,
                                                     external_database_release_id => $extDbRlsId,
						 });
	 $row->submit();
     }
 }
 print "$rowCount rows added.\n"
}


sub undoTables {
  my ($self) = @_;

  return ('ApiDB.Indel'
     );
}

1;
