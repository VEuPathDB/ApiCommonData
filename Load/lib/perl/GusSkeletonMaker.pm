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
  $gusGene->{bioperlFeature} = $bioperlGene;

  ##create hash to identify distinct exons based start_end
  my %distinctExons;

  ## create hash to identify distince transcript based on exons and their locations
  my %distinctTranscripts;

  foreach my $bioperlTranscript ($bioperlGene->get_SeqFeatures()) {
    my $transcriptKey;
    foreach my $exon ($bioperlTranscript->get_SeqFeatures()){
      $transcriptKey .= $exon->start()."_".$exon->end().",";
    }
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
    }
    $bioperlTranscript->{gusFeature} = $gusTranscript;
    push (@{$gusTranscript->{bioperlFeature}}, $bioperlTranscript);

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
    if ($bioperlGene->primary_tag() eq 'coding_gene' || $bioperlGene->primary_tag() eq 'repeated_gene' || $bioperlGene->primary_tag() eq 'pseudo_gene' || $bioperlGene->primary_tag() eq 'transposable_element_gene') {

      my $translatedAAFeat = &makeTranslatedAAFeat($plugin, $dbRlsId);
      $gusTranscript->addChild($translatedAAFeat);
      $translatedAAFeat->{bioperlTranscript} = $bioperlTranscript;

      foreach my $exonCdsArray (@gusExonsAndCodingLocations) {
        my $aaFeatureExon = GUS::Model::DoTS::AAFeatureExon->new({coding_start => $exonCdsArray->[1],
                                                                  coding_end => $exonCdsArray->[2],
                                                                 });
        $aaFeatureExon->addParent($translatedAAFeat);
        $aaFeatureExon->addParent($_);
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
    @sortedGusExons = sort{$b->getChild('DoTS::NALocation', 1)->getStartMin() <=> $a->getChild('DoTS::NALocation', 1)->getStartMin()} $gusGene->getChildren('DoTS::ExonFeature', 1);
  }else{
    @sortedGusExons = sort{$a->getChild('DoTS::NALocation', 1)->getStartMin() <=> $b->getChild('DoTS::NALocation', 1)->getStartMin()} $gusGene->getChildren('DoTS::ExonFeature', 1);
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



#################################################################

sub undoTables {
 return ('DoTS.RNAFeatureExon',
	 'DoTS.TranslatedAAFeature',
	 'DoTS.TranslatedAASequence',
	 );
}


1;
