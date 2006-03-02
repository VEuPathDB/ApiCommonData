package ApiCommonData::Load::Utility::ECAnnotater;

use strict;
use warnings;

use GUS::Model::DoTS::AASequenceEnzymeClass;
use GUS::Model::SRes::EnzymeClass;

sub new {
   my $class = shift;
   my $self = {};
   bless($self, $class);
   
   return $self;
}


sub addEnzymeClassAssociation {
  my ($self, $ecAssociation) = @_;

#          my $ecAssociation = {
#                    'ecNumber' => 'The raw EC number (e.g. 1.23.4.6),
#                    'evidenceDescription' => 'String describing where the term comes from, e.g. Annotation Center',
#                    'releaseId' => 'External Database Release Id of the Enzyme Database,
#                    'sequenceId' => 'GUS Id of the AA sequence',
#                              };

  $self->{plugin}->userError("addEnzymeClassAssoc requires a hash as input with the following named attributes as input: ecNumber, evidenceDescripition, releaseId, sequenceId") unless (exists($ecAssociation->{'ecNumber'}) && exists($ecAssociation->{'evidenceDescription'}) && exists($ecAssociation->{'releaseId'}) && exists($ecAssociation->{'sequenceId'}));

  my $gusEcId = $self->_getEcId($ecAssociation->{'ecNumber'}, $ecAssociation->{'releaseId'});
  my $gusEcAssociation =
    GUS::Model::DoTS::AASequenceEnzymeClass->new( {
                                      'aa_sequence_id'  => $ecAssociation->{'sequenceId'},
                                      'enzyme_class_id' => $gusEcId,
                                      'evidence_code'   => $ecAssociation->{'evidenceDescription'},
                                                   } );
  unless ($gusEcAssociation->retrieveFromDB()) {
    $gusEcAssociation->submit();

  }
}


sub _getEcId {
   my ($self, $ecNum, $relId) = @_;

   my $gusEcObj = GUS::Model::SRes::EnzymeClass->new( {
						       'ec_number' => $ecNum,
						       'external_database_release_id' => $relId,
						      } );

   $gusEcObj->retrieveFromDB()
     or die "no such EC entry: $ecNum";

   my $gusECId = $gusEcObj->getId();

   return $gusECId;
}

return 1;


