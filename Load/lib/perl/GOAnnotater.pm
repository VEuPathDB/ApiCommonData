package ApiCommonData::Load::GOAnnotater;

use strict;

use GUS::Model::SRes::GOEvidenceCode;
use GUS::Model::SRes::GOTerm;
use GUS::Model::DoTS::GOAssocInstEvidCode;
use GUS::Model::DoTS::GOAssociationInstanceLOE;
use GUS::Model::DoTS::GOAssociationInstance;
use GUS::Model::DoTS::GOAssociation;


sub new {
   my $class = shift;
   my $goRelease = shift;
   my $self = {};
   bless($self, $class);

   $self->{'dbRls'} = $goRelease;
#IS LOE A ONE TIME THING OR KEEP GETTING IT??
   
   #Initialize some of your hashs here (contexts) so you can more quickly operate.
   $self->_initEvidenceCodes();
   $self->_initGoTermIds();
   
   return $self;
}


#getGOId
sub getGoTermId {
  my ($self, $goTermId) = @_;

  my $goTermId = $self->{goTermIds}->{$goTermId};

  $goTermId
    || $self->userError("Can't find GoTerm in database for GO Id: $goTermId");

  return $goTermId;
}


sub getEvidenceCode {
  my ($self, $evidenceCode) = @_;
    
  my $evidenceId = $self->{evidenceIds}->{$evidenceCode};
    $evidenceId || $self->userError("Evidence code '$evidenceCode' not found in db.");
  return $evidenceId;
  
}

#getOrCreateLOE
sub getLoeId {
  my ($self, $loeName) = @_;

  if (!$self->{$loeName}) {
    my $gusObj = GUS::Model::DoTS::GOAssociationInstanceLOE->new( {
              'name' => $loeName, } );
      unless ($gusObj->retrieveFromDB) { $gusObj->submit(); }
      my $loeId = $gusObj->getId();
    $self->{$loeName} = $loeId;
  }

  return $self->{$loeName};
}


sub getOrCreateGOAssociation {
  my ($self, $goId, $aaId, $tableId) = @_;


     my $gusGOA = GUS::Model::DoTS::GOAssociation->new( {
                   'table_id' => $tableId,
                   'row_id' => $aaId,
                   'go_term_id' => $goId,
                   'is_not' => 0,
                   'is_deprecated' => 0,
                   'defining' => 0, } );
    unless ($gusGOA->retrieveFromDB()) {
       $gusGOA->submit(); 
    }
    my $goAssc = $gusGOA->getId();

return $goAssc;
}

sub deprecateGOInstances {
return 1;
}


sub getOrCreateGoInstance {
 my ($self, $asscId, $evidId, $loeId, $isPrim) = @_;  

 my $gusObj = GUS::Model::DoTS::GOAssociationInstance->new( {
                      'go_association_id' => $asscId,
                      'go_assoc_inst_loe_id' => $loeId,
                      'is_primary' => $isPrim,
                      'is_deprecated' => 0, } );
 
 unless ($gusObj->retrieveFromDB) { $gusObj->submit(); }
 my $instId = $gusObj->getId();

 my $evdObj = GUS::Model::DoTS::GOAssocInstEvidCode->new( {
                     'go_evidence_code_id' => $evidId,
                     'go_association_instance_id' => $instId, } );


 unless ($evdObj->retrieveFromDB) { $evdObj->submit(); }

return $instId;
}


sub _initGoTermIds {
  my ($self, $goDbRlsId) = @_;

  if (!$self->{goTermIds}) {
    my $sql = "SELECT go_term_id, go_id FROM SRes.GOTerm WHERE external_database_release_id = $goDbRlsId";

    my $stmt = $self->prepareAndExecute($sql);
    while (my ($go_term_id, $go_id) = $stmt->fetchrow_array()) {
      $self->{goTermIds}->{$go_id} = $go_term_id;
    }

  }
}


sub _initEvidenceCodes {
   my $self = shift;

   my $sql = "select go_evidence_code_id, name from sres.goevidencecode";
      my $stmt = $self->prepareAndExecute($sql);
      while (my ($id, $name) = $stmt->fetchrow_array()) { 
        $self->{evidenceIds}->{$name} = $id;
      }
}


1;

