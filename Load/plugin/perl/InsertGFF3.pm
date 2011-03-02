package ApiCommonData::Load::Plugin::InsertGFF3;
@ISA = qw(GUS::PluginMgr::Plugin);

use strict;
use warnings;

use GUS::PluginMgr::Plugin;

use GUS::Model::DoTS::NASequence;
use GUS::Model::SRes::SequenceOntology;
use GUS::Model::SRes::ExternalDatabase;
use GUS::Model::SRes::ExternalDatabaseRelease;
use GUS::Model::ApiDB::GFF3;
use ApiCommonData::Load::Util;

# ----------------------------------------------------------
# Load Arguments
# ----------------------------------------------------------

sub getArgsDeclaration {
  my $argsDeclaration  =
    [
     fileArg({ name => 'file',
         descr => 'tab delimited file',
         constraintFunc=> undef,
         reqd  => 1,
         isList => 0,
         mustExist => 1,
         format => 'Nine column tab delimited file in the order seqid, source, type, start, end, score, strand, phase, attribute',
       }),
     stringArg({ name => 'gff3DbName',
     descr => 'externaldatabase name for gff3 source',
     constraintFunc=> undef,
     reqd  => 1,
     isList => 0
         }),
     stringArg({ name => 'gff3DbVer',
     descr => 'externaldatabaserelease version used for gff3 source',
     constraintFunc=> undef,
     reqd  => 1,
     isList => 0
         })
    ];

  return $argsDeclaration;
}


# ----------------------------------------------------------
# Documentation
# ----------------------------------------------------------

sub getDocumentation {

  my $description = <<DESCR;
Plugin to load GFF3 file into apidb.gff3 table
DESCR

  my $purpose = <<PURPOSE;
Plugin to load GFF3 file into apidb.gff3 table 
PURPOSE

  my $purposeBrief = <<PURPOSEBRIEF;
Plugin to load GFF3 file into apidb.gff3 table 
PURPOSEBRIEF

  my $notes = <<NOTES;
NOTES

  my $tablesAffected = <<AFFECT;
ApiDB.GFF3
AFFECT

  my $tablesDependedOn = <<TABD;
DoTS.NASequence, SRes.ExternalDatabaseRelease, Sres.SequenceOntology 
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

  my $configuration = { requiredDbVersion => 3.5,
                        cvsRevision => '$Revision: 90 $',
                        name => ref($self),
                        argsDeclaration => $args,
                        documentation => $documentation
                      };

  $self->initialize($configuration);

  return $self;
}

sub run {
  my $self = shift;

  my $gff3ExtDbReleaseId = $self->getExtDbRlsId($self->getArg('gff3DbName'),
             $self->getArg('gff3DbVer')) || $self->error("Can't find external_database_release_id for gff3 data source");

  my $tabFile = $self->getArg('file');

  my ($seqIdHash, $soTermHash) = $self->getUniqueSeqIdandSOTerm($tabFile);

  my $processed;

  open(FILE,$tabFile) || $self->error("$tabFile can't be opened for reading");

  while(<FILE>){

      chomp();

      next if /^\s*$/;
      next if /^##/;

      my ($seqid, $source, $term, $start, $end, $score, $strand, $phase, $attr) = split(/\t/,$_);
      my $is_reversed = 0;
      $is_reversed = 1 if $strand =~ /\-/;

      #my $naSeq = GUS::Model::DoTS::NASequence->new({source_id => $seqid});
      #my $SOTerm = GUS::Model::SRes::SequenceOntology->new({'term_name' => $type });

      #if($naSeq->retrieveFromDB && $SOTerm->retrieveFromDB){

      #   my $naSeqId = $naSeq->getNaSequenceId();
         my $naSeqId = $seqIdHash->{$seqid};
         #my $soid = $SOTerm->getSequenceOntologyId();
         my $soid = $soTermHash->{$term};
    
         $self->insertGFF3($naSeqId, $source, $soid, $start, $end, $score, $is_reversed, $phase, $attr, $gff3ExtDbReleaseId);
  
         $processed++;
         #print "$processed gff3 lines loaded\n";
      #}else{
         #$self->log("WARNING","NASequence for $gff3ExtDbReleaseId or SO term $type cannot be found");
      #}
      
      $self->undefPointerCache();
  }        

  return "$processed gff3 lines parsed and loaded";
}


sub insertGFF3 {
  my ($self,$naSeqId, $source, $soid, $start, $end, $score, $is_reversed, $phase, $attr, $gff3ExtDbReleaseId) = @_;

  my $gff3 = GUS::Model::ApiDB::GFF3->new({'na_sequence_id' => $naSeqId,
                                'source' => $source,
                                'sequence_ontology_id' => $soid,
                                'mapping_start' => $start,
                                'mapping_end' => $end,
                                'score' => $score,
                                'is_reversed' => $is_reversed,
                                'phase' => $phase,
                                'external_database_release_id' => $gff3ExtDbReleaseId
                                 });

  unless ($gff3->retrieveFromDB()){
      $gff3->setAttr($attr);
      $gff3->submit();
  }else{
      $self->log("WARNING","gff3 $gff3 already exists for na_feature_id: $naSeqId");
  }

}

sub getUniqueSeqIdandSOTerm{
  my ($self, $f) = @_;
  my (%seqIdHash, %soTermHash);

  open(F, $f);
  while(<F>) {
    chomp();
    next if /^\s*$/;
    next if /^##/;
    my ($seqid, $source, $type, @others) = split(/\t/,$_);
    $seqIdHash{$seqid}++;
    $soTermHash{$type}++;
  }
  close F;

  while(my ($seqid, $v) = each %seqIdHash) {
    my $naSeq = GUS::Model::DoTS::NASequence->new({source_id => $seqid});
    if($naSeq->retrieveFromDB) {
       my $naSeqId = $naSeq->getNaSequenceId();
       $seqIdHash{$seqid} = $naSeqId;
    } else {
       $self->log("WARNING","NASequence for $seqid cannot be found");
    }
  }

  while(my ($term, $v) = each %soTermHash) {
    my $SOTerm = GUS::Model::SRes::SequenceOntology->new({'term_name' => $term });
    if($SOTerm->retrieveFromDB){
      my $soid = $SOTerm->getSequenceOntologyId();
      $soTermHash{$term} = $soid;
    } else {
       $self->log("WARNING","SO term for $term cannot be found");
    }
  }

  return (\%seqIdHash, \%soTermHash);
}


=c
sub getOrCreateExtDbAndDbRls{
  my ($self, $dbName,$dbVer) = @_;

  my $extDbId=$self->InsertExternalDatabase($dbName);

  my $extDbRlsId=$self->InsertExternalDatabaseRls($dbName,$dbVer,$extDbId);

  return $extDbRlsId;
}

sub InsertExternalDatabase{

    my ($self,$dbName) = @_;
    my $extDbId;

    my $sql = "select external_database_id from sres.externaldatabase where lower(name) like '" . lc($dbName) ."'";
    my $sth = $self->prepareAndExecute($sql);
    $extDbId = $sth->fetchrow_array();

    if ($extDbId){
  print STEDRR "Not creating a new entry for $dbName as one already exists in the database (id $extDbId)\n";
    }

    else {
  my $newDatabase = GUS::Model::SRes::ExternalDatabase->new({
      name => $dbName,
     });
  $newDatabase->submit();
  $extDbId = $newDatabase->getId();
  print STEDRR "created new entry for database $dbName with primary key $extDbId\n";
    }
    return $extDbId;
}

sub InsertExternalDatabaseRls{

    my ($self,$dbName,$dbVer,$extDbId) = @_;

    my $extDbRlsId = $self->releaseAlreadyExists($extDbId,$dbVer);

    if ($extDbRlsId){
  print STDERR "Not creating a new release Id for $dbName as there is already one for $dbName version $dbVer\n";
    }

    else{
        $extDbRlsId = $self->makeNewReleaseId($extDbId,$dbVer);
  print STDERR "Created new release id for $dbName with version $dbVer and release id $extDbRlsId\n";
    }
    return $extDbRlsId;
}
=cut


sub releaseAlreadyExists{
    my ($self, $extDbId,$dbVer) = @_;

    my $sql = "select external_database_release_id 
               from SRes.ExternalDatabaseRelease
               where external_database_id = $extDbId
               and version = '$dbVer'";

    my $sth = $self->prepareAndExecute($sql);
    my ($relId) = $sth->fetchrow_array();

    return $relId; #if exists, entry has already been made for this version

}

sub makeNewReleaseId{
    my ($self, $extDbId,$dbVer) = @_;

    my $newRelease = GUS::Model::SRes::ExternalDatabaseRelease->new({
  external_database_id => $extDbId,
  version => $dbVer,
  download_url => '',
  id_type => '',
  id_url => '',
  secondary_id_type => '',
  secondary_id_url => '',
  description => '',
  file_name => '',
  file_md5 => '',
  
    });

    $newRelease->submit();
    my $newReleasePk = $newRelease->getId();

    return $newReleasePk;

}

sub undoTables {
  return ('ApiDB.GFF3',
    'SRes.ExternalDatabaseRelease',
    'SRes.ExternalDatabase',
   );
}

