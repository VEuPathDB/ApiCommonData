package ApiCommonData::Load::SpecialCaseQualifierHandlers;

use strict;

use GUS::Supported::SpecialCaseQualifierHandlers;
use GUS::Model::DoTS::Transcript;
use GUS::Model::DoTS::TranslatedAAFeature;
use GUS::Model::DoTS::TranslatedAASequence;
use GUS::Model::DoTS::AALocation;
use GUS::Supported::Plugin::InsertSequenceFeaturesUndo;
use GUS::Model::DoTS::AASequenceEnzymeClass;
use GUS::Model::DoTS::NAFeatureComment;
use GUS::Model::DoTS::Repeats;
use ApiCommonData::Load::Util;

# this is the list of so terms that this file uses.  we have them here so we
# can check them at start up time.
my $soTerms = ({"SECIS_element" => 1,
		"stop_codon_redefinition_as_selenocysteine" => 1,
	       });


sub new {
  my ($class) = @_;
  my $self = {};

  bless($self, $class);

  $self->{standardSCQH} = GUS::Supported::SpecialCaseQualifierHandlers->new();
  return $self;
}

sub setPlugin{
  my ($self, $plugin) = @_;
  $self->{plugin} = $plugin;

}

sub initUndo{
  my ($self, $algoInvocIds, $dbh, $commit) = @_;

  $self->{'algInvocationIds'} = $algoInvocIds;
  $self->{'dbh'} = $dbh;
  $self->{'commit'} = $commit;
  $self->{standardSCQH}->initUndo($algoInvocIds, $dbh, $commit);
}

sub undoAll{
  my ($self, $algoInvocIds, $dbh, $commit) = @_;
  $self->initUndo($algoInvocIds, $dbh, $commit);

  $self->_undoFunction();
  $self->_undoProduct();
  $self->_undoSecondaryId();
  $self->_undoGene();
  $self->_undoECNumber();
  $self->_undoAnticodon();
  $self->_undoProvidedTranslation();
  $self->_undoMiscSignalNote();
  $self->_undoSourceIdAndTranscriptSeq();
  $self->_undoDbXRef();
  $self->_undoGenbankDbXRef();
  $self->_undoGapLength();
  $self->_undoNote();
  $self->_undoPseudo();
  $self->_undoTranscriptProteinId();
  $self->_undoTranscriptTranslExcept();
  $self->_undoProvidedOrfTranslation();
  $self->_undoRptUnit();
  $self->_undoCommentNterm();
}


######### Set source_id and, while here, exon start/stop and transcript seq ###

# 1. Loop through Transcripts... Set the Sequence for its splicedNaSequence
# 2. Find the Min CDS Start and Max CDS END and set translation(Start|Stop)
#    for the translatedAAFeature
# 3. No Splicing of the Exons occurs!!!
sub sourceIdAndTranscriptSeq {
  my ($self, $tag, $bioperlFeature, $geneFeature) = @_;

  # first set source id, and propogate it to the transcript and aa seq
  my @tagValues = $bioperlFeature->get_tag_values($tag);
  $geneFeature->setSourceId($tagValues[0]);

  my @transcripts = $geneFeature->getChildren("DoTS::Transcript");
  my $count = 0;
  foreach my $transcript (@transcripts) {
    $count++;
    $transcript->setSourceId("$tagValues[0]-$count");
    my $translatedAAFeat = $transcript->getChild('DoTS::TranslatedAAFeature');
    if ($translatedAAFeat) {
      $translatedAAFeat->setSourceId("$tagValues[0]-$count");
      my $aaSeq = $translatedAAFeat->getParent('DoTS::TranslatedAASequence');
      if ($aaSeq) {
	$aaSeq->setSourceId("$tagValues[0]-$count");
      }
    }
  }


  # second, initialize isPseudo
  if (!defined($geneFeature->getIsPseudo())) {
    $geneFeature->setIsPseudo(0);
  }

  # now do the exons and transcript seq
  foreach my $transcript ($geneFeature->getChildren('DoTS::Transcript')) {

    my ($transcriptMin, $transcriptMax, @exons, $isReversed);

    foreach my $rnaExon ($transcript->getChildren('DoTS::RNAFeatureExon')) {
      my $exon = $rnaExon->getParent('DoTS::ExonFeature');
      my $naLoc = $exon->getChild('DoTS::NALocation');

      $isReversed = $naLoc->getIsReversed();

      my $exonStart = $isReversed ? $naLoc->getEndMax : $naLoc->getStartMin();
      my $exonStop = $isReversed ? $naLoc->getStartMin : $naLoc->getEndMax();

      # This works until there are alternaltive spliced transcripts...or UTRs
      # These will be overwritten for gff files with coding stop and start tags
      # by the setCodingAndTranslationStart/Stop subroutines below
      $exon->setCodingStart($exonStart);
      $exon->setCodingEnd($exonStop);

      push(@exons, $exon);
    }

    my @exonsSorted = map { $_->[0] }
      sort { $a->[3] ? $b->[1] <=> $a->[1] : $a->[1] <=> $b->[1] }
	map { [ $_, $_->getFeatureLocation ]}
	  @exons;

    my $final = scalar(@exonsSorted) - 1;
    my $transcriptSequence;
    my $order = 1;

    for my $exon (@exonsSorted) {
      my $sourceId = "$tagValues[0]-$order";
      $exon->setOrderNumber($order);
      $exon->setSourceId("$sourceId");
      $order++;

      my $chunk = $exon->getFeatureSequence();
      $transcriptSequence .= $chunk;
    }

    my $splicedNaSeq = $transcript->getParent('DoTS::SplicedNASequence');
    $splicedNaSeq->setSequence($transcriptSequence);
    $splicedNaSeq->setSourceId($transcript->getSourceId());

    if($bioperlFeature->primary_tag() eq "coding_gene"){
      print STDERR $transcript->toString();


      my $translatedAaFeature = $transcript->getChild('DoTS::TranslatedAAFeature');
      my $transcriptLoc = $transcript->getChild('DoTS::NALocation');
      my $transcriptSeq = $transcript->getParent("DoTS::SplicedNASequence");

      my $seq = $transcriptSeq->getSequence();
      my $transcriptLength = length($seq);
      $transcriptLoc->setStartMin(1);
      $transcriptLoc->setStartMax(1);
      $transcriptLoc->setEndMin($transcriptLength);
      $transcriptLoc->setEndMax($transcriptLength);
      $transcriptLoc->setIsReversed(0);
      my $codingStart = $exonsSorted[0]->getCodingStart();
      my $codingStop = $exonsSorted[$final]->getCodingEnd();

      my $translationStart = $self->_getTranslationStart($isReversed, $codingStart, $transcriptLoc);

      my $translationStop = $self->_getTranslationStop($isReversed, $codingStop, $transcriptLoc, $transcriptLength);

      $translatedAaFeature->setTranslationStart($translationStart);
      $translatedAaFeature->setTranslationStop($translationStop);
    }

  }
  return [];
}

sub _undoSourceIdAndTranscriptSeq {
  my ($self) = @_;

}

################ Coding Start/Stop ######################

sub setCodingAndTranslationStart{
  my ($self, $tag, $bioperlFeature, $exonFeature) = @_;

  return $self->_setCodingAndTranslationStartAndStop($tag, $bioperlFeature, $exonFeature, 0);

}

sub _undoSetCodingAndTranslationStart {
  my ($self) = @_;

}

sub setCodingAndTranslationStop {
  my ($self, $tag, $bioperlFeature, $exonFeature) = @_;

  return $self->_setCodingAndTranslationStartAndStop($tag, $bioperlFeature, $exonFeature, 1);

}

sub _setCodingAndTranslationStartAndStop{
  my ($self, $tag, $bioperlFeature, $exonFeature, $isStop) = @_;

  my ($codingValue) = $bioperlFeature->get_tag_values($tag);

  my $rnaExon = $exonFeature->getChild("DoTS::RNAFeatureExon");
  my $transcript = $rnaExon->getParent("DoTS::Transcript");
  my $transcriptLoc = $transcript->getChild("DoTS::NALocation");
  my $translatedAAFeat = $transcript->getChild("DoTS::TranslatedAAFeature");
  my $transcriptSeq = $transcript->getParent("DoTS::SplicedNASequence");
  my $exonLoc = $exonFeature->getChild("DoTS::NALocation");

  my $isReversed = $exonLoc->getIsReversed();

  if($isStop){
    $exonFeature->setCodingEnd($codingValue);

    my $seq = $transcriptSeq->getSequence();
    my $transcriptLength = length($seq);

    if(!$translatedAAFeat->{tempCodingStop} || (!$isReversed && $codingValue > $translatedAAFeat->{tempCodingStop}) || ($isReversed && $codingValue < $translatedAAFeat->{tempCodingStop})){

      $translatedAAFeat->{tempCodingStop} = $codingValue;

      my $translationStop = $self->_getTranslationStop($isReversed, $codingValue, $transcriptLoc, $transcriptLength);

      $translatedAAFeat->setTranslationStop($translationStop);
    }
  }else{
    $exonFeature->setCodingStart($codingValue);

    if(!$translatedAAFeat->{tempCodingStart} || (!$isReversed && $codingValue < $translatedAAFeat->{tempCodingStart}) || ($isReversed && $codingValue > $translatedAAFeat->{tempCodingStart})){

      $translatedAAFeat->{tempCodingStart} = $codingValue;

      my $translationStart = $self->_getTranslationStart($isReversed, $codingValue, $transcriptLoc);

      $translatedAAFeat->setTranslationStart($translationStart);
    }
  }
  return [];
}

sub _undoSetCodingAndTranslationStop {
  my ($self) = @_;

}
################ Translation#############################

sub setProvidedTranslation {
  my ($self, $tag, $bioperlFeature, $geneFeature) = @_;

  my ($aaSequence) = $bioperlFeature->get_tag_values($tag);

  my $transcript = $geneFeature->getChild("DoTS::Transcript");

  my $translatedAaFeature = $transcript->getChild('DoTS::TranslatedAAFeature');
  my $translatedAaSequence = $translatedAaFeature->getParent('DoTS::TranslatedAASequence');

  $translatedAaSequence->setSequence($aaSequence);

  return [];
}

sub _undoProvidedTranslation{
  my ($self) = @_;

}

################ Product ################################

# only keep the first /product qualifier
# cascade product name to transcript, translation and AA sequence:
sub product {
  my ($self, $tag, $bioperlFeature, $geneFeature) = @_;

  my @tagValues = $bioperlFeature->get_tag_values($tag);
  $geneFeature->setProduct($tagValues[0]);

  # cascade product name to transcript, translation and AA sequence:
  my @transcripts = $geneFeature->getChildren("DoTS::Transcript");
  foreach my $transcript (@transcripts) {
    $transcript->setProduct($tagValues[0]);
    my $translatedAAFeat = $transcript->getChild('DoTS::TranslatedAAFeature');
    if ($translatedAAFeat) {
      $translatedAAFeat->setDescription($tagValues[0]);
      my $aaSeq = $translatedAAFeat->getParent('DoTS::TranslatedAASequence');
      if ($aaSeq) {
	$aaSeq->setDescription($tagValues[0]);
      }
    }
  }

  return [];
}

# nothing special to do
sub _undoProduct{
  my ($self) = @_;
}

sub setSecondaryId {
  my ($self, $tag, $bioperlFeature, $geneFeature) = @_;
  my @tagValues = $bioperlFeature->get_tag_values($tag);

  #get AA Sequence
  my @transcripts = $geneFeature->getChildren("DoTS::Transcript");
  foreach my $transcript (@transcripts) {
    my $translatedAAFeat = $transcript->getChild('DoTS::TranslatedAAFeature');
    if ($translatedAAFeat) {
      my $aaSeq = $translatedAAFeat->getParent('DoTS::TranslatedAASequence');
      if ($aaSeq) {
	$aaSeq->setSecondaryIdentifier($tagValues[0]);
      }
    }
  }

  return [];
}

sub _undoSecondaryId{
  my ($self) = @_;
}

################ Gene ###############################3
# we wrap these methods so that we don't call the standard SCQH directly, to
# have finer control over the order of undoing
sub gene {
  my ($self, $tag, $bioperlFeature, $feature) = @_;
  return $self->{standardSCQH}->gene($tag, $bioperlFeature, $feature);
}

sub _undoGene{
  my ($self) = @_;
  return $self->{standardSCQH}->_undoGene();
}

################ dbXRef ###############################

sub dbXRef {
  my ($self, $tag, $bioperlFeature, $feature) = @_;
  return $self->{standardSCQH}->dbXRef($tag, $bioperlFeature, $feature);
}

sub _undoDbXRef{
  my ($self) = @_;
  return $self->{standardSCQH}->_undoDbXRef();
}

################ genbankDbXRef ###############################

sub genbankDbXRef {
  my ($self, $tag, $bioperlFeature, $feature) = @_;
  my @tagValues;
  foreach my $tagValue ($bioperlFeature->get_tag_values($tag)){
      my @split = split(/\:/,$tagValue);
      if (scalar(@split) < 2){
	  $tagValue = "Genbank:".$tagValue;
      }
      push(@tagValues,$tagValue);
  }
  $bioperlFeature->remove_tag($tag);
  $bioperlFeature->add_tag_value($tag,@tagValues);
  return $self->{standardSCQH}->dbXRef($tag, $bioperlFeature, $feature);
}

sub _undoGenbankDbXRef{
  my ($self) = @_;
  return $self->{standardSCQH}->_undoDbXRef();
}

################ rpt_unit ################################

# create a comma delimited list of rpt_units
sub rptUnit {
  my ($self, $tag, $bioperlFeature, $feature) = @_;

  my @tagValues = $bioperlFeature->get_tag_values($tag);
  my $rptUnit = join(", ", @tagValues);
  $feature->setRptUnit($rptUnit);
  return [];
}

# nothing special to do
sub _undoRptUnit{
  my ($self) = @_;

}

################ comment_Nterm ################################

# map a consensus comment to the rpt_unit column, ignore every other value
sub commentNterm {
  my ($self, $tag, $bioperlFeature, $feature) = @_;

  my @tagValues = $bioperlFeature->get_tag_values($tag);

  foreach my $tagValue (@tagValues){
    if ($tagValue =~ /consensus/){
      my @tagSplit = split("consensus", $tagValue);
      $tagSplit[1] =~ s/\s//g;
      $feature->setRptUnit($tagSplit[1]);
    }
  }
  return [];
}

# nothing special to do
sub _undoCommentNterm{
  my ($self) = @_;

}


################ Gap Length ###############################

sub gapLength {
  my ($self, $tag, $bioperlFeature, $feature) = @_;
  return $self->{standardSCQH}->gapLength($tag, $bioperlFeature, $feature);
}

sub _undoGapLength{
  my ($self) = @_;
  return $self->{standardSCQH}->_undoGapLength();
}


################ Note ########################################

sub note {
  my ($self, $tag, $bioperlFeature, $feature) = @_;
  return $self->{standardSCQH}->note($tag, $bioperlFeature, $feature);
}

sub _undoNote{
  my ($self) = @_;
  return $self->{standardSCQH}->_undoNote();
}

############### Pseudo  ###############################

sub setPseudo {
  my ($self, $tag, $bioperlFeature, $feature) = @_;

  my $transcript = &getGeneTranscript($self->{plugin}, $feature);

  $feature->setIsPseudo(1);
  $transcript->setIsPseudo(1);


  return [];
}

sub _undoPseudo{
    my ($self) = @_;
}

############### transl_except  ###############################

sub transcriptTranslExcept {
  my ($self, $tag, $bioperlFeature, $geneFeature) = @_;
  my $transcript = $geneFeature->getChild("DoTS::Transcript");
  my ($transl_except) = $bioperlFeature->get_tag_values($tag);
  $transcript->setTranslExcept($transl_except);
  return [];
}

sub _undoTranscriptTranslExcept {}

################ EC Number ###############################

# attach EC number to translated aa seq.
sub ECNumber {
  my ($self, $tag, $bioperlFeature, $feature) = @_;

  my $aaSeq = &getGeneAASeq($self->{plugin},$feature);

  foreach my $tagValue ($bioperlFeature->get_tag_values($tag)) {
    if ($tagValue eq ""){
      next;
    }
    $tagValue =~ s/^EC: //;
    $tagValue =~ s/\_/\-/;
    my $ecId = $self->_getECNumPrimaryKey($tagValue);
    die "Invalid Enzyme Class '$tagValue'" unless $ecId;
    my $args = {enzyme_class_id => $ecId,
		evidence_code => 'Annotation Center'};
    my $aaSeqEC = GUS::Model::DoTS::AASequenceEnzymeClass->new($args);
    $aaSeq->addChild($aaSeqEC);
  }

#  $aaSeq->submit();

  return [];
}

sub _getECNumPrimaryKey {
  my ($self, $ECNum) = @_;

  if (!$self->{ECNumPKs}) {
    my $rls_id = $self->{plugin}->getExternalDbRlsIdByTag("enzyme");
    $self->{plugin}->userError("Plugin argument --handlerExternalDbs must provide a tag 'enzyme' with External Db info for the Enzyme Database") unless $rls_id;

    my $dbh = $self->{plugin}->getQueryHandle();
    my $sql = <<EOSQL;

  SELECT EC_number, enzyme_class_id
  FROM   sres.EnzymeClass
  WHERE  external_database_release_id = ?

EOSQL

    my $stmt = $dbh->prepare($sql); $stmt->execute($rls_id);
    while (my ($ecnum, $pk) = $stmt->fetchrow_array()){
      $self->{ECNumPKs}->{$ecnum} = $pk;
    }
  }

  return $self->{ECNumPKs}->{$ECNum};
}

# nothing special to do
sub _undoECNumber{
  my ($self) = @_;
  $self->_deleteFromTable('DoTS.AASequenceEnzymeClass');
}

################ anticodon ########################################
sub anticodon {
  my ($self, $tag, $bioperlFeature, $feature) = @_;

  my @tags = $bioperlFeature->get_tag_values($tag);
  die "Feature has more than one /anticodon\n" if scalar(@tags) != 1;

  my $transcript = &getGeneTranscript($self->{plugin}, $feature);
  $transcript->setAnticodon($tags[0]);
  return [];
}

sub _undoAnticodon{
  my ($self) = @_;
}

################# transcript's protein ID ######################################
sub transcriptProteinId {
  my ($self, $tag, $bioperlFeature, $feature) = @_;

  my ($proteinId) = $bioperlFeature->get_tag_values($tag);

  my $transcript = $feature->getChild("DoTS::Transcript");

  $transcript->setProteinId($proteinId);

  my $translatedAAFeat = $transcript->getChild('DoTS::TranslatedAAFeature');
  if ($translatedAAFeat) {
    my $aaSeq = $translatedAAFeat->getParent('DoTS::TranslatedAASequence');
    $aaSeq->setSecondaryIdentifier($proteinId) if ($aaSeq);
  }

  return [];
}

sub _undoTranscriptProteinId{
  my ($self) = @_;
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


################### open reading frame translation  #################
################ Translation#############################

sub setProvidedOrfTranslation {
  my ($self, $tag, $bioperlFeature, $orfFeature) = @_;

  my ($aaSequence) = $bioperlFeature->get_tag_values($tag);

  my $translatedAaFeature = $orfFeature->getChild('DoTS::TranslatedAAFeature');
  my $translatedAaSequence = $translatedAaFeature->getParent('DoTS::TranslatedAASequence');

  $translatedAaSequence->setSequence($aaSequence);

  return [];
}

sub _undoProvidedOrfTranslation{
  my ($self) = @_;

}

################## static methods to be used by this and other S.C.Q.H.s ######

sub getGeneAASeq {
  my ($plugin, $gusGeneFeature) = @_;

  my $transcript = &getGeneTranscript($plugin,$gusGeneFeature);

  my $translatedAAFeat = $transcript->getChild("DoTS::TranslatedAaFeature");

  my $aaSeq = $translatedAAFeat->getParent("DoTS::TranslatedAaSequence");

  return $aaSeq;
}

# given a gus feature, confirm that it is a gene, and, get its transcript
# note: assumes the gene has only one transcript (for now)
sub getGeneTranscript {
  my ($plugin, $gusGeneFeature) = @_;

  my $transcript = $gusGeneFeature->getChild("DoTS::Transcript");
  $transcript || $plugin->error("Can't find transcript for feature with na_feature_id = " . $gusGeneFeature->getId());
  return $transcript;
}


###################  misc_signal /note  #################

sub miscSignalNote {
  my ($self, $tag, $bioperlFeature, $feature) = @_;

  my @notes;
  foreach my $tagValue ($bioperlFeature->get_tag_values($tag)) {
    if ($tagValue eq 'TGA slenocysteine codon') {
      my $soId = $self->_getSOPrimaryKey('stop_codon_redefinition_as_selenocysteine');
      $feature->setSequenceOntologyId($soId);
    } elsif ($tagValue eq 'SECIS element') {
      my $id = $self->_getSOPrimaryKey('SECIS_element');
      $feature->setSequenceOntologyId($id);
    }

    my $arg = {comment_string => substr($tagValue, 0, 4000)};
    push(@notes, GUS::Model::DoTS::NAFeatureComment->new($arg));

  }
  return \@notes;
}

sub _undoMiscSignalNote{
  my ($self) = @_;
  $self->_deleteFromTable('DoTS.NAFeatureComment');
}

#################################################################

sub _getSOPrimaryKey {
  my ($self, $soTerm) = @_;
  die "using so term '$soTerm' which not declared at the top of this file" unless $soTerms->{$soTerm};

  return $self->{plugin}->getSOPrimaryKey($soTerm);
}

sub _deleteFromTable{
   my ($self, $tableName) = @_;

  &GUS::Supported::Plugin::InsertSequenceFeaturesUndo::deleteFromTable($tableName, $self->{'algInvocationIds'}, $self->{'dbh'}, $self->{'commit'});
}

sub _getTranslationStart{
  my ($self, $isReversed, $codingStart, $transcriptLoc) = @_;
  my $translationStart;

  if($isReversed){

    my $transcriptStop = $transcriptLoc->getEndMax();
    $translationStart = $transcriptStop - $codingStart + 1;

  }else{

    my $transcriptStart = $transcriptLoc->getStartMin();
    $translationStart = $codingStart - $transcriptStart + 1;
  }

  return $translationStart;
}

sub _getTranslationStop{
  my ($self, $isReversed, $codingStop, $transcriptLoc, $transcriptLength) = @_;
  my $translationStop;

  if($isReversed){
    my $transcriptStart = $transcriptLoc->getStartMin();
    $translationStop = $transcriptLength - ($codingStop - $transcriptStart);

  }else{
    my $transcriptStop = $transcriptLoc->getEndMax();
    $translationStop = $transcriptLength - ($transcriptStop - $codingStop);
  }

  return $translationStop;
}

1;
