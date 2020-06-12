package ApiCommonData::Load::gus4SpecialCaseQualifierHandlers;

#### a new package in gus4 copied from SpecialCaseQualifierHandlers

use strict;

use GUS::Supported::SpecialCaseQualifierHandlers;
use GUS::Model::DoTS::Gene;
use GUS::Model::DoTS::GeneInstance;
use GUS::Model::DoTS::Transcript;
use GUS::Model::DoTS::TranslatedAAFeature;
use GUS::Model::DoTS::TranslatedAASequence;
use GUS::Model::DoTS::AALocation;
use GUS::Supported::Plugin::InsertSequenceFeaturesUndo;
use GUS::Model::DoTS::AASequenceEnzymeClass;
use GUS::Model::DoTS::NAFeatureComment;
use GUS::Model::DoTS::Repeats;
use GUS::Model::ApiDB::GeneFeatureProduct;
use GUS::Model::DoTS::SplicedNASequence;

use GUS::Supported::Util;
use Data::Dumper;

# this is the list of so terms that this file uses.  we have them here so we
# can check them at start up time.

my $soTerms = ({stop_codon_redefinition_as_selenocysteine => 1,
		SECIS_element => 1,
		centromere => 1,
		GC_rich_promoter_region => 1,
		tandem_repeat => 1,
		exon => 1,
		ORF => 1,
	       });
sub new {
  my ($class) = @_;
  my $self = {};

  bless($self, $class);

  $self->{translationFlag};
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
#  $self->_undoProduct();
  $self->_undoSecondaryId();
  $self->_undoGene();
#  $self->_undoECNumber();
  $self->_undoAnticodon();
  $self->_undoProvidedTranslation();
  $self->_undoMiscSignalNote();
  $self->_undoSetParent();
#  $self->_undoSourceIdAndTranscriptSeq();
  $self->_undoSourceIdAndTranscriptSeqAndTranslatedAAFeat();
#  $self->_undoDbXRef();
#  $self->_undoGenbankDbXRef();
  $self->_undoGapLength();
  $self->_undoNote();
  $self->_undoPseudo();
#  $self->_undoTranscriptProteinId();
  $self->_undoTranscriptTranslExcept();
  $self->_undoProvidedOrfTranslation();
  $self->_undoCommentNterm();
  $self->_undoPartial();
#  $self->_undoNoteWithAuthor();
#  $self->_undoLiterature();
#  $self->_undoMiscFeatureNote();
#  $self->_undoObsoleteProduct();
  $self->_undoRptUnit();

}


######### Set source_id and, while here, exon start/stop and transcript seq ###

# 1. Loop through Transcripts... Set the Sequence for its splicedNaSequence
# 2. Find the Min CDS Start and Max CDS END and set translation(Start|Stop)
#    for the translatedAAFeature
# 3. No Splicing of the Exons occurs!!!
sub sourceIdAndTranscriptSeqAndTranslatedAAFeat {
  my ($self, $tag, $bioperlFeature, $geneFeature) = @_;

  # first set source id, and propogate it to the transcript and aa seq
  my @tagValues = $bioperlFeature->get_tag_values($tag);

  $tagValues[0] =~ s/^\s+//;
  $tagValues[0] =~ s/\s+$//;

  $geneFeature->setSourceId($tagValues[0]);

  my $geneLoc = $geneFeature->getChild('DoTS::NALocation');

  ## DoTS::ExonFeature
  my @exonFeatures = $geneFeature->getChildren("DoTS::ExonFeature");

  my @exonsSorted = map { $_->[0] }
  sort { $a->[3] ? ($b->[1] <=> $a->[1] || $b->[2] <=> $a->[2]) : ($a->[1] <=> $b->[1] || $a->[2] <=> $b->[2])}
  map { [ $_, $_->getFeatureLocation ]}
  @exonFeatures;

  my $final = scalar(@exonsSorted) - 1;

  my $order = 1;
  my $prevExon;

  my @exons;

  for my $exon (@exonsSorted) {

      if($prevExon){
#	  print ${[$prevExon->getFeatureLocation()]}[1]."\n";
	  if(${[$exon->getFeatureLocation()]}[0] == ${[$prevExon->getFeatureLocation()]}[0]
	     && ${[$exon->getFeatureLocation()]}[1] == ${[$prevExon->getFeatureLocation()]}[1]
	     && ${[$exon->getFeatureLocation()]}[2] == ${[$prevExon->getFeatureLocation()]}[2]
	    ){
	    ## $order--;  ## comment this out since each exon in table DoTs::ExonFeature is unique
	    die "duplicated exon found in the table Dots.ExonFeature for $tagValues[0]\n";  
	    ## temporary make it die. if this find, need to deal with exon.CodingStart and exon.CodingEnd too
	  }
      }

      #$exon->setOrderNumber($order);
      #my $sourceId = "$tagValues[0]-$order";
      my $sourceId = $tagValues[0]."-E".$order;
      $exon->setSourceId("$sourceId");
      my $naLoc = $exon->getChild('DoTS::NALocation');

      my $isReversed = $naLoc->getIsReversed();

      $prevExon = $exon;
      $order++;

      push(@exons,$exon);
  }

  ## DoTS::Transcript
  my $tcount = 0;
  my $aaCount = 0;

  my @transcripts = $geneFeature->getChildren('DoTS::Transcript');
  my @transcriptsSorted = map { $_->[0] }
  sort { $a->[3] ? ($b->[1] <=> $a->[1] || $b->[2] <=> $a->[2]) : ($a->[1] <=> $b->[1] || $a->[2] <=> $b->[2])}
  map { [ $_, $_->getFeatureLocation ]}
  @transcripts;

#  foreach my $transcript ($geneFeature->getChildren('DoTS::Transcript')) {
  foreach my $transcript (@transcriptsSorted) {

    $tcount++;
    ## set up a temporary transcript id 
    my $transcSourceId = $tagValues[0]."-T".$tcount;
    $transcript->setSourceId("$transcSourceId");

    # now do the exons and transcript seq
    my ($transcriptMin, $transcriptMax, @exons, $isReversed);

    foreach my $rnaExon ($transcript->getChildren('DoTS::RNAFeatureExon')) {
      my $exon = $rnaExon->getParent('DoTS::ExonFeature');
      push(@exons, $exon);
    }

    my @exonsSorted = map { $_->[0] }
      sort { $a->[3] ? $b->[1] <=> $a->[1] : $a->[1] <=> $b->[1] }
	map { [ $_, $_->getFeatureLocation ]}
	  @exons;

    my $final = scalar(@exonsSorted) - 1;
    my $transcriptSequence; ## = $transcript->getFeatureSequence();

    for my $exon (@exonsSorted) {

      my $chunk = $exon->getFeatureSequence();
      $transcriptSequence .= $chunk;
    }

    my $splicedNaSeq = $transcript->getParent('DoTS::SplicedNASequence');
    $splicedNaSeq->setSequence($transcriptSequence);
    $splicedNaSeq->setSourceId($transcript->getSourceId());
    my $transcriptLoc = $transcript->getChild('DoTS::NALocation');

    $isReversed = $transcriptLoc->getIsReversed();
    my $seq = $splicedNaSeq->getSequence();
    my $transcriptLength = length($seq);
    $transcriptLoc->setStartMin(1);
    $transcriptLoc->setStartMax(1);
    $transcriptLoc->setEndMin($transcriptLength);
    $transcriptLoc->setEndMax($transcriptLength);
    $transcriptLoc->setIsReversed(0);
    $transcript->setIsPredicted(1);


    if($bioperlFeature->primary_tag() eq "coding_gene" || $bioperlFeature->primary_tag() eq "pseudo_gene"){

      my @translatedAaFeatures = $transcript->getChildren('DoTS::TranslatedAAFeature');

      foreach my $translatedAaFeature (@translatedAaFeatures) {
	$aaCount++;
	my $aaSourceId = $tagValues[0]."-P".$aaCount;
	$translatedAaFeature->setSourceId("$aaSourceId");

	my $translatedAaSequence = $translatedAaFeature->getParent('DoTS::TranslatedAASequence');
	  $translatedAaSequence->setSourceId("$aaSourceId");


	my ($translationStart, $translationStop); # = $transcript->getTranslationStartStop();
	my $tLength = 0;
	my @bioperlExons = $translatedAaFeature->{bioperlTranscript}->get_SeqFeatures;
	my $exonCtr = scalar @bioperlExons;
	#print STDERR "For $tagValues[0], aaSourceId = $aaSourceId, exonCtr = $exonCtr\n";
	my $bioperlStrand = $translatedAaFeature->{bioperlTranscript}->location->strand;

	foreach my $exon (sort {($bioperlStrand == 1) ? ($a->location->start <=> $b->location->start) 
				  : ($b->location->start <=> $a->location->start) } @bioperlExons) {
	  my ($exonCodingStart) = $exon->get_tag_values('CodingStart');
	  my ($exonCodingEnd) = $exon->get_tag_values('CodingEnd');
	  if ($exonCodingStart ne '' && $exonCodingStart ne 'null' && !$translationStart) {
	    $translationStart = $tLength + (($bioperlStrand == 1) ? $exonCodingStart - $exon->location->start + 1 : $exon->location->end - $exonCodingStart + 1 );
	  }
	  if ($exonCodingEnd ne '' && $exonCodingEnd ne 'null') {
	    $translationStop = $tLength + ( ($bioperlStrand == 1) ? $exonCodingEnd - $exon->location->start + 1 : $exon->location->end - $exonCodingEnd + 1);
	  }
	  $tLength += $exon->location->end - $exon->location->start + 1;
	}

	$translationStart = $translationStart ? $translationStart : 1;
	$translationStop = $translationStop ? $translationStop : $tLength;

	#print STDERR $geneFeature->getChild('DoTS::NALocation')->getIsReversed(). "strand, ".$transcript->getSourceId().": start at $translationStart, end at $translationStop\n";

	if($translatedAaFeature){
	  $translatedAaFeature->setTranslationStart($translationStart);
	  $translatedAaFeature->setTranslationStop($translationStop);
	}
      }
    }
  }

  return [];
}

sub _undoSourceIdAndTranscriptSeqAndTranslatedAAFeat {
  my ($self) = @_

}


################ Set Parent for GeneFeature ######################

sub setParent{
  my ($self, $tag, $bioperlFeature, $geneFeature) = @_;

  my @tagValues = $bioperlFeature->get_tag_values($tag);
  

  $tagValues[0] =~ s/^\s+//;
  $tagValues[0] =~ s/\s+$//;


  my $gene = GUS::Model::DoTS::Gene->new({name => $tagValues[0]});
  my $geneInstance = GUS::Model::DoTS::GeneInstance->new();
  
  
  $geneInstance->setParent($geneFeature);

  if($gene->retrieveFromDB()){
      $geneInstance->setParent($gene);
      $geneInstance->set("is_reference",0);
  }else{

      $gene->set("name",$tagValues[0]);


      $geneInstance->setParent($gene);
      $geneInstance->set("is_reference",1);
  }

  return [];
}

sub _undoSetParent {
  my ($self) = @_;

}


################ For UTRFeature, set transcript as Parent ######################

sub setUtrParent{
  my ($self, $tag, $bioperlFeature, $utrFeature) = @_;

  # tagValue here is the value of Parent tag in bioperlFeature
  my @tagValues = $bioperlFeature->get_tag_values($tag);
  $tagValues[0] =~ s/^\s+//;
  $tagValues[0] =~ s/\s+$//;

  my $transcript = GUS::Model::DoTS::Transcript->new({source_id => $tagValues[0]});

  if ($transcript->retrieveFromDB()) {
    $utrFeature->setParent($transcript);
  }

  return [];
}

sub _undoSetUtrParent {
  my ($self) = @_;

}


################ Translation#############################

sub setProvidedTranslation {
  my ($self, $tag, $bioperlFeature, $feature) = @_;

  my ($aaSequence) = $bioperlFeature->get_tag_values($tag);

  my $transcript;
  if($bioperlFeature->primary_tag() =~ /gene/){
      $transcript = $feature->getChild("DoTS::Transcript");
  }else{
      $transcript = $feature;
  }

  my @translatedAaFeatures = $transcript->getChildren('DoTS::TranslatedAAFeature');
  foreach my $translatedAaFeature (@translatedAaFeatures) {
    my $translatedAaSequence = $translatedAaFeature->getParent('DoTS::TranslatedAASequence');

    my ($tempAASequence) = $translatedAaFeature->{bioperlTranscript}->get_tag_values($tag);
    $translatedAaSequence->setSequence($tempAASequence);
  }

  #  $translatedAaSequence->setSequence($aaSequence);

  return [];
}

sub _undoProvidedTranslation{
  my ($self) = @_;

}


sub setSecondaryId {
  my ($self, $tag, $bioperlFeature, $geneFeature) = @_;
  my @tagValues = $bioperlFeature->get_tag_values($tag);

  #get AA Sequence
  my @transcripts = $geneFeature->getChildren("DoTS::Transcript");
  foreach my $transcript (@transcripts) {
    my @translatedAAFeats = $transcript->getChildren('DoTS::TranslatedAAFeature');

    foreach my $translatedAAFeat (@translatedAAFeats) {
      if ($translatedAAFeat) {
	my $aaSeq = $translatedAAFeat->getParent('DoTS::TranslatedAASequence');
	if ($aaSeq) {
	  $aaSeq->setSecondaryIdentifier($tagValues[0]);
	}
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


############### Pseudo  ###############################

sub setPseudo {
  my ($self, $tag, $bioperlFeature, $feature) = @_;
  $feature->setIsPseudo(1);

  return [];
}

sub _undoPseudo{
    my ($self) = @_;
}

############### Partial  ###############################

sub setPartial {
  my ($self, $tag, $bioperlFeature, $feature) = @_;
  $feature->setIsPartial(1);

  return [];
}

sub _undoPartial{
    my ($self) = @_;
}

############### transl_except  ###############################

sub transcriptTranslExcept {
  my ($self, $tag, $bioperlFeature, $transcript) = @_;
  #my $transcript = $geneFeature->getChild("DoTS::Transcript");

  ## some transcrips may have more than one transl_except,
  my $transl_except = join (",", $bioperlFeature->get_tag_values($tag));

  $transcript->setTranslExcept($transl_except);
  return [];
}

sub _undoTranscriptTranslExcept {}

############### transl_table ###############################

sub transcriptTransTable {
  my ($self, $tag, $bioperlFeature, $transcript) = @_;
  #my $transcript = $geneFeature->getChild("DoTS::Transcript");
  my ($transl_table) = $bioperlFeature->get_tag_values($tag);
  $transcript->setTranslTable($transl_table);
  return [];
}

sub _undoTranscriptTransTable {
  my ($self) = @_;
}


################ anticodon ########################################
sub anticodon {
  my ($self, $tag, $bioperlFeature, $feature) = @_;

  my @tags = $bioperlFeature->get_tag_values($tag);
  die "Feature has more than one /anticodon\n" if scalar(@tags) != 1;

#  my $transcript = &getGeneTranscript($self->{plugin}, $feature);
#  $transcript->setAnticodon($tags[0]);

  $feature->setAnticodon($tags[0]);
  return [];
}

sub _undoAnticodon{
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

################ Note ########################################

sub note {
  my ($self, $tag, $bioperlFeature, $feature) = @_;
  return $self->{standardSCQH}->note($tag, $bioperlFeature, $feature);
}

sub _undoNote{
  my ($self) = @_;
  return $self->{standardSCQH}->_undoNote();
}

################ Product ################################

# only keep the first /product qualifier
# cascade product name to transcript, translation and AA sequence:
sub product {
  my ($self, $tag, $bioperlFeature, $feature) = @_;

 # print $bioperlFeature->primary_tag()."\n";
  my @tagValues = $bioperlFeature->get_tag_values($tag);
  if($tagValues[0] =~ />>/){
        my(@s) = split(/>>/,$tagValues[0]);
        $s[1] =~ s/\s+//g;
        $tagValues[0] = $s[1];
      }

  if($tagValues[0] =~ /;evidence=/){
        my(@s) = split(/;evidence=/,$tagValues[0]);
        $s[1] =~ s/^\s+//g;
        $tagValues[0] = $s[0];
        $feature->set("evidence",$s[1]);
      }


#  print STDERR Dumper $feature->getSourceId();

#  print STDERR "Feature Info:\n";
#  print STDERR Dumper $feature;
  $feature->setProduct($tagValues[0]);

  # cascade product name to transcript, translation and AA sequence:

  my @transcripts;
  if($bioperlFeature->primary_tag() =~ /gene/){
      @transcripts = $feature->getChildren("DoTS::Transcript");
    }else{
      push(@transcripts,$feature);
    }
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

################ rpt_type ################################

# create a comma delimited list of rpt_type
sub rptType {
  my ($self, $tag, $bioperlFeature, $feature) = @_;

  my @tagValues = $bioperlFeature->get_tag_values($tag);
  my $rptType = join(", ", @tagValues);
  $feature->setRptType($rptType);
  return [];
}

# nothing special to do
sub _undoRptType{
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

###################  misc_signal /note  #################

sub miscSignalNote {
  my ($self, $tag, $bioperlFeature, $feature) = @_;

  my @notes;
  foreach my $tagValue ($bioperlFeature->get_tag_values($tag)) {
    if ($tagValue eq 'TGA slenocysteine codon' || $tagValue eq 'stop_codon_redefined_as_selenocysteine') {
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


################### open reading frame translation  #################
################ Translation#############################

sub setProvidedOrfTranslation {  #### need more work for gus4
  my ($self, $tag, $bioperlFeature, $orfFeature) = @_;

  my ($aaSequence) = $bioperlFeature->get_tag_values($tag);

  my $translatedAaFeature = $orfFeature->getChild('DoTS::TranslatedAAFeature');
  my $translatedAaSequence = $translatedAaFeature->getParent('DoTS::TranslatedAASequence');
  my $soId = $self->_getSOPrimaryKey('ORF');
  $translatedAaSequence->setSequence($aaSequence);
  $translatedAaSequence->setSequenceOntologyId($soId);

  return [];
}

sub _undoProvidedOrfTranslation{
  my ($self) = @_;

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


############################## validation ########################

sub validateCodingSequenceLength {
    my ($self, $tag, $bioperlFeature, $feature) = @_;
    my ($msg, $warning);

    my @transcripts = $feature->getChildren("DoTS::Transcript");

    foreach my $transcript (@transcripts) {
      my $splicedNASequence = $transcript->getParent('DoTS::SplicedNASequence');

      #get corresponding mRNA bioperl object
      my $CDSLength;
      foreach my $mRNA ($bioperlFeature->get_SeqFeatures()) {
	if ($mRNA->{gusFeature} == $transcript) {
	  ($CDSLength) = $mRNA->get_tag_values('CDSLength') if $mRNA->has_tag('CDSLength');
	  last;
	}
      }

      my @translatedAAFeats = $transcript->getChildren('DoTS::TranslatedAAFeature');

      foreach my $translatedAAFeat (@translatedAAFeats ) {
      if ($translatedAAFeat) {
	my $transcriptSourceId = $transcript->getSourceId();

	my $aaSeq = $translatedAAFeat->getParent('DoTS::TranslatedAASequence');
	if($aaSeq && $CDSLength){
	    if($aaSeq->get('length') != (($CDSLength / 3) -1)){

		my $transcriptSeq = substr($splicedNASequence->getSequence(),$translatedAAFeat->getTranslationStart(),$CDSLength);
		my $lastCodon = substr($transcriptSeq,-3);

		if($aaSeq->get('length') == ($CDSLength/3) && !($lastCodon eq 'TGA' || $lastCodon eq 'TAA' || $lastCodon eq 'TAG')){
		    $warning = "***WARNING********* ";
		    if ($translatedAAFeat->{bioperlTranscript}->has_tag('stop_codon_redefined_as_selenocysteine') ) {
		      $warning .= "selenoprotein ";
		    }
		    if ($transcript->getIsPartial()){
		      $warning .= "Partial transcript ";
		    }
		    if($transcript->getIsPseudo()){
			$warning .= "Pseudo transcript ";
		    }
		    $warning .= "partial transcript " if ($transcript->getIsPartial() == 1);
		    $warning .= "$transcriptSourceId does not have a stop codon\n";

		    ## set is_partial=1 if gene does not have a stop codon
		    $transcript->setIsPartial(1);

		    if($self->{plugin}->{vlFh}){
			$self->{plugin}->{vlFh}->print("$warning\n");
		    }else{
			$self->{plugin}->log("$warning\n");
		    }
		}else{
		  $warning = "***WARNING********* Coding sequence for ";
		  if ($transcript->getIsPartial()){
		    $warning .= "partial ";
		  }
		  if($transcript->getIsPseudo()){
		    $warning .= "pseudo ";
		  }
		  $warning .= "transcript $transcriptSourceId with length: $CDSLength has trailing NAs. CDS length truncated to ".($aaSeq->get('length')*3)."\n";

		    ## set is_partial=1 if gene does not have a stop codon
		    $transcript->setIsPartial(1);

		    if($self->{plugin}->{vlFh}){
			$self->{plugin}->{vlFh}->print("$warning\n");
		    }else{
			$self->{plugin}->log("$warning\n");
		    }
#		    push(@{$self->{plugin}->{validationErrors}},$msg);
		}
	      }
	  }
	  }
      }
  }

    return [];

}


sub validateGene {
    my ($self, $tag, $bioperlFeature, $feature) = @_;

    my ($msg, $warning);

    my (@transcripts) = $feature->getChildren("DoTS::Transcript");

    my $sourceId = $feature->get("source_id");
    my $geneLoc = $feature->getChild("DoTS::NALocation");

    if(!$sourceId){
	$msg = "***ERROR********* This gene feature does not have a source id.\n";
	push(@{$self->{plugin}->{validationErrors}},$msg);
#	print $feature->getFeatureSequence();
	return;
    }

    foreach my $transcript (@transcripts){

      my @translatedAAFeats = $transcript->getChildren('DoTS::TranslatedAAFeature');

      foreach my $translatedAAFeat (@translatedAAFeats) {
      if ($translatedAAFeat) {
	my $trasccriptSourceId = $transcript->getSourceId();
	my $aaSeq = $translatedAAFeat->getParent('DoTS::TranslatedAASequence');

	if($aaSeq){

	    if($aaSeq->get('sequence') eq ''){

	      ## generate translation (protein) sequence if it is not in annotation file
	      ## by calling getSequence method in TranslatedAASequence object

		$aaSeq->setSequence($aaSeq->getSequence()) ;
#		last;
	    }else{
               my $transl_table = $transcript->getTranslTable();
               my $codonTable = ($transl_table) ? ($transl_table) : 1;

	       my $translatedAASeq = $translatedAAFeat->translateFeatureSequenceFromNASequence($codonTable);
	       my $providedAASeq = $aaSeq->get('sequence');
	       my $providedAASeqLessOneAtEnd = substr ($providedAASeq, 0, length($providedAASeq)-1 );
	       my $providedAASeqLessOneAtBegin = substr ($providedAASeq, 1, length($providedAASeq) );
	       my $translatedAASeqLessOneAtBegin = substr ($translatedAASeq, 1, length($providedAASeq) );
	       if ( ($providedAASeq ne $translatedAASeq)
		    && ($providedAASeqLessOneAtBegin ne $translatedAASeqLessOneAtBegin)
		    && ($providedAASeqLessOneAtEnd ne $translatedAASeq )) {
		 $msg = "***ERROR********* ";
		 $msg .= "selenoprotein " if ($translatedAAFeat->{bioperlTranscript}->has_tag('stop_codon_redefined_as_selenocysteine') );
		 $msg .= "Pseudo " if ($transcript->getIsPseudo());
		 $msg .= "Partial " if ($transcript->getIsPartial());

		 $msg .= "transcript $trasccriptSourceId protein sequence does not match with the annotation sequence.\n The provided sequence: ".$aaSeq->get('sequence')."\n The translated sequence ".$translatedAAFeat->translateFeatureSequenceFromNASequence($codonTable)."\n";
		    if($self->{plugin}->{vlFh}){
			$self->{plugin}->{vlFh}->print("$msg\n");
		    }else{
			$self->{plugin}->log("$msg\n");
		    }
		    #push(@{$self->{plugin}->{validationErrors}},$msg);
	       }
	    }

	    if($aaSeq->get('sequence') =~ /(\*)/ && !($aaSeq->get('sequence') =~ /\*$/)){
	      $warning = "***WARNING********* ";
	      $warning .= "selenoprotein " if ($bioperlFeature->has_tag('stop_codon_redefined_as_selenocysteine') 
					      || $translatedAAFeat->{bioperlTranscript}->has_tag('stop_codon_redefined_as_selenocysteine') );

	      if ($bioperlFeature->has_tag('product') ) {
		my ($tempProduct) = $bioperlFeature->get_tag_values('product');
		$warning .= "selenoprotein " if ($tempProduct =~ /selenoprotein/i);
	      }

	      $warning .= "Pseudo " if ($transcript->getIsPseudo());
	      $warning .= "Partial " if ($transcript->getIsPartial());

	      $warning .= "transcript $trasccriptSourceId contains internal stop codons.\n The sequence: ".$aaSeq->get('sequence')."\n";

		    if($self->{plugin}->{vlFh}){
			$self->{plugin}->{vlFh}->print("$warning\n");
		    }else{
			$self->{plugin}->log("$warning\n");
		    }
	    }
	  }
      }
      }
    }

    return [];

}


################ host #################

## join host with | if there are more than one

sub host {
  my ($self, $tag, $bioperlFeature, $feature) = @_;

  my @tagValues = $bioperlFeature->get_tag_values($tag);
  $feature->setSpecificHost(join(' | ', @tagValues));

  return [];
}

sub _undoHost{
  my ($self) = @_;

}


1;
