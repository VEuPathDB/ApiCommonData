package ApiCommonData::Load::SpecialCaseQualifierHandlers;
#vvvvvvvvvvvvvvvvvvvvvvvvv GUS4_STATUS vvvvvvvvvvvvvvvvvvvvvvvvv
  # GUS4_STATUS | SRes.OntologyTerm              | auto   | absent
  # GUS4_STATUS | SRes.SequenceOntology          | auto   | absent
  # GUS4_STATUS | Study.OntologyEntry            | auto   | absent
  # GUS4_STATUS | SRes.GOTerm                    | auto   | absent
  # GUS4_STATUS | Dots.RNAFeatureExon            | auto   | fixed
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
  # GUS4_STATUS | dots.gene                      | manual | fixed
#die 'This file has broken or unreviewed GUS4_STATUS rules.  Please remove this line when all are fixed or absent';
#^^^^^^^^^^^^^^^^^^^^^^^^^ End GUS4_STATUS ^^^^^^^^^^^^^^^^^^^^

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
  $self->_undoProduct();
  $self->_undoSecondaryId();
  $self->_undoGene();
  $self->_undoECNumber();
  $self->_undoAnticodon();
  $self->_undoProvidedTranslation();
  $self->_undoMiscSignalNote();
  $self->_undoSetParent();
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
  $self->_undoPartial();
  $self->_undoNoteWithAuthor();
  $self->_undoLiterature();
  $self->_undoMiscFeatureNote();
  $self->_undoObsoleteProduct();
  $self->_undoRptUnit();

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
      my $sourceId = "$tagValues[0]-$order";
      $exon->setSourceId("$sourceId");
      my $naLoc = $exon->getChild('DoTS::NALocation');

      my $isReversed = $naLoc->getIsReversed();

      # my $exonStart = $isReversed ? $naLoc->getEndMax : $naLoc->getStartMin();
      # my $exonStop = $isReversed ? $naLoc->getStartMin : $naLoc->getEndMax();

      # if($bioperlFeature->primary_tag() eq "coding_gene" || $bioperlFeature->primary_tag() eq "pseudo_gene"){
      # 	   $exon->setCodingStart($exonStart);
      # 	   $exon->setCodingEnd($exonStop);
      # }

      $prevExon = $exon;
      $order++;

      push(@exons,$exon);
  }

  # second, initialize isPseudo
  if (!defined($geneFeature->getIsPseudo())) {
    $geneFeature->setIsPseudo(0);
  }

  ## intialize isPartial
  if (!defined($geneFeature->getIsPartial())) {
    $geneFeature->setIsPartial(0);
  }


  ## DoTS::Transcript
  my $count = 0;

  foreach my $transcript ($geneFeature->getChildren('DoTS::Transcript')) {

    $count++;
    ## if transcript has sourceId, load it, otherwise use the sourceId of gene, sourceId-$count
    my $transcSourceId;
    if ($transcript->{bioperlFeature}->has_tag($tag)) {
      ($transcSourceId) = $transcript->{bioperlFeature}->get_tag_values($tag);
    } else {
      $transcSourceId = "$tagValues[0]-$count";
    }
    $transcript->setSourceId("$transcSourceId");

    my $translatedAAFeat = $transcript->getChild('DoTS::TranslatedAAFeature');

    if ($translatedAAFeat) {
      #$translatedAAFeat->setSourceId("$tagValues[0]-$count");
      $translatedAAFeat->setSourceId("$transcSourceId");
      my $aaSeq = $translatedAAFeat->getParent('DoTS::TranslatedAASequence');
      if ($aaSeq) {
	#$aaSeq->setSourceId("$tagValues[0]-$count");
	$aaSeq->setSourceId("$transcSourceId");
      }
    }

    # # add order_number for rnaFeatureExon
    # my @rnaFeatureExon = $transcript->getChildren('DoTS::RNAFeatureExon');
    # my @rnaFeatureExonSorted = map { $_->[0] }
    #   sort { $a->[3] ? ($b->[1] <=> $a->[1] || $b->[2] <=> $a->[2]) : ($a->[1] <=> $b->[1] || $a->[2] <=> $b->[2])}
    # 	map { [ $_, $_->getParent('DoTS::ExonFeature')->getFeatureLocation ]}
    # 	  @rnaFeatureExon;

    # my $rnaExCt = 0;
    # foreach my $rnaExon (@rnaFeatureExonSorted) {
    #   $rnaExCt++;
    #   $rnaExon->setOrderNumber($rnaExCt);
    # }


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

      my $translatedAaFeature = $transcript->getChild('DoTS::TranslatedAAFeature');
      my $translatedAaSequence = $translatedAaFeature->getParent('DoTS::TranslatedAASequence');

      # my ($codingStart,$codingStop);
      # 	foreach my $sortedExon (@exonsSorted){
      # 	    $codingStart = $sortedExon->get("coding_start");
      # 	    if($codingStart ne 'null' && $codingStart ne ''){
      # 		last;
      # 	    }
      # 	}

      # 	foreach my $sortedExon (reverse @exonsSorted){
      # 	    $codingStop = $sortedExon->get("coding_end");
      # 	    if($codingStop ne 'null' && $codingStop ne ''){
      # 		last;
      # 	    }
      # 	}

      # my $firstExonLoc = $exonsSorted[0]->getChild("DoTS::NALocation");
      # my $finalExonLoc = $exonsSorted[$final]->getChild("DoTS::NALocation");

      # if($isReversed){
      # 	  $codingStart = $firstExonLoc->getEndMax() - $codingStart;
      # 	  $codingStop = $codingStop - $finalExonLoc->getStartMin();
      # }else{
      # 	  $codingStart = $codingStart - $firstExonLoc->getStartMin();
      # 	  $codingStop = $finalExonLoc->getEndMax() - $codingStop;
      # }

      # my $translationStart = $self->_getTranslationStart($isReversed, $codingStart, $transcriptLoc);

      # my $translationStop = $self->_getTranslationStop($isReversed, $codingStop, $transcriptLoc, $transcriptLength);

# #      print STDERR $transcript->getSourceId()."\tCoding $codingStart\t$codingStop\t$transcriptLength\t$isReversed\t$translationStart\t$translationStop\n";

      my ($translationStart, $translationStop) = $transcript->getTranslationStartStop();
      print STDERR $geneFeature->getChild('DoTS::NALocation')->getIsReversed(). "strand, ".$transcript->getSourceId().": start at $translationStart, end at $translationStop\n";

      if($translatedAaFeature){
	  $translatedAaFeature->setTranslationStart($translationStart);
	  $translatedAaFeature->setTranslationStop($translationStop);
      }
    }
  }

  return [];
}

sub _undoSourceIdAndTranscriptSeq {
  my ($self) = @_;

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

  if ($codingValue ne '' && $codingValue ne 'null'){

    my @rnaExons = $exonFeature->getChildren("DoTS::RNAFeatureExon");

    my $tc = 0;
    foreach my $rnaExon (@rnaExons) {
      my $transcript = $rnaExon->getParent("DoTS::Transcript");
      $tc++;
      my $gene = $transcript->getParent("DoTS::GeneFeature");
      my $transcriptLoc = $transcript->getChild("DoTS::NALocation");
      my $translatedAAFeat = $transcript->getChild("DoTS::TranslatedAAFeature");
      my $translatedAaSequence = $translatedAAFeat->getParent("DoTS::TranslatedAASequence");
      my $transcriptSeq = $transcript->getParent("DoTS::SplicedNASequence");

      my $exonLoc = $exonFeature->getChild("DoTS::NALocation");
      my $geneLoc = $gene->getChild("DoTS::NALocation");
      my $isReversed = $exonLoc->getIsReversed();

      my @eachRnaExons = $transcript->getChildren('DoTS::RNAFeatureExon');
      my $totalExonsLength = 0;

      my @eachRnaExonsSorted = map { $_->[0] }
      sort { $a->[3] ? $b->[1] <=> $a->[1] : $a->[1] <=> $b->[1] }
	map { [ $_, $_->getParent('DoTS::ExonFeature')->getFeatureLocation ]}
	  @eachRnaExons;

      my $intronLength = 0;
      my $final = scalar (@eachRnaExonsSorted) - 1;
      my $firstExonLoc = $eachRnaExonsSorted[0]->getParent('DoTS::ExonFeature')->getChild("DoTS::NALocation");
      my $finalExonLoc = $eachRnaExonsSorted[$final]->getParent('DoTS::ExonFeature')->getChild("DoTS::NALocation");

      if($isStop){  ## set exonFeature.codingStop and AAFeature.translationStop

	$exonFeature->setCodingEnd($codingValue);

	# my $seq = $transcriptSeq->getSequence();
	# my $transcriptLength = length($seq);

	# my $tmpExon = $finalExonLoc;
	# my $ctr = $final-1;
	# while(!($codingValue >= $tmpExon->getStartMin() && $codingValue <= $tmpExon->getEndMax())){
	#   #print STDERR "process \$codingValue at codingStop: $codingValue..... For transcript: ".$transcript->getSourceId()." for exon: ".$tmpExon->getParent('DoTS::ExonFeature')->getSourceId()." at ".$tmpExon->getStartMin()."--".$tmpExon->getEndMax()."\n";
	#     my $currentExon = $eachRnaExonsSorted[$ctr]->getParent('DoTS::ExonFeature');

	#     if ($isReversed) {
	# 	$intronLength += ($currentExon->getChild("DoTS::NALocation")->getStartMin() - $tmpExon->getEndMax()) - 1;
	#     } else {
	# 	$intronLength += ($tmpExon->getStartMin() - $currentExon->getChild("DoTS::NALocation")->getEndMax()) - 1;
	#     }
	#     $tmpExon = $currentExon->getChild("DoTS::NALocation");
	#     $ctr--;
	# }

	# if(!$translatedAAFeat->{tempCodingStop} || (!$isReversed && $codingValue > $translatedAAFeat->{tempCodingStop}) || ($isReversed && $codingValue < $translatedAAFeat->{tempCodingStop})){

	#    $translatedAAFeat->{tempCodingStop} = $codingValue;

	#    my $codingPos;
	#    if ($isReversed) {
	#        $codingPos = $codingValue - $finalExonLoc->getStartMin() - $intronLength;
	#    } else {
	#        $codingPos = $finalExonLoc->getEndMax() - $codingValue - $intronLength;
	#    }

	#    my $translationStop = $self->_getTranslationStop($isReversed, $codingPos, $transcriptLoc, $transcriptLength);
	#    $translatedAAFeat->setTranslationStop($translationStop);
	# }

      }else{   ## set exon.codingStart and aafeature.translationStart

	$exonFeature->setCodingStart($codingValue);

	# my $tmpExon = $firstExonLoc;
	# my $ctr = 1;

	# while(!($codingValue >= $tmpExon->getStartMin() && $codingValue <= $tmpExon->getEndMax())){
	#   #print STDERR "process \$codingValue at codingStart: $codingValue.....transcript: ".$transcript->getSourceId()." for exon: ".$tmpExon->getParent('DoTS::ExonFeature')->getSourceId()." at ".$tmpExon->getStartMin()."--".$tmpExon->getEndMax()."\n";

	#     my $currentExon = $eachRnaExonsSorted[$ctr]->getParent('DoTS::ExonFeature');

	#     if ($isReversed) {
	# 	$intronLength += ($tmpExon->getStartMin() - $currentExon->getChild("DoTS::NALocation")->getEndMax()) - 1;
	#     } else {
	# 	$intronLength += ($currentExon->getChild("DoTS::NALocation")->getStartMin() - $tmpExon->getEndMax()) - 1;
	#     }
	#     $tmpExon = $currentExon->getChild("DoTS::NALocation");
	#     $ctr++;
	# }

	# if(!$translatedAAFeat->{tempCodingStart} || (!$isReversed && $codingValue < $translatedAAFeat->{tempCodingStart}) || ($isReversed && $codingValue > $translatedAAFeat->{tempCodingStart})){

	#     $translatedAAFeat->{tempCodingStart} = $codingValue;

	#     my $codingPos;
	#     if($isReversed){
	# 	$codingPos = $firstExonLoc->getEndMax() - $codingValue - $intronLength;
	#     } else {
	# 	$codingPos = $codingValue - $firstExonLoc->getStartMin() - $intronLength;
	#     }

	#     my $translationStart = $self->_getTranslationStart($isReversed, $codingPos, $transcriptLoc);
	#     $translatedAAFeat->setTranslationStart($translationStart);
	# }
      }

    }
  }else{
      if($isStop){
	  $exonFeature->setCodingEnd('');
      }else{
	  $exonFeature->setCodingStart('');
      }
  }


  return [];
}


sub _undoSetCodingAndTranslationStop {
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
      $feature->setIsPseudo(1);
  
#  if($bioperlFeature->primary_tag() =~ /gene/){
#      my $transcript = &getGeneTranscript($self->{plugin}, $feature);

#      $feature->setIsPseudo(1);
#      $transcript->setIsPseudo(1);

#  }else{
#      $feature->setIsPseudo(1);
#  }


  return [];
}

sub _undoPseudo{
    my ($self) = @_;
}

############### Partial  ###############################

sub setPartial {
  my ($self, $tag, $bioperlFeature, $feature) = @_;
       $feature->setIsPartial(1);

#  if($bioperlFeature->primary_tag() =~ /gene/){
#      my $transcript = &getGeneTranscript($self->{plugin}, $feature);

#      $feature->setIsPartial(1);
#      $transcript->setIsPartial(1);
#  }else{
#      $feature->setIsPartial(1);
#  }


  return [];
}

sub _undoPartial{
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

############### transl_table ###############################
sub transcriptTransTable {
  my ($self, $tag, $bioperlFeature, $geneFeature) = @_;
  my $transcript = $geneFeature->getChild("DoTS::Transcript");
  my ($transl_table) = $bioperlFeature->get_tag_values($tag);
  $transcript->setTranslTable($transl_table);
  return [];
}

sub _undoTranscriptTransTable {
  my ($self) = @_;
}

################ EC Number ###############################

# attach EC number to translated aa seq.
sub ECNumber {
  my ($self, $tag, $bioperlFeature, $feature) = @_;

  my $aaSeq = &getGeneAASeq($self->{plugin},$feature);
  
  my $sourceId = $feature->getSourceId();

  foreach my $tagValue ($bioperlFeature->get_tag_values($tag)) {
    if ($tagValue eq ""){

      next;
    }
    $tagValue =~ s/^EC: //;
    $tagValue =~ s/^EC //;
    if($tagValue =~ />>/){
	my(@s) = split(/>>/,$tagValue);
	$s[1] =~ s/\s+//g;
	$tagValue = $s[1];
    }

    $tagValue =~ s/\_/\-/;
    my $ecId = $self->_getECNumPrimaryKey($tagValue);
    unless ($ecId){
	push(@{$self->{plugin}->{validationErrors}},"***ERROR********* Invalid Enzyme Class '$tagValue' associated with gene source id '$sourceId'\n");
    }else{
	     my $args = {enzyme_class_id => $ecId,
			 evidence_code => 'Annotation Center'};
	     my $aaSeqEC = GUS::Model::DoTS::AASequenceEnzymeClass->new($args);
	     $aaSeq->addChild($aaSeqEC);
    }
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
  my $soId = $self->_getSOPrimaryKey('ORF');
  $translatedAaSequence->setSequence($aaSequence);
  $translatedAaSequence->setSequenceOntologyId($soId);

  return [];
}

sub _undoProvidedOrfTranslation{
  my ($self) = @_;

}

################## static methods to be used by this and other S.C.Q.H.s ######

sub getGeneAASeq {
  my ($plugin, $gusFeature) = @_;

  my $transcript;


  if ($gusFeature->toString() =~ /GeneFeature/){

      $transcript = &getGeneTranscript($plugin,$gusFeature);
  }else{
      $transcript = $gusFeature;
  }

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

    my $transcriptStart = $transcriptLoc->getStartMin();

    $translationStart = $transcriptStart + $codingStart;

  }else{

    my $transcriptStart = $transcriptLoc->getStartMin();

    $translationStart = $transcriptStart + $codingStart;
  }


  return $translationStart;
}

sub _getTranslationStop{
  my ($self, $isReversed, $codingStop, $transcriptLoc, $transcriptLength,$geneLoc) = @_;
  my $translationStop;

  if($isReversed){
    my $transcriptStop = $transcriptLoc->getEndMax();


    $translationStop = $transcriptStop - $codingStop;

  }else{
    my $transcriptStop = $transcriptLoc->getEndMax();


    $translationStop = $transcriptStop - $codingStop;
  }


  return $translationStop;
}






################ Literature ###############################

sub literature {
  my ($self, $tag, $bioperlFeature, $feature) = @_;

  my @dbRefNaFeatures;
  foreach my $tagValues ($bioperlFeature->get_tag_values($tag)) {
      my @tagValues = split(/,/,$tagValues);
      foreach my $tagValue (@tagValues){
	  if ($tagValue =~ /^\s*(PMID:\s*\d+)/) {
	      my $pmid = $1;
	      push(@dbRefNaFeatures, 
		   GUS::Supported::SpecialCaseQualifierHandlers::buildDbXRef($self->{plugin}, $pmid));
	  } else {
	      next;
	  }
      }
  }
  return \@dbRefNaFeatures;
}

# undo handled by undoDbXRef in GUS::Supported::Load::SpecialCaseQualifierHandler
sub _undoLiterature{
  my ($self) = @_;
  GUS::Supported::SpecialCaseQualifierHandlers::_undoDbXRef($self);
}

###################  obsolete_product  #################
sub obsoleteProduct {
  my ($self, $tag, $bioperlFeature, $feature) = @_;

  my @notes;
  foreach my $tagValue ($bioperlFeature->get_tag_values($tag)) {
    my $note = "Obsolete product name: $tagValue";
    my $arg = {comment_string => substr($note, 0, 4000)};
    push(@notes, GUS::Model::DoTS::NAFeatureComment->new($arg));

  }
  return \@notes;
}

sub _undoObsoleteProduct {
  my ($self) = @_;
  $self->_deleteFromTable('DoTS.NAFeatureComment');
}



###################  misc_feature /note  #################
sub miscFeatureNote {
  my ($self, $tag, $bioperlFeature, $feature) = @_;

  return undef if $bioperlFeature->has_tag('algorithm');

  # map contents of note to appropriate go term
  my @notes;
  my %note2SO = ('putative centromer' =>'centromere',   # centromere or centromeric
		 'centromere, putative' => 'centromere',
		 'GC-rich' => 'GC_rich_promoter_region',
		 'GC-rcih' => 'GC_rich_promoter_region',
		 'GC rich' => 'GC_rich_promoter_region',
		 'tetrad tandem repeat' => 'tandem_repeat',
		 'Possible exon' => 'exon',
		 'Could be the last exon' => 'NO_SO_TERM',
		 'maps at the 3' => 'NO_SO_TERM',
		);
  my @keys = keys(%note2SO);


  foreach my $tagValue ($bioperlFeature->get_tag_values($tag)) {

    my $found;
    foreach my $key (@keys) {
      $found = $key if $tagValue =~ /$key/i;
      last if $found;
    }
#    die "Can't find so term for note '$tagValue'" unless $found;

    my $soTerm = $note2SO{$found};

#    if ($soTerm ne 'NO_SO_TERM') {
    if ($soTerm && $soTerm ne 'NO_SO_TERM') {
      my $soId = $self->_getSOPrimaryKey($soTerm);
      $feature->setSequenceOntologyId($soId);
    }

    my $arg = {comment_string => substr($tagValue, 0, 4000)};
    push(@notes, GUS::Model::DoTS::NAFeatureComment->new($arg));

  }
  return \@notes;
}

sub _undoMiscFeatureNote{
  my ($self) = @_;
  $self->_deleteFromTable('DoTS.NAFeatureComment');
}

################# Note with Author #################################

sub noteWithAuthor {
  my ($self, $tag, $bioperlFeature, $feature) = @_;

  foreach my $controlledCuration ($bioperlFeature->get_tag_values($tag)){
    my $html = $self->_makeHTML($controlledCuration);

    my $comment = GUS::Model::DoTS::NAFeatureComment->
                                    new({ COMMENT_STRING => $html });

    $comment->setParent($feature);
  }

return [];
}

sub _undoNoteWithAuthor{
  my ($self) = @_;
  $self->_deleteFromTable('DoTS.NAFeatureComment');
}

sub _makeHTML{
  my($self, $controlledCuration) = @_;

  my @subTags = split(';', $controlledCuration);

  my %curation;
  my @htmls;
  my ($url, $text);
  foreach my $subTag (@subTags){
    my ($label, $data) = split('=', $subTag);
    $label =~ s/\s//g;

    $curation{$label} = $data;
  }

  foreach my $prefix (sort keys %curation) {
    my $val = $curation{$prefix};
    my $html;

    if($prefix eq "date"){
      next;
    }elsif($prefix eq "URL_display"){
      $text = $val;
    }elsif($prefix eq "URL" || $prefix eq "db_xref"){

      $url = $val;
      $url =~ s/\s//g;

    }elsif($prefix eq "dbxref"){

      ($prefix,$val) = split(":", $val);
      $html = "<b>$prefix</b>:\t$val<br>" if($val);

    }else{
      $html = "<b>$prefix</b>:\t$val<br>" if($val);
    }
    push(@htmls, $html);
  }

  if($url && $text){
    my $html = "<a href=\"$url\">$text</a><br>";
    push(@htmls, $html);
  }elsif($url){
    my $html = "<a href=\"$url\">$url</a><br>";
    push(@htmls, $html);
  }

  my $userCommentHtml = join('', @htmls);

  return $userCommentHtml;

}



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

      my $translatedAAFeat = $transcript->getChild('DoTS::TranslatedAAFeature');

      if ($translatedAAFeat) {
	my $transcriptSourceId = $transcript->getSourceId();

	my $aaSeq = $translatedAAFeat->getParent('DoTS::TranslatedAASequence');
	if($aaSeq && $CDSLength){
	    if($aaSeq->get('length') != (($CDSLength / 3) -1)){

		my $transcriptSeq = substr($splicedNASequence->getSequence(),$translatedAAFeat->getTranslationStart(),$CDSLength);
		my $lastCodon = substr($transcriptSeq,-3);

		if($aaSeq->get('length') == ($CDSLength/3) && !($lastCodon eq 'TGA' || $lastCodon eq 'TAA' || $lastCodon eq 'TAG')){
		    $warning = "***WARNING********* ";
		    if ($transcript->getIsPartial()){
		      $warning .= "Partial transcript ";
		    }
		    if($transcript->getIsPseudo()){
			$warning .= "Pseudo transcript ";
		    }
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

    return [];

}

# sub validateStopCodons {
#     my ($self, $tag, $bioperlFeature, $feature) = @_;

#     my ($msg, $warning);
#     my (@transcripts) = $feature->getChildren("DoTS::Transcript");
#     my $sourceId = $feature->get("source_id");
#     my $geneLoc = $feature->getChild("DoTS::NALocation");

#     foreach my $transcript (@transcripts){

# 	my $translatedAAFeat = $transcript->getChild('DoTS::TranslatedAAFeature');
# 	if ($translatedAAFeat) {
# 	    my $proteinSourceId = $translatedAAFeat->get("source_id");
# 	    $proteinSourceId =~ s/\-\d+$//;
# 	    my $aaSeq = $translatedAAFeat->getParent('DoTS::TranslatedAASequence');

# 	    if($aaSeq){
# 		if($aaSeq->get('sequence') =~ /(\*)/ && !($aaSeq->get('sequence') =~ /\*$/)){

# 		    if($transcript->getIsPseudo()){
# 			$warning = "***WARNING********* Pseudogene $proteinSourceId contains internal stop codons.\n The sequence: ".$aaSeq->get('sequence')."\n";

# 			if($self->{plugin}->{vlFh}){
# 			    $self->{plugin}->{vlFh}->print("$warning\n");
# 			}else{
# 			    $self->{plugin}->log("$warning\n");
# 			}
# 		    }else{
# 		    #print "Hello\n";
# 			$msg = "***ERROR********* $proteinSourceId contains internal stop codons.\n The sequence: ".$aaSeq->get('sequence')."\n";
# 			push(@{$self->{plugin}->{validationErrors}},$msg);
# 		    }
# 		}

# 	}
# 	}

#     }

#     return [];
# }


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

      my $translatedAAFeat = $transcript->getChild('DoTS::TranslatedAAFeature');

      if ($translatedAAFeat) {
	my $trasccriptSourceId = $transcript->getSourceId();
	my $aaSeq = $translatedAAFeat->getParent('DoTS::TranslatedAASequence');

	if($aaSeq){

	    if($aaSeq->get('sequence') eq ''){
		$aaSeq->setSequence($aaSeq->getSequence()) ;
#		last;
	    }else{
               my $transl_table = $transcript->getTranslTable();
               my $codonTable = ($transl_table) ? ($transl_table - 1) : 0;

	       if($aaSeq->get('sequence') ne $translatedAAFeat->translateFeatureSequenceFromNASequence($codonTable)){
		 $msg = "***ERROR********* ";
		 $msg .= "selenoprotein " if ($transcript->{bioperlFeature}->has_tag('stop_codon_redefined_as_selenocysteine') );
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
	      $warning .= "selenoprotein " if ($bioperlFeature->has_tag('stop_codon_redefined_as_selenocysteine') );
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

    return [];

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
