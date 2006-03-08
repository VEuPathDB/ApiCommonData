package ApiCommonData::Load::Utility::GOAnnotater;

use strict;

use GUS::Model::SRes::GOEvidenceCode;
use GUS::Model::SRes::GOTerm;
use GUS::Model::DoTS::GOAssocInstEvidCode;
use GUS::Model::DoTS::GOAssociationInstanceLOE;
use GUS::Model::DoTS::GOAssociationInstance;
use GUS::Model::DoTS::GOAssociation;


sub new {
   my $class = shift;
   my $plugin = shift;
   my $goRelease = shift;

   my $self = {};
   bless($self, $class);

   $self->{plugin} = $plugin;
                                                                                                                             
   $self->_initEvidenceCodes();
   $self->_initGoTermIds($goRelease);
   
   return $self;
}


sub getGoTermId {
  my ($self, $goId) = @_;

  my $goTermId = $self->{goTermIds}->{$goId};

  $goTermId
    || $self->userError("Can't find GoTerm in database for GO Id: $goId");

  return $goTermId;
}


sub getEvidenceCode {
  my ($self, $evidenceCode) = @_;
    
  my $evidenceId = $self->{evidenceIds}->{$evidenceCode};
       $evidenceId || $self->userError("Evidence code '$evidenceCode' not found in db.");

  return $evidenceId;
}


sub getLoeId {
  my ($self, $loeName) = @_;

  if (!$self->{$loeName}) {
    my $gusObj = GUS::Model::DoTS::GOAssociationInstanceLOE->new( {
              'name' => $loeName,
               } );

      unless ($gusObj->retrieveFromDB) { 
                          $gusObj->submit();
                         }

      my $loeId = $gusObj->getId();
 
      $self->{$loeName} = $loeId;
  }

  return $self->{$loeName};
}


sub getOrCreateGOAssociation {
  my ($self, $goAssc) = @_;

     my $gusGOA = GUS::Model::DoTS::GOAssociation->new( {
                   'table_id' => $goAssc->{'tableId'},
                   'row_id' => $goAssc->{'rowId'},
                   'go_term_id' => $goAssc->{'goId'},
                   'is_not' => $goAssc->{'isNot'},
                   'is_deprecated' => 0,
                   'defining' => $goAssc->{'isDefining'},
                    } );

    unless ($gusGOA->retrieveFromDB()) {
       $gusGOA->submit(); 
    }

    my $goAssociationId = $gusGOA->getId();

return $goAssociationId;
}


sub deprecateGOInstances {
return 1;
}


sub getOrCreateGOInstance {
 my ($self, $assc) = @_;  

 my $gusObj = GUS::Model::DoTS::GOAssociationInstance->new( {
                      'go_association_id' => $assc->{'goAssociation'},
                      'go_assoc_inst_loe_id' => $assc->{'lineOfEvidence'},
                      'is_primary' => $assc->{'isPrimary'},
                      'is_deprecated' => 0, 
                       } );
 
 unless ($gusObj->retrieveFromDB) { 
                     $gusObj->submit(); 
                     }

 my $instId = $gusObj->getId();

 my $evdObj = GUS::Model::DoTS::GOAssocInstEvidCode->new( {
                     'go_evidence_code_id' => $assc->{'evidenceCode'},
                     'go_association_instance_id' => $instId, 
                      } );

 unless ($evdObj->retrieveFromDB) { $evdObj->submit(); }

return $instId;
}


sub _initEvidenceCodes {
   my $self = shift;

   my $sql = "select go_evidence_code_id, name from sres.goevidencecode";
      my $stmt = $self->{plugin}->prepareAndExecute($sql);

      while (my ($id, $name) = $stmt->fetchrow_array()) { 
        $self->{evidenceIds}->{$name} = $id;
      }
}


sub _initGoTermIds {
   my ($self,$goRelease) = @_;

   foreach my $dbRlsId (@$goRelease) {

      my ($dbName,$dbVersion) = split(/\^/,$dbRlsId);

      my $goVersion = $self->{plugin}->getExtDbRlsId($dbName,
                                                   $dbVersion,)
              or die "Couldn't retrieve external database!\n";

      my $sql = "SELECT go_term_id, 
                     go_id FROM SRes.GOTerm WHERE 
                     external_database_release_id = $goVersion
                 UNION
                 SELECT go_term_id,
                     source_id FROM SRes.GOSynonym WHERE
                     external_database_release_id = $goVersion
                     AND source_id is not null";

        my $stmt = $self->{plugin}->prepareAndExecute($sql);

        while (my ($go_term_id, $go_id) = $stmt->fetchrow_array()) {
           $self->{goTermIds}->{$go_id} = $go_term_id;
        }
    }
}



1;

