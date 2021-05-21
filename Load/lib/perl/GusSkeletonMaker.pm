package ApiCommonData::Load::GusSkeletonMaker;
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
  # GUS4_STATUS | dots.gene                      | manual | reviewed
#die 'This file has broken or unreviewed GUS4_STATUS rules.  Please remove this line when all are fixed or absent';
#^^^^^^^^^^^^^^^^^^^^^^^^^ End GUS4_STATUS ^^^^^^^^^^^^^^^^^^^^

use strict;
use GUS::Model::DoTS::SplicedNASequence;
use GUS::Model::DoTS::GeneFeature;
use GUS::Model::DoTS::Transcript;
use GUS::Model::DoTS::ExonFeature;
use GUS::Model::DoTS::TranslatedAASequence;
use GUS::Model::DoTS::TranslatedAAFeature;
use GUS::Model::DoTS::RNAFeatureExon;
use GUS::Model::DoTS::AAFeatureExon;
use GUS::Model::DoTS::Gene;
use GUS::Model::DoTS::GeneInstance;
use FileHandle;


my $soTerms = { #'coding_gene'=>'protein_coding',
                'coding_gene'=>'protein_coding_gene',
		'repeated_gene'=>'repeat_region',
		'haplotype_block'=>'haplotype_block',
		'tRNA_gene'=> 'ncRNA_gene',
		'rRNA_gene'=> 'ncRNA_gene',
                'pseudo_gene'=>'pseudogene',
		'ncRNA_gene'=> 'ncRNA_gene',
		'snRNA_gene'=> 'ncRNA_gene',
		'snoRNA_gene'=> 'ncRNA_gene',
		'scRNA_gene'=> 'ncRNA_gene',
		'tmRNA_gene'=> 'ncRNA_gene',
		'SRP_RNA_gene'=> 'ncRNA_gene',
		'RNase_MRP_RNA_gene'=> 'ncRNA_gene',
                'RNase_P_RNA_gene' => 'ncRNA_gene',
                'telomerase_RNA_gene' => 'ncRNA_gene',
                'transposable_element_gene' => 'transposable_element_gene',
                'antisense_RNA_gene' => 'ncRNA_gene',
		'misc_RNA_gene'=> 'ncRNA_gene',
		'misc_feature_gene'=> 'ncRNA_gene',
		'transcript' => 'transcript',
		'exon' => 'exon',
		'ORF' => 'ORF',
		'miRNA_gene' => 'ncRNA_gene',
		'mRNA' => 'mRNA',
		'miRNA' => 'miRNA',
		'misc_RNA' => 'ncRNA',  ## coding for ncRNA since misc_RNA is not in ONTOLOGYTERM table yet
		'ncRNA' => 'ncRNA',
		'rRNA' => 'rRNA',
		'RNase_MRP_RNA' => 'RNase_MRP_RNA',
		'RNase_P_RNA' => 'RNase_P_RNA',
		'scRNA' => 'scRNA',
		'snRNA' => 'snRNA',
		'snoRNA' => 'snoRNA',
		'SRP_RNA' => 'SRP_RNA',
		'tRNA' => 'tRNA',
		'telomerase_RNA' => 'telomerase_RNA',
		'tmRNA' => 'tmRNA',
		'transcript' => 'transcript',
	      };

#--------------------------------------------------------------------------------

sub makeGeneSkeleton{
  my ($plugin, $bioperlGene, $genomicSeqId, $dbRlsId, $taxonId,$isPredicted) = @_;

  my $gusGene = &makeGusGene($plugin, $bioperlGene, $genomicSeqId, $dbRlsId, $isPredicted);

  $bioperlGene->{gusFeature} = $gusGene;
  $gusGene->{bioperlFeature} = $bioperlGene;

  ##create hash to identify distinct exons based start_end
  my %distinctExons;

  ## create hash to identify distince transcript based on exons and their locations
  my %distinctTranscripts;

  foreach my $bioperlTranscript ($bioperlGene->get_SeqFeatures()) {
    my $transcriptKey;

    my @sortedExons = sort { $a->start <=> $b->start || $a->end <=> $b->end } $bioperlTranscript->get_SeqFeatures();
    my @sortedExonLocationStrings = map { $_->start . "_" . $_->end } @sortedExons;
    my $transcriptKey = join(",", @sortedExonLocationStrings);

    #print STDERR "\$transcriptKey = $transcriptKey\n";

    my ($transcriptNaSeq, $gusTranscript);
    if (!$distinctTranscripts{$transcriptKey}) {
      $transcriptNaSeq = &makeTranscriptNaSeq($plugin, $bioperlTranscript, $taxonId, $dbRlsId);
      $gusTranscript = &makeGusTranscript($plugin, $bioperlTranscript, $dbRlsId);
      $distinctTranscripts{$transcriptKey} = $gusTranscript;

      $gusTranscript->setParent($gusGene);
      $transcriptNaSeq->addChild($gusTranscript);

    } else {
      $gusTranscript = $distinctTranscripts{$transcriptKey};

      ## print duplicated gene ID in case it is represented by ID 
      my ($errorId, $errorTransId);
      if ($bioperlGene->has_tag('ID') ) {
	($errorId) = $bioperlGene->get_tag_values('ID');
	($errorTransId) = $bioperlTranscript->get_tag_values('ID') if ($bioperlTranscript->has_tag('ID'));
      } elsif ($bioperlGene->has_tag('locus_tag') ) {
	($errorId) = $bioperlGene->get_tag_values('locus_tag');
	($errorTransId) = $bioperlTranscript->get_tag_values('locus_tag') if ($bioperlTranscript->has_tag('locus_tag'));
      }

      print STDERR "Duplicated transcript found at $errorId, $errorTransId: $transcriptKey\n";
    }
    $bioperlTranscript->{gusFeature} = $gusTranscript;  ## bioperlTranscript to gusTranscript is many to one
    push (@{$gusTranscript->{bioperlFeature}}, $bioperlTranscript);  ## gusTransscript to bioperlTranscript is one to many

    my @gusExonsAndCodingLocations;

    foreach my $bioperlExon ($bioperlTranscript->get_SeqFeatures()) {
      my $gusExon;

      ##check to see if I've seen this exon:
      if(!$distinctExons{$bioperlExon->start()."_".$bioperlExon->end()}){
        $gusExon = &makeGusExon($plugin, $bioperlExon, $genomicSeqId, $dbRlsId);
        $distinctExons{$bioperlExon->start()."_".$bioperlExon->end()} = $gusExon;
        $gusExon->setParent($gusGene);
	$bioperlExon->{gusFeature} = $gusExon;
      }else{
        $gusExon =  $distinctExons{$bioperlExon->start()."_".$bioperlExon->end()};
	$bioperlExon->{gusFeature} = $gusExon;
      }


      my ($codingStart) = $bioperlExon->get_tag_values('CodingStart');
      my ($codingEnd) = $bioperlExon->get_tag_values('CodingEnd');
      push @gusExonsAndCodingLocations, [$gusExon, $codingStart, $codingEnd];

      push (@{$gusExon->{bioperlFeature}}, $bioperlExon);  ### gusExon to bioperlExon is one to many

      ## make rnafeatureexon and associate it with its transcript
      my $rnaFeatureExon = GUS::Model::DoTS::RNAFeatureExon->new();
      $rnaFeatureExon->setParent($gusTranscript);
      $rnaFeatureExon->setParent($gusExon);
      $rnaFeatureExon->{bioperlFeature} = $bioperlExon;  ## rnaFeatureExon to bioperlExon is one to one

#### do not assign the codingStart and codingEnd to rnaFeatureExon
#      my $codingStart = 0;
#      my $codingEnd = 0;
#      ($codingStart) = $bioperlExon->get_tag_values('CodingStart');
#      ($codingEnd) = $bioperlExon->get_tag_values('CodingEnd');
#      ($codingStart) ? $rnaFeatureExon->setCodingStart($codingStart) : $rnaFeatureExon->setCodingStart('');
#      ($codingEnd) ? $rnaFeatureExon->setCodingEnd($codingEnd) : $rnaFeatureExon->setCodingEnd('');

    } ##this should end the exon loop

    ## set order_number exons in DoTS::RNAFeatureExon
    my @sortedRnaExons;
    if($gusGene->getChild('DoTS::NALocation', 1)->getIsReversed()){
      @sortedRnaExons = sort {$b->getParent('DoTS::ExonFeature', 1)->getChild('DoTS::NALocation', 1)->getStartMin() <=> $a->getParent('DoTS::ExonFeature', 1)->getChild('DoTS::NALocation', 1)->getStartMin()} $gusTranscript->getChildren('DoTS::RNAFeatureExon', 1);
    } else {
      @sortedRnaExons = sort {$a->getParent('DoTS::ExonFeature', 1)->getChild('DoTS::NALocation', 1)->getStartMin() <=> $b->getParent('DoTS::ExonFeature', 1)->getChild('DoTS::NALocation', 1)->getStartMin()} $gusTranscript->getChildren('DoTS::RNAFeatureExon', 1);
    }
    foreach my $i (0..$#sortedRnaExons) {
      $sortedRnaExons[$i]->setOrderNumber($i+1);
    }

    ## make translatedAAFeat and translatedAASeq for coding gene
    ## only for $bioperlGene->primary_tag() eq coding_gene and $bioperlTranscript->primary_tag() eq mRNA
    if ( ($bioperlGene->primary_tag() eq 'coding_gene'
	  || $bioperlGene->primary_tag() eq 'repeated_gene'
	  || $bioperlGene->primary_tag() eq 'pseudo_gene'
	  || $bioperlGene->primary_tag() eq 'transposable_element_gene')
	 && ($bioperlTranscript->primary_tag() eq 'mRNA'
	     || $bioperlTranscript->primary_tag() eq 'pseudogenic_transcript')

       ) {

      my $translatedAAFeat = &makeTranslatedAAFeat($plugin, $dbRlsId);
      $gusTranscript->addChild($translatedAAFeat);
      $translatedAAFeat->{bioperlTranscript} = $bioperlTranscript;

      foreach my $exonCdsArray (@gusExonsAndCodingLocations) {
        my $aaFeatureExon = GUS::Model::DoTS::AAFeatureExon->new({coding_start => $exonCdsArray->[1],
                                                                  coding_end => $exonCdsArray->[2],
                                                                 });
        $aaFeatureExon->setParent($translatedAAFeat);
        $aaFeatureExon->setParent($exonCdsArray->[0]);
      }

      my $translatedAASeq = &makeTranslatedAASeq($plugin, $taxonId, $dbRlsId);
      $translatedAASeq->addChild($translatedAAFeat);
      $translatedAASeq->{bioperlTranscript} = $bioperlTranscript;

      # make sure we submit all kids of the translated aa seq
      $gusGene->addToSubmitList($translatedAASeq);
    }
  }

  ##sort exons in DoTS::ExonFeature
  my @sortedGusExons;
  if($gusGene->getChild('DoTS::NALocation', 1)->getIsReversed()){
    @sortedGusExons = sort{$b->getChild('DoTS::NALocation', 1)->getEndMax() <=> $a->getChild('DoTS::NALocation', 1)->getEndMax() || $b->getChild('DoTS::NALocation', 1)->getStartMin() <=> $a->getChild('DoTS::NALocation', 1)->getStartMin()} $gusGene->getChildren('DoTS::ExonFeature', 1);
  }else{
    @sortedGusExons = sort{$a->getChild('DoTS::NALocation', 1)->getStartMin() <=> $b->getChild('DoTS::NALocation', 1)->getStartMin() || $a->getChild('DoTS::NALocation', 1)->getEndMax() <=> $b->getChild('DoTS::NALocation', 1)->getEndMax() } $gusGene->getChildren('DoTS::ExonFeature', 1);
  }

  ##set the order number
  for(my $a = 0;$a<scalar(@sortedGusExons);$a++){
    $sortedGusExons[$a]->setOrderNumber($a+1);
  }

  return $gusGene;
}

sub makeOrfSkeleton{
  my ($plugin, $bioperlOrf, $genomicSeqId, $dbRlsId, $taxonId, $isPredicted) = @_;

  my $gusMiscFeature = &makeGusOrf($plugin, $bioperlOrf, $genomicSeqId, $dbRlsId,$isPredicted);
  $bioperlOrf->{gusFeature} = $gusMiscFeature;
  $gusMiscFeature->{bioperlFeature} = $bioperlOrf;

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
     unless (grep {$type eq $_} ("haplotype_block","coding_gene", "tRNA_gene", "rRNA_gene", "snRNA_gene", "snoRNA_gene", "misc_RNA_gene", "misc_feature_gene", "repeated_gene","pseudo_gene","SRP_RNA_gene","RNase_MRP_RNA_gene","RNase_P_gene","RNase_MRP_gene","RNase_P_RNA_gene","ncRNA_gene", "tmRNA_gene", "scRNA_gene", "miRNA_gene", "transposable_element_gene","telomerase_RNA_gene", "antisense_RNA_gene"));

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

  $plugin->error("Expected a transcript, including all kinds of RNA, got: '$type'")
    unless ($type =~ /transcript/ || $type =~ /RNA/ || $type =~ /misc_feature/);

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
  my ($plugin, $bioperlExon, $genomicSeqId, $dbRlsId,$gusGene) = @_;

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
  my ($plugin,$dbRlsId) = @_;

  my $transAAFeat = GUS::Model::DoTS::TranslatedAAFeature->
    new({external_database_release_id => $dbRlsId,
         is_predicted => 0,
        });

  return $transAAFeat;
}

#--------------------------------------------------------------------------------

# postprocess a feature tree (before it is written to database by ISF)
sub postprocessFeatureTree {
  my ($gusFeatureTree, $postprocessDirective, $postprocessDir, $postprocessDataStore) = @_;

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

  my $gusGene = $gusFeatureTree;
  my $geneId = $gusGene->getSourceId();
  my @gusTranscripts = $gusGene->getChildren('DoTS::Transcript', 1);
  foreach my $gusTranscript (@gusTranscripts) {
    my $transcriptId = $gusTranscript->getSourceId();
    #my $splicedNaSeq = $gusTranscript->getParent('DoTS::SplicedNASequence', 1);
    #my $transcriptSeq = $splicedNaSeq->getSequence();
    my $transcriptSeq = $gusTranscript->getFeatureSequence();

    my @exonPath;
    my @exonLocations;
    my @gusExons = $gusTranscript->getExons();
    foreach my $gusExon (@gusExons) {
      my $exonStart = $gusExon->getChild('DoTS::NALocation', 1)->getStartMin(); 
      my $exonEnd = $gusExon->getChild('DoTS::NALocation', 1)->getEndMax();
      my $exonOrderNumber = $gusExon->getOrderNumber();
      push (@exonPath, $exonOrderNumber);
      push (@exonLocations, $exonStart, $exonEnd);
    }

    @exonPath = sort {$a <=> $b} @exonPath;
    my $exonPathStr = join (",", @exonPath);

    @exonLocations = sort {$a <=> $b} @exonLocations;
    my $exonLocationsStr = join (",", @exonLocations);

    #print $postprocessDataStore "$geneId\t$transcriptId\t$transcriptSeq\n";
    print $postprocessDataStore "$geneId\t$transcriptSeq\t$exonPathStr\t$exonLocationsStr\t$transcriptId\n";
  }

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

  my $gusGene = $gusFeatureTree;
  my $geneId = $gusGene->getSourceId();
  my @gusTranscripts = $gusGene->getChildren('DoTS::Transcript', 1);

  foreach my $gusTranscript (@gusTranscripts) {
    my $transcriptId = $gusTranscript->getSourceId();
    #my $splicedNaSeq = $gusTranscript->getParent('DoTS::SplicedNASequence', 1);
    #my $transcriptSeq = $splicedNaSeq->getSequence();
    my $transcriptSeq = $gusTranscript->getFeatureSequence();

    my @exonPath;
    my @exonLocations;
    my @gusExons = $gusTranscript->getExons();
    foreach my $gusExon (@gusExons) {
      my $exonStart = $gusExon->getChild('DoTS::NALocation', 1)->getStartMin(); 
      my $exonEnd = $gusExon->getChild('DoTS::NALocation', 1)->getEndMax();
      my $exonOrderNumber = $gusExon->getOrderNumber();
      push (@exonPath, $exonOrderNumber);
      push (@exonLocations, $exonStart, $exonEnd);
    }

    @exonPath = sort {$a <=> $b} @exonPath;
    my $exonPathStr = join (",", @exonPath);

    @exonLocations = sort {$a <=> $b} @exonLocations;
    my $exonLocationsStr = join (",", @exonLocations);

    print $postprocessDataStore "$geneId\t$transcriptSeq\t$exonPathStr\t$exonLocationsStr\n";
  }

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
      $postprocessDataStore->{$geneId}->{$transcriptSeq}->{$exonPath} = $transcriptId;
    }
    $fh->close();
  }

  my $gusGene = $gusFeatureTree;
  my $geneId = $gusGene->getSourceId();
  my @gusTranscripts = $gusGene->getChildren('DoTS::Transcript', 1);
  foreach my $gusTranscript (@gusTranscripts) {

    my $transcriptSeq = $gusTranscript->getFeatureSequence();

    ## get exonPath
    my @ePaths;
    foreach my $gusExonFeat ($gusTranscript->getExons()) {
      push @ePaths, $gusExonFeat->getOrderNumber();
    }
    my $exonFeatPath = join (",", sort {$a <=> $b} @ePaths);

    my $transcriptId = $postprocessDataStore->{$geneId}->{$transcriptSeq}->{$exonFeatPath};
    if ($transcriptId) { ## set transcript ID in gus object
      $gusTranscript->setSourceId($transcriptId);
    } else {
      die "Can not find the generated transcript ID for gene: $geneId\n";
    }

    my $splicedNaSeq = $gusTranscript->getParent('DoTS::SplicedNASequence');
    $splicedNaSeq->setSourceId($transcriptId);  ## set sourceId for splicedNaSequence
    $splicedNaSeq->setSequence($transcriptSeq);

    if ( ($gusGene->getName() eq 'coding_gene'
	  || $gusGene->getName() eq 'pseudo_gene'
	  || $gusGene->getName() eq 'repeated_gene'
	  || $gusGene->getName() eq 'transposable_element_gene')

	 && $gusTranscript->getName() eq 'mRNA') {

      my @translatedAaFeatures = $gusTranscript->getChildren('DoTS::TranslatedAAFeature', 1);
      my $aaCount = 0;
      foreach my $translatedAaFeature (sort {$a->translation_stop <=> $b->translation_stop} @translatedAaFeatures) {
	$aaCount++;
	my $aaSourceId = $transcriptId."-p".$aaCount;
	$translatedAaFeature->setSourceId("$aaSourceId");

	my $translatedAaSequence = $translatedAaFeature->getParent('DoTS::TranslatedAASequence');
	$translatedAaSequence->setSourceId("$aaSourceId");
      }
    }
  }

  return $postprocessDataStore;
}

#################################################################

sub undoTables {
 return ('DoTS.RNAFeatureExon',
         'DoTS.AAFeatureExon',
	 'DoTS.TranslatedAAFeature',
	 'DoTS.TranslatedAASequence',
	 );
}


1;
