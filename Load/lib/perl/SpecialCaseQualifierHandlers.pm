package ApiCommonData::Load::SpecialCaseQualifierHandlers;

use strict;

use GUS::Supported::SpecialCaseQualifierHandlers;
use GUS::Model::DoTS::Transcript;
use GUS::Model::DoTS::TranslatedAAFeature;
use GUS::Model::DoTS::TranslatedAASequence;
use GUS::Model::DoTS::AALocation;
use GUS::Supported::Plugin::InsertSequenceFeaturesUndo;

sub new {
  my ($class) = @_;
  my $self = {};
  bless($self, $class);
  return $self;
}

sub setPlugin{
  my ($self, $plugin) = @_;
  $self->{plugin} = $plugin;

}

sub undoAll{
  my ($self, $algoInvocIds, $dbh) = @_;

  $self->{'algInvocationIds'} = $algoInvocIds;
  $self->{'dbh'} = $dbh;

  $self->_undoTranslations();
  $self->_undoFunction();
}


############### TranslatedAAFeature  ###############################3

sub translation {
  my ($self, $tag, $bioperlFeature, $feature) = @_;

  my @tags = $bioperlFeature->get_tag_values($tag);
  die "Feature has more than one translation \n" if scalar(@tags) != 1;

  my $featureHash = $self->_getAASequenceFeatures($bioperlFeature);

  my $extDbRls = $feature->getExternalDatabaseReleaseId();

  my $transAaFeat = GUS::Model::DoTS::TranslatedAAFeature->new({
           'is_predicted' => 1,
           'external_database_release_id' => $extDbRls,
           'source_id' => $featureHash->{'source_id'},
            });

  my $seqLength = length($tags[0]);
  my $aaSeq = GUS::Model::DoTS::TranslatedAASequence->
    new({'sequence' => $tags[0],
         'source_id' => $featureHash->{'source_id'},
         'secondary_identifier' => $featureHash->{'protein_id'},
         'description' => $featureHash->{'product'},
         'external_database_release_id' => $extDbRls ,
         'length' => $seqLength,
        });

  $aaSeq->submit();

  $transAaFeat->setAaSequenceId($aaSeq->getId());

  return [$transAaFeat];
}


sub _getAASequenceFeatures {
   my ($self, $bioperlFeature) = @_;

  my $featureHash = {};

  if ($bioperlFeature->has_tag('protein_id')) {
  my @tags = $bioperlFeature->get_tag_values('protein_id');
    $featureHash->{'protein_id'} = $tags[0]; 
  }
  if ($bioperlFeature->has_tag('locus_tag')) {
  my @tags = $bioperlFeature->get_tag_values('locus_tag');
      $featureHash->{'source_id'} = $tags[0]; 
  }
  if ($bioperlFeature->has_tag('product')) {
  my @tags = $bioperlFeature->get_tag_values('product');
    $featureHash->{'product'} = $tags[0]; 
  }

return $featureHash;
}


sub _undoTranslations{
  my ($self) = @_;

  $self->_deleteFromTable('DoTS.TranslatedAAFeature');
  $self->_deleteFromTable('DoTS.TranslatedAASequence');
  $self->_deleteFromTable('DoTS.AALocation');

}


################ Function ################################

sub function {
  my ($self, $tag, $bioperlFeature, $feature) = @_;

  my @tagValues = $bioperlFeature->get_tag_values($tag);
  $feature->setFunction(join(' | ', @tagValues));

  return [];
}

sub _undoFunction{
  my ($self) = @_;

}

#################################################################

sub _deleteFromTable{
   my ($self, $tableName) = @_;

  &GUS::Supported::Plugin::InsertSequenceFeaturesUndo::deleteFromTable($tableName, $self->{'algInvocationIds'}, $self->{'dbh'});
}

1;
