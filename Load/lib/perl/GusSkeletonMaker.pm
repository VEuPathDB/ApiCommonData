package ApiCommonData::Load::GusSkeletonMaker;

use strict;
use GUS::Model::DoTS::SplicedNASequence;
use GUS::Model::DoTS::GeneFeature;
use GUS::Model::DoTS::Transcript;
use GUS::Model::DoTS::ExonFeature;
use GUS::Model::DoTS::TranslatedAASequence;
use GUS::Model::DoTS::TranslatedAAFeature;
use GUS::Model::DoTS::RNAFeatureExon;
use GUS::Model::DoTS::Gene;
use GUS::Model::DoTS::GeneInstance;
use FileHandle;


my $soTerms = { 'coding_gene'=>'protein_coding',
		'repeated_gene'=>'repeat_region',
		'haplotype_block'=>'haplotype_block',
		'tRNA_gene'=> 'tRNA_encoding',
		'rRNA_gene'=> 'rRNA_encoding',
                'pseudo_gene'=>'pseudogene',                 
		'ncRNA_gene'=> 'non_protein_coding',
		'snRNA_gene'=> 'snRNA_encoding',
		'snoRNA_gene'=> 'snoRNA_encoding',
		'scRNA_gene'=> 'scRNA_encoding',
		'SRP_RNA_gene'=> 'SRP_RNA_encoding',
		'RNase_MRP_RNA_gene'=> 'RNase_MRP_RNA',
                'RNase_P_RNA_gene' => 'RNase_P_RNA',
                'transposable_element_gene' => 'transposable_element_gene',
		'misc_RNA_gene'=> 'non_protein_coding',
		'misc_feature_gene'=> 'non_protein_coding',
		'transcript' => 'transcript',
		'exon' => 'exon',
		'ORF' => 'ORF',
		'miRNA_gene' => 'miRNA_encoding',
	      };

#--------------------------------------------------------------------------------

sub makeGeneSkeleton{
  my ($plugin, $bioperlGene, $genomicSeqId, $dbRlsId, $taxonId,$isPredicted) = @_;

  my $gusGene = &makeGusGene($plugin, $bioperlGene, $genomicSeqId, $dbRlsId, $isPredicted);

  $bioperlGene->{gusFeature} = $gusGene;

  my $transcriptExons;  # hash to remember each transcript's exons

  foreach my $bioperlTranscript ($bioperlGene->get_SeqFeatures()) {
    my $transcriptNaSeq = &makeTranscriptNaSeq($plugin, $bioperlTranscript, $taxonId, $dbRlsId);

    my $gusTranscript = &makeGusTranscript($plugin, $bioperlTranscript, $dbRlsId);
    $gusTranscript->setParent($gusGene);
    $bioperlTranscript->{gusFeature} = $gusTranscript;

    $transcriptNaSeq->addChild($gusTranscript);

#    my $gusTranscriptId = $gusTranscript->getId();
    $transcriptExons->{$gusTranscript}->{transcript} = $gusTranscript;

    foreach my $bioperlExon ($bioperlTranscript->get_SeqFeatures()) {
      my $gusExon = &getGusExon($plugin, $bioperlExon, $genomicSeqId, $dbRlsId, $gusGene);
      $bioperlExon->{gusFeature} = $gusExon;

      push(@{$transcriptExons->{$gusTranscript}->{exons}}, $gusExon);
    }


    if ($bioperlGene->primary_tag() eq 'coding_gene' || $bioperlGene->primary_tag() eq 'repeated_gene' || $bioperlGene->primary_tag() eq 'pseudo_gene' || $bioperlGene->primary_tag() eq 'transposable_element_gene') {

      my $translatedAAFeat = &makeTranslatedAAFeat($dbRlsId);
      $gusTranscript->addChild($translatedAAFeat);
      

      my $translatedAASeq = &makeTranslatedAASeq($plugin, $taxonId, $dbRlsId);
      $translatedAASeq->addChild($translatedAAFeat);

      # make sure we submit all kids of the translated aa seq
      $gusGene->addToSubmitList($translatedAASeq);
    }
  }

  # attach gene's exons to the appropriate transcripts
  # update the transcript's splicedNaSequence
  # the transcriptObjId is the perl object id for the transcript object
  foreach my $transcriptObjId (keys %$transcriptExons) {
    my $gusTranscript = $transcriptExons->{$transcriptObjId}->{transcript};

    if(my $exons = $transcriptExons->{$transcriptObjId}->{exons}) {

      foreach my $exon (@$exons) {
	my $rnaFeatureExon = GUS::Model::DoTS::RNAFeatureExon->new();
        $rnaFeatureExon->setParent($gusTranscript);
        $rnaFeatureExon->setParent($exon);

        $exon->setParent($gusGene);
      }
    }
  }
  return $gusGene;
}

sub makeOrfSkeleton{
  my ($plugin, $bioperlOrf, $genomicSeqId, $dbRlsId, $taxonId, $isPredicted) = @_;

  my $gusMiscFeature = &makeGusOrf($plugin, $bioperlOrf, $genomicSeqId, $dbRlsId,$isPredicted);
  $bioperlOrf->{gusFeature} = $gusMiscFeature;

  my $translatedAAFeat = &makeTranslatedAAFeat($dbRlsId);
  $gusMiscFeature->addChild($translatedAAFeat);

  my $translatedAASeq = &makeTranslatedAASeq($plugin, $taxonId, $dbRlsId);
  $translatedAASeq->addChild($translatedAAFeat);

  # make sure we submit all kids of the translated aa seq
  $gusMiscFeature->addToSubmitList($translatedAASeq);

  return $gusMiscFeature;
}

#--------------------------------------------------------------------------------

sub makeGusGene {
  my ($plugin, $bioperlGene, $genomicSeqId, $dbRlsId, $isPredicted) = @_;

  my $type = $bioperlGene->primary_tag();

  $plugin->error("Trying to make gus skeleton from a tree rooted with an unexpected type: '$type'") 
     unless (grep {$type eq $_} ("haplotype_block","coding_gene", "tRNA_gene", "rRNA_gene", "snRNA_gene", "snoRNA_gene", "misc_RNA_gene", "misc_feature_gene", "repeated_gene","pseudo_gene","SRP_RNA_gene","RNase_MRP_RNA_gene","RNase_P_gene","RNase_MRP_gene","RNase_P_RNA_gene","ncRNA_gene","scRNA_gene", "miRNA_gene", "transposable_element_gene"));

  my $gusGene = $plugin->makeSkeletalGusFeature($bioperlGene, $genomicSeqId,
						$dbRlsId, 
						'GUS::Model::DoTS::GeneFeature',
						$soTerms->{$type},$isPredicted);
  return $gusGene;
}

sub makeGusOrf {
  my ($plugin, $bioperlOrf, $genomicSeqId, $dbRlsId,$isPredicted) = @_;

  my $type = $bioperlOrf->primary_tag();

  $plugin->error("Trying to make gus skeleton from a tree rooted with an unexpected type: '$type'") unless $type eq  "ORF";

  my $gusOrf = $plugin->makeSkeletalGusFeature($bioperlOrf, $genomicSeqId,
					       $dbRlsId,
					       'GUS::Model::DoTS::Miscellaneous',
					       $soTerms->{$type},$isPredicted);
  return $gusOrf;
}

#--------------------------------------------------------------------------------

# does not compute the spliced seq itself
sub makeTranscriptNaSeq {
  my ($plugin, $bioperlTranscript, $taxonId, $dbRlsId) = @_;

  my $soId = $plugin->getSOPrimaryKey('mature_transcript');

  # not using ExternalNASequence here because we're not setting source_id(???)
  my $transcriptNaSeq = 
    GUS::Model::DoTS::SplicedNASequence->new({sequence_ontology_id => $soId,
                                              sequence_version => 1,
                                              taxon_id => $taxonId,
                                              external_database_release_id => $dbRlsId
                                             });
  return $transcriptNaSeq;
}

#--------------------------------------------------------------------------------

sub makeGusTranscript {
  my ($plugin, $bioperlTranscript, $dbRlsId) = @_;

  my $type = $bioperlTranscript->primary_tag();

  $plugin->error("Expected a transcript, got: '$type'")
    unless ($type eq 'transcript');

  my $gusTranscript =
    $plugin->makeSkeletalGusFeature($bioperlTranscript,
				    undef,      # set with addChild above
				    $dbRlsId,
				    'GUS::Model::DoTS::Transcript',
				    $soTerms->{$type});
  return $gusTranscript;
}

#--------------------------------------------------------------------------------

# get a gus exon from a bioperl exon
# if the gus gene already has a gus exon with that location (from a previous
# transcript), we return that one
# otherwise, make a new gus exon and add it to the gus gene
sub getGusExon {
  my ($plugin, $bioperlExon, $genomicSeqId, $dbRlsId, $gusGene) = @_;
  my $gusExon;
  my @geneExons = $gusGene->getChildren('DoTS::ExonFeature');
  @geneExons = () unless (@geneExons);

  foreach my $geneExon (@geneExons) {
    my $geneExonStart = $geneExon->getChild('DoTS::NALocation')->getStartMin();
    my $geneExonEnd = $geneExon->getChild('DoTS::NALocation')->getEndMax();

    if ($geneExonStart == $bioperlExon->start()	&& $geneExonEnd == $bioperlExon->end()) {
      return $geneExon;
    }
  }
  return  &makeGusExon($plugin, $bioperlExon, $genomicSeqId, $dbRlsId);
}

#--------------------------------------------------------------------------------

sub makeGusExon {
  my ($plugin, $bioperlExon, $genomicSeqId, $dbRlsId) = @_;

  my $type = $bioperlExon->primary_tag();

  $plugin->error("Expected an exon, got: '$type'") unless ($type eq 'exon');

  my $gusExon = $plugin->makeSkeletalGusFeature($bioperlExon,
						$genomicSeqId,
						$dbRlsId,
						'GUS::Model::DoTS::ExonFeature',
						$soTerms->{$type});

#add exon coding start/stop here if the bioperl object has coding start/stop values, otherwise set to the exon start/stop
  return $gusExon;
}

#--------------------------------------------------------------------------------

sub makeTranslatedAASeq {
  my ($plugin, $taxonId, $dbRlsId) = @_;

  my $soId = $plugin->getSOPrimaryKey('polypeptide');

  my $translatedAaSeq = 
    GUS::Model::DoTS::TranslatedAASequence->
	new({sequence_ontology_id => $soId,
	     sequence_version => 1,
	     taxon_id => $taxonId,
	     external_database_release_id => $dbRlsId
	    });

  return $translatedAaSeq;
}

#--------------------------------------------------------------------------------

sub makeTranslatedAAFeat {
  my ($dbRlsId) = @_;

  my $transAAFeat = GUS::Model::DoTS::TranslatedAAFeature->
    new({external_database_release_id => $dbRlsId,
         is_predicted => 0,
        });

  return $transAAFeat;
}

#--------------------------------------------------------------------------------

# postprocess a feature tree (before it is written to database by ISF)
sub postprocessFeatureTree {
  my ($gusFeatureTree, $postprocessDirective, $postprocessDir, $postprocessDataStore);

  return unless $postprocessDirective;

  if ($postprocessDirective eq 'PRINT_TRANSCRIPT_IDS') {
    return printTranscriptIds($gusFeatureTree, $postprocessDirective, $postprocessDir, $postprocessDataStore);
  }

  if ($postprocessDirective eq 'PRINT_TRANSCRIPT_INFO') {
    return printTranscriptInfo($gusFeatureTree, $postprocessDirective, $postprocessDir, $postprocessDataStore);
  }

  if ($postprocessDirective eq 'SET_TRANSCRIPT_IDS') {
    return setTranscriptIds($gusFeatureTree, $postprocessDirective, $postprocessDir, $postprocessDataStore);
  }

  die "You have provided an unsupported postprocessing directive in argument '--postprocessingDirective $postprocessDirective'.  Supported directives are PRINT_TRANSCRIPT_IDS, PRINT_TRANSCRIPT_INFO and SET_TRANSCRIPT_IDS\n";
}

sub printTranscriptIds {
  my ($gusFeatureTree, $postprocessDirective, $postprocessDir, $postprocessDataStore) = @_;

  if (!$postprocessDataStore) {
    -d $postprocessDir || die "Error: the postprocessing dir provided in argument '--postprocessingDir $postprocessDir' is not a directory\n";
    # save the file handle in the data store for use in following feature trees
    $postprocessDataStore = FileHandle->new();
    $postprocessDataStore->open(">$postprocessDir/transcriptIds") || die "Can't open transcript IDs file '$postprocessDir/transcriptIds' for writing\n";
  }

  # SUFEN TODO: fill these in with proper values from the feature tree.
  my $geneId = $gusFeatureTree;
  my $transcriptId = $gusFeatureTree;
  my $transcriptSeq = $gusFeatureTree;

  print $postprocessDataStore "$geneId\t$transcriptId\t$transcriptSeq\n";

  return $postprocessDataStore;
}

sub printTranscriptInfo {
  my ($gusFeatureTree, $postprocessDirective, $postprocessDir, $postprocessDataStore) = @_;

  if (!$postprocessDataStore) {
    -d $postprocessDir || die "Error: the postprocessing dir provided in argument '--postprocessingDir $postprocessDir' is not a directory\n";
    # save the file handle in the data store for use in following feature trees
    $postprocessDataStore = FileHandle->new();
    $postprocessDataStore->open(">$postprocessDir/transcriptInfo") || die "Can't open transcript info file '$postprocessDir/transcriptInfo' for writing\n";
  }

  # SUFEN TODO: fill these in with proper values from the feature tree.
  my $geneId = $gusFeatureTree;
  my $transcriptId = $gusFeatureTree;
  my $transcriptSeq = $gusFeatureTree;
  my @exonPath;
  my @exonLocations;
  foreach my $exon ($gusFeatureTree) {
    my $exonNumber = $gusFeatureTree;
    my $exonStart = $gusFeatureTree;
    my $exonEnd = $gusFeatureTree;
    push(@exonPath, $exonNumber);
    push(@exonLocations, [$exonStart, $exonEnd]);
  }

  @exonPath = sort {$a <=> $b} @exonPath;
  my $exonPathStr = join(",", @exonPath);

  @exonLocations = sort {$a->[0] - $b->[0] || $a->[1] - $b->[1]} @exonLocations;
  my @exonLocStrings = map { "$_->[0]-$_->[1]"} @exonLocations;
  my $exonLocationsStr = join(",", @exonLocStrings);

  print $postprocessDataStore "$geneId\t$transcriptId\t$transcriptSeq\t$exonPathStr\t$exonLocationsStr\n";

  return $postprocessDataStore;
}

sub setTranscriptIds{
  my ($gusFeatureTree, $postprocessDirective, $postprocessDir, $postprocessDataStore) = @_;

  if (!$postprocessDataStore) {
    -d $postprocessDir || die "Error: the postprocessing dir provided in argument '--postprocessingDir $postprocessDir' is not a directory\n";
    # save the file handle in the data store for use in following feature trees
    my $fh = FileHandle->new();
    $fh->open("$postprocessDir/transcriptInfoAndIds") || die "Can't open transcript info and IDs file '$postprocessDir/transcriptInfoAndIds'\n";
    while(<$fh>) {
      chomp;
      my ($geneId, $transcriptSeq, $exonPath, $exonLocations, $transcriptId) = split(/\t/);
      die "Invalid line in file $postprocessDir/transcriptInfoAndIds:\n$_\n" unless $geneId && $transcriptSeq && $transcriptId;
      $postprocessDataStore->{$geneId}->{$transcriptSeq} = $transcriptId;
    }
    $fh->close();
  }

  # SUFEN TODO
  my $geneId = $gusFeatureTree;
  my $transcriptSeq = $gusFeatureTree;

  my $transcriptId = $postprocessDataStore->{$geneId}->{$transcriptSeq};

  # SUFEN TODO -- set transcript id in gus object

  return $postprocessDataStore;
}


#################################################################

sub undoTables {
 return ('DoTS.RNAFeatureExon',
	 'DoTS.TranslatedAAFeature',
	 'DoTS.TranslatedAASequence',
	 );
}


1;
