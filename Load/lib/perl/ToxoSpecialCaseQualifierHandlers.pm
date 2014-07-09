package ApiCommonData::Load::SpecialCaseQualifierHandlers;
#vvvvvvvvvvvvvvvvvvvvvvvvv GUS4_STATUS vvvvvvvvvvvvvvvvvvvvvvvvv
  # GUS4_STATUS | SRes.OntologyTerm              | auto   | absent
  # GUS4_STATUS | SRes.SequenceOntology          | auto   | absent
  # GUS4_STATUS | Study.OntologyEntry            | auto   | absent
  # GUS4_STATUS | SRes.GOTerm                    | auto   | absent
  # GUS4_STATUS | Dots.RNAFeatureExon            | auto   | absent
  # GUS4_STATUS | RAD.SageTag                    | auto   | absent
  # GUS4_STATUS | RAD.Analysis                   | auto   | absent
  # GUS4_STATUS | ApiDB.Profile                  | auto   | absent
  # GUS4_STATUS | Study.Study                    | auto   | absent
  # GUS4_STATUS | Dots.Isolate                   | auto   | absent
  # GUS4_STATUS | DeprecatedTables               | auto   | absent
  # GUS4_STATUS | Pathway                        | auto   | absent
  # GUS4_STATUS | DoTS.SequenceVariation         | auto   | absent
  # GUS4_STATUS | RNASeq Junctions               | auto   | absent
  # GUS4_STATUS | Simple Rename                  | auto   | absent
  # GUS4_STATUS | ApiDB Tuning Gene              | auto   | absent
  # GUS4_STATUS | Rethink                        | auto   | absent
  # GUS4_STATUS | dots.gene                      | manual | unreviewed
die 'This file has broken or unreviewed GUS4_STATUS rules.  Please remove this line when all are fixed or absent';
#^^^^^^^^^^^^^^^^^^^^^^^^^ End GUS4_STATUS ^^^^^^^^^^^^^^^^^^^^

use strict;
use GUS::Supported::SpecialCaseQualifierHandlers;
use GUS::Model::DoTS::ExternalNASequence;
use GUS::Model::DoTS::AASequenceEnzymeClass;
use GUS::Model::DoTS::TranslatedAASequence;
use GUS::Model::DoTS::TranslatedAAFeature;
use GUS::Model::DoTS::Transcript;
use GUS::Model::DoTS::GeneFeature;
use GUS::Model::DoTS::ExonFeature;

# This is a pluggable module for GUS::Supported::Plugin::InsertSequenceFeatures 
my $soTerms = ({polypeptide => "polypeptide",
		protein_coding => "protein_coding",
		exon => "exon",
		pseudogene => "pseudogene",
		pseudogenic_transcript => "pseudogenic_transcript",
		protein_coding_primary_transcript => "protein_coding_primary_transcript",
		nc_primary_transcript => "nc_primary_transcript",
	       });

sub new {
  my ($class) = @_;
  my $self = {};
  bless($self, $class);
  return $self;
}

sub setPlugin{
  my ($self, $plugin) = @_;
  $self->{plugin} = $plugin;

  foreach my $soTerm (keys %$soTerms){
    unless($self->{plugin}->getSOPrimaryKey($soTerms->{$soTerm})){die "SO term $soTerms->{$soTerm} not found\n";}
  }

}

sub undoAll{
  my ($self, $algoInvocIds, $dbh) = @_;

  $self->{'algInvocationIds'} = $algoInvocIds;
  $self->{'dbh'} = $dbh;

  $self->_undoMiscSignalNote();
  $self->_undoECNumber();
  $self->_undoProtein();
  $self->_undoProduct();
  $self->_undoTranslation();
  $self->_undoExons();
  $self->_undoToxoAttributes();
  $self->_undoParent();
}

################ add exons and AA seq ###################################
sub exonsAndEmptyTranslation {
  my ($self, $tag, $bioperlFeature, $geneFeature) = @_;

  # this handler is called when we get the first "source_id"
  # (typically /systematic_id or /gene), so first we take care of
  # that:

  my @tags = $bioperlFeature->get_tag_values($tag);
  die "Feature has more than one identifier\n" if scalar(@tags) != 1;

  $geneFeature->setSourceId($tags[0]);

  # since P. falciparum input only contains "flat" CDS entries, we
  # need to auto-vivify a feature tree of transcripts and exons:

  my $proteinSoTermId = $self->{plugin}->getSOPrimaryKey($soTerms->{protein_coding})
    or die "No SO Term ID found for 'protein_coding'\n";

  my $geneFeatureSoTermId = $geneFeature->getSequenceOntologyId()
      or die "gene feature didn't have a SO term!\n";

  if ($geneFeatureSoTermId == $proteinSoTermId) {
    my $transcript = $self->_initTranscript($geneFeature,
					    $bioperlFeature,
					    "protein_coding_primary_transcript"
					   );
    $self->_initCDSExons($transcript, $bioperlFeature);
    $self->_initTranslation($transcript);
  } else {
    my $transcript = $self->_initTranscript($geneFeature,
					    $bioperlFeature,
					    "nc_primary_transcript"
					   );
    $self->_initRNAExons($transcript, $bioperlFeature);
  }

  return [];
}


sub _initCDSExons {

  my ($self, $transcript, $bioperlFeature) = @_;

  my $SOId = $self->{plugin}->getSOPrimaryKey($soTerms->{exon}) or die "SO term 'exon' not found.\n";

  my @exonLocations = sort { $a->start <=> $b->start }
    $bioperlFeature->location()->each_Location();

  @exonLocations = reverse @exonLocations if $bioperlFeature->location->strand == -1;

  my $orderNum = 1;
  my $cdsLen = 0;
  foreach my $exonLoc (@exonLocations) {
    my $exon = GUS::Model::DoTS::ExonFeature->new({
				name => 'exon',
				sequence_ontology_id => $SOId,
				na_sequence_id => $transcript->getNaSequenceId,
				external_database_release_id => $transcript->getExternalDatabaseReleaseId,
				is_predicted => 0,
				order_number => $orderNum,
				reading_frame => 3 - (($cdsLen % 3) || 3)
				});
    $exon->setIsInitialExon(1) if ($orderNum == 1);
    $exon->setIsFinalExon(1) if ($orderNum++ == scalar(@exonLocations));

    my $location = $self->{plugin}->makeLocation($exonLoc,
						 $bioperlFeature->strand());

    my $codingStart = $location->getStartMin();
    $codingStart = $location->getStartMax() unless $codingStart;
    my $codingEnd = $location->getEndMax();
    $codingEnd = $location->getEndMin() unless $codingEnd;
    $cdsLen += $codingEnd - $codingStart + 1;
    if ($location->getIsReversed()) {
      ($codingStart, $codingEnd) = ($codingEnd, $codingStart);
    }
    $exon->setCodingStart($codingStart);
    $exon->setCodingEnd($codingEnd);
    $exon->addChild($location);
    $transcript->addChild($exon);
  }
}

sub _initRNAExons {

  my ($self, $transcript, $bioperlFeature) = @_;

  my $SOId = $self->{plugin}->getSOPrimaryKey($soTerms->{exon}) or die "SO term 'exon' not found.\n";

  my @exonLocations = $bioperlFeature->location()->each_Location();
  my $orderNum = 1;
  my $cdsLen = 0;
  foreach my $exonLoc (@exonLocations) {
    my $exon = GUS::Model::DoTS::ExonFeature->new({
				name => 'exon',
				sequence_ontology_id => $SOId,
				na_sequence_id => $transcript->getNaSequenceId,
				external_database_release_id => $transcript->getExternalDatabaseReleaseId,
				is_predicted => 0,
				order_number => $orderNum,
				});
    $exon->setIsInitialExon(1) if ($orderNum == 1);
    $exon->setIsFinalExon(1) if ($orderNum++ == scalar(@exonLocations));

    my $location = $self->{plugin}->makeLocation($exonLoc,
						 $bioperlFeature->strand());

    $exon->addChild($location);
    $transcript->addChild($exon);
  }
}

################ add exons and AA seq ###################################

sub _initTranscript {
  my ($self, $geneFeature, $bioperlFeature, $soTerm) = @_;


  my $transcript = $geneFeature->getChild("DoTS::Transcript");

  my $SOId = $self->{plugin}->getSOPrimaryKey($soTerm)
    or die "No SO Term Id found for: $soTerm\n";

  unless ($transcript) {
    $transcript = GUS::Model::DoTS::Transcript->new({ source_id => $geneFeature->getSourceId(),
						      na_sequence_id => $geneFeature->getNaSequenceId(),
						      sequence_ontology_id => $SOId,
						      name => 'transcript',
						    });

    $transcript->setProduct($geneFeature->getProduct());
    $transcript->setExternalDatabaseReleaseId($geneFeature->getExternalDatabaseReleaseId());

    my $location = $self->{plugin}->makeLocation($bioperlFeature->location());
    $transcript->addChild($location);
    $transcript->submit();
    $transcript->setParent($geneFeature);
  }

  $transcript->setSourceId($geneFeature->getSourceId());

  return $transcript;
}

sub _undoExons {
  my ($self) = @_;

}

############### init TranslatedAAFeature  ###############################

# initialize a TranslatedAAFeature with an empty AASeq, unless already exists
sub _initTranslation {
  my ($self, $transcript, $sequence) = @_;


  unless ($transcript->isa("GUS::Model::DoTS::Transcript")) {
    die "_initTranslation expected a DoTS::Transcript feature object, not a @{[ref $transcript]}\n";

  }

  my $transAAFeat = $self->_retrieveTranslatedAAFeature($transcript);

  unless ($transAAFeat) {
    $transAAFeat = GUS::Model::DoTS::TranslatedAAFeature->new();
    $transAAFeat->setIsPredicted(0);

    my $aaSeq = GUS::Model::DoTS::TranslatedAASequence->new();

    $aaSeq->setSourceId($transcript->getSourceId());
    $aaSeq->setDescription($transcript->getProduct());
    $aaSeq->setExternalDatabaseReleaseId($transcript->getExternalDatabaseReleaseId());
    $aaSeq->setSequenceOntologyId($self->{plugin}->getSOPrimaryKey($soTerms->{polypeptide})) or die "SO term 'polypeptide' not found.\n";

    my $naSeq =
      GUS::Model::DoTS::ExternalNASequence->new({ na_sequence_id => $transcript->getNaSequenceId(),
						});
    if ($naSeq->retrieveFromDB()) {
      $aaSeq->setTaxonId($naSeq->getTaxonId);
    }

    $aaSeq->submit();

    $transAAFeat->setAaSequenceId($aaSeq->getId());
    $transAAFeat->setNaFeatureId($transcript->getId());
  }

  if ($sequence) {
    my $aaSeq = $self->_retrieveTranslatedAASequence($transAAFeat);
    $aaSeq->setSequence($sequence);
    $aaSeq->submit();
  }

  $transAAFeat->setSourceId($transcript->getSourceId());
  $transAAFeat->setDescription($transcript->getProduct());
  $transAAFeat->setExternalDatabaseReleaseId($transcript->getExternalDatabaseReleaseId());
  $transAAFeat->setSequenceOntologyId($self->{plugin}->getSOPrimaryKey($soTerms->{polypeptide})) or die "SO term 'polypeptide' not found.\n";

  $transAAFeat->submit();
}

sub _undoTranslation{
  my ($self) = @_;

  $self->_deleteFromTable('DoTS.TranslatedAAFeature');
  $self->_deleteFromTable('DoTS.TranslatedAASequence');

}

################ EC Number ###############################

# attach EC number to translated aa seq.
sub ECNumber {
  my ($self, $tag, $bioperlFeature, $transcript) = @_;

  $self->_initTranslation($transcript);

  my $translatedAAFeat = $self->_retrieveTranslatedAAFeature($transcript);

  my $aaSeq = $self->_retrieveTranslatedAASequence($translatedAAFeat);

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

  $aaSeq->submit();

  return [];
}

sub _getECNumPrimaryKey {
  my ($self, $ECNum) = @_;

  if (!$self->{ECNumPKs}) {
    my $rls_id = $self->{plugin}->getExternalDbRlsIdByTag("enzyme");
    $self->{plugin}->userError("Plugin argument --handlerExternalDbs must provide a tag 'enzyme' with External Db info for the Enzyme Database") unless $rls_id;
my $dbh = $self->{plugin}->getDbHandle();

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

################# Exon Type ########################################

sub exonType {
  my ($self, $tag, $bioperlFeature, $feature) = @_;

  my ($type) = $bioperlFeature->get_tag_values($tag);

  $feature->setIsInitialExon($type eq "Single" || $type eq "Initial");
  $feature->setIsFinalExon($type eq "Single" || $type eq "Terminal");

  return [];
}

################ Product ################################

# only keep the first /product qualifier
sub product {
  my ($self, $tag, $bioperlFeature, $feature) = @_;

  my @tagValues = $bioperlFeature->get_tag_values($tag);
  $feature->setProduct($tagValues[0]);

  # cascade product name to transcript, translation and AA sequence:
  my $transcript = $feature->getChild("DoTS::Transcript");
  if ($transcript) {
    $transcript->setProduct($tagValues[0]);
    my $translatedAAFeat = $self->_retrieveTranslatedAAFeature($transcript);
    if ($translatedAAFeat) {
      $translatedAAFeat->setDescription($tagValues[0]);
      my $aaSeq = $self->_retrieveTranslatedAASequence($translatedAAFeat);
      if ($aaSeq) {
	$aaSeq->setDescription($tagValues[0]);
	$aaSeq->submit();
      }
      $translatedAAFeat->submit();
    }
    $transcript->submit();
  }

  return [];
}

# nothing special to do
sub _undoProduct{
  my ($self) = @_;

}

################ Protein ################################

# only keep the first /product qualifier
sub protein {
  my ($self, $tag, $bioperlFeature, $feature) = @_;

  my @tagValues = $bioperlFeature->get_tag_values($tag);

  # traverse the tree until we get the AA sequence:
  my $transcript = $feature->getChild("DoTS::Transcript");
  if ($transcript) {
    my $translatedAAFeat = $self->_retrieveTranslatedAAFeature($transcript);
    if ($translatedAAFeat) {
      my $aaSeq = $self->_retrieveTranslatedAASequence($translatedAAFeat);
      if ($aaSeq) {
	$aaSeq->setSequence($tagValues[0]);
	$aaSeq->submit();
      }
      $translatedAAFeat->submit();
    }
  }

  return [];
}

# nothing special to do
sub _undoProtein{
  my ($self) = @_;

}

################# add GeneFeature #####################################

sub addGeneFeature{
  my ($self, $tag, $bioperlFeature, $feature) = @_;

  my ($sourceId) = $bioperlFeature->get_tag_values($tag);
  $feature->setSourceId($sourceId);

  #add a GeneFeature as a parent if the source ids match

  my $gene = $feature->getParent("GUS::Model::DoTS::GeneFeature");

  unless ($gene) {
    $gene = GUS::Model::DoTS::GeneFeature->new({source_id => $sourceId});

    if($gene->retrieveFromDB()){
      $feature->setParent($gene);
    }else{
      warn "There is no gene with source_id = $sourceId to associate with the child feature\n";
    }
  }

  $feature->submit();

  return [];
}

sub _undoParent{
  my ($self) = @_;

}

################# toxo Product ########################################

sub toxoProduct {
  my ($self, $tag, $bioperlFeature, $transcript) = @_;

  my ($product) = $bioperlFeature->get_tag_values($tag);

  my $gene = $self->_getTranscriptGene($bioperlFeature, $transcript);
  $gene->setProduct($product);
  $gene->submit();

  return [];
}

################# transcript ID ######################################

sub transcriptId {
  my ($self, $tag, $bioperlFeature, $feature) = @_;

  my ($proteinId) = $bioperlFeature->get_tag_values($tag);

  my $transcript = $feature->getChild("DoTS::Transcript");

  $transcript->setProteinId($proteinId);
  $transcript->submit();

  return [];
}

################# toxo Pseudo ########################################

sub toxoIsPseudo {
  my ($self, $tag, $bioperlFeature, $transcript) = @_;

  my ($isPseudo) = $bioperlFeature->get_tag_values($tag);

  return [] unless $isPseudo;

  my $gene = $self->_getTranscriptGene($bioperlFeature, $transcript);

  $gene->setIsPseudo(1);
  $transcript->setIsPseudo(1);

  $gene->setSequenceOntologyId($self->{plugin}->getSOPrimaryKey($soTerms->{pseudogene})) or die "SO term 'pseudogene' not found.\n";
  $transcript->setSequenceOntologyId($self->{plugin}->getSOPrimaryKey($soTerms->{pseudogenic_transcript})) or die "SO term 'pseudogenic_transcript' not found.\n";

  $gene->submit();
  $transcript->submit();

  return [];
}

################# toxo Source Id ########################################

sub toxoSourceId {
  my ($self, $tag, $bioperlFeature, $transcript) = @_;

  my ($sourceId) = $bioperlFeature->get_tag_values($tag);

  my $gene = $self->_getTranscriptGene($bioperlFeature, $transcript);
  $gene->setSourceId($sourceId);
  $transcript->setSourceId($sourceId);
  $gene->submit();

  return [];
}

################# toxo Protein ##########################################

sub toxoProtein {
  my ($self, $tag, $bioperlFeature, $transcript) = @_;

  my ($sequence) = $bioperlFeature->get_tag_values($tag);

  $self->_initTranslation($transcript, $sequence);

  return [];
}

sub _undoToxoAttributes {
  my ($self) = @_;
}

sub _getTranscriptGene {
  my ($self, $bioperlTranscriptFeature, $transcriptFeature) = @_;

  my $gene = $transcriptFeature->getParent("GUS::Model::DoTS::GeneFeature");

  unless ($gene) {
    $gene = GUS::Model::DoTS::GeneFeature->new();
    $gene->setName("gene");
    $gene->setNaSequenceId($transcriptFeature->getNaSequenceId());
    $gene->setExternalDatabaseReleaseId($transcriptFeature->getExternalDatabaseReleaseId());

    my $location = 
      $self->{plugin}->makeLocation($bioperlTranscriptFeature->location(),
				    $bioperlTranscriptFeature->strand());
    $gene->addChild($location);
    $gene->setSequenceOntologyId($self->{plugin}->getSOPrimaryKey($soTerms->{protein_coding})) or die "Did not retrieve SO id for SO term 'protein_coding'\n";

    # submit gene here, before it is attached to transcript, to submit
    # the gene-location relationship.
    $gene->submit();

    $gene->setVersionable(0); # workaround object layer bug:
                              # uniqueness contraint violation on
                              # multiple submits to version table

    $gene->addChild($transcriptFeature);
  }
  return $gene;
}

sub _retrieveTranslatedAAFeature {

  my ($self, $transcript) = @_;

  my $dbh = $self->{plugin}->getDbHandle();

  my $sth = $dbh->prepare(<<EOSQL);

    SELECT aa_feature_id
    FROM DoTS.TranslatedAAFeature
    WHERE na_feature_id = ?

EOSQL

  my $translatedAAFeature;

  $sth->execute($transcript->getId());


  if (my ($aaFeatureId) = $sth->fetchrow_array()) {
    $translatedAAFeature = GUS::Model::DoTS::TranslatedAAFeature->new({aa_feature_id => $aaFeatureId});
    $translatedAAFeature->retrieveFromDB();
  }

  return $translatedAAFeature;
}

sub _retrieveTranslatedAASequence {

  my ($self, $translatedAAFeature) = @_;

  my $translatedAASequence = GUS::Model::DoTS::TranslatedAASequence->new({aa_sequence_id => $translatedAAFeature->getAaSequenceId()});
  $translatedAASequence->retrieveFromDB();

  return $translatedAASequence;
}

###################  misc_signal /note  #################
sub miscSignalNote {
  my ($self, $tag, $bioperlFeature, $feature) = @_;

  my @notes;
  foreach my $tagValue ($bioperlFeature->get_tag_values($tag)) {

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

sub _deleteFromTable{
   my ($self, $tableName) = @_;

  &GUS::Supported::Plugin::InsertSequenceFeaturesUndo::deleteFromTable($tableName, $self->{'algInvocationIds'}, $self->{'dbh'});
}


1;
