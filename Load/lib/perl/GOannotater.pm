package ApiComplexa::DataLoad::GOannotater;

use strict;

use GUS::Model::SRes::GOEvidenceCode;
use GUS::Model::SRes::GOTerm;
use GUS::Model::DoTS::GOAssocInstEvidCode;
use GUS::Model::DoTS::GOAssociationInstanceLOE;
use GUS::Model::DoTS::GOAssociationInstance;
use GUS::Model::DoTS::GOAssociation;




sub new {
   my $class = shift;
   my $self = {};
   bless($self, $class);
   return $self;
}


sub getGOId {
   my ($self, $goId) = @_;

   my $gusObj = GUS::Model::SRes::GOTerm->new( { 'go_id' => $goId, } );
   $gusObj->retrieveFromDB() || die "No entry for the this go term";
   my $gusId = $gusObj->getId();

return $gusId;
}


sub getEvidenceCode {
    my ($self, $evidType) = @_;

    my $gusObj = GUS::Model::SRes::GOEvidenceCode->new( { 'name' => $evidType, } );
    $gusObj->retrieveFromDB() || die "No entry for the this evidence type";
    my $gusId = $gusObj->getId();
    
return $gusId;
}

sub getOrCreateLOE {
  my ($self, $loeName) = @_;

  my $gusObj = GUS::Model::DoTS::GOAssociationInstanceLOE->new( {
                         'name' => $loeName, } );

 unless ($gusObj->retrieveFromDB) { $gusObj->submit(); }
 my $loeId = $gusObj->getId();

return $loeId;
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

    
1;

