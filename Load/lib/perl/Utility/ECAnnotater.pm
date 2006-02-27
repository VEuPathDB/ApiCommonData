package ApiCommonData::Load::Utility::ECAnnotater;

use strict;
use DBI;
use CBIL::Util::Disp;
use GUS::Model::DoTS::Transcript;
use GUS::Model::DoTS::TranslatedAAFeature;
use GUS::Model::DoTS::AASequenceEnzymeClass;
use GUS::Model::SRes::EnzymeClass;

sub new {
   my $class = shift;
   my $self = {};
   bless($self, $class);
   
   return $self;
}


sub addEnzymeClassAssoc {
   my ($self, $seqId, $ecNumber, $relId, $evid) = @_;

       my $gusEcId = $self->_getEcId($ecNumber,$relId);
       my $gusEcAsc = GUS::Model::DoTS::AASequenceEnzymeClass->new( {
                                'aa_sequence_id'=>$seqId, 
                                'enzyme_class_id'=>$gusEcId,
                                'evidence_code'=> $evid,
                                } );
         unless ($gusEcAsc->retrieveFromDB()) {
            $gusEcAsc->submit();
         }
}



sub getAASeqIdFromFeatId {
   my ($self, $featId) = @_;

   my $gusTAAF = GUS::Model::DoTS::TranslatedAAFeature->new( { 'na_feature_id' => $featId, } );
   $gusTAAF->retrieveFromDB() || die "no translated aa sequence: $featId";
   my $gusAASeq = $gusTAAF->getAaSequenceId();

return $gusAASeq
}


sub getAASeqIdFromGeneId {
   my ($self, $featId) = @_;

   my $gusTAAF = GUS::Model::DoTS::TranslatedAASequence->new( { 'source_id' => $featId, } );
   $gusTAAF->retrieveFromDB() || die "no translated aa sequence: $featId";
   my $gusAASeq = $gusTAAF->getId();

return $gusAASeq
}


sub _getEcId {
   my ($self, $ecNum, $relId) = @_;

       my $gusEcObj = GUS::Model::SRes::EnzymeClass->new( {
                                 'ec_number' => $ecNum,
                                 'external_database_release_id' => $relId,
                                 } );
       $gusEcObj->retrieveFromDB() || die "no such EC entry: $ecNum";
       my $gusECId = $gusEcObj->getId();

return $gusECId;
}

return 1;


