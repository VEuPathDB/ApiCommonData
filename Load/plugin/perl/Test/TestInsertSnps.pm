package ApiCommonData::Load::Plugin::Test::TestInsertSnps;
use base qw(GUS::PluginMgr::PluginTestCase);

use strict;

use Error qw(:try);

use GUS::Model::DoTS::Transcript;
use GUS::Model::DoTS::ExonFeature;
use GUS::Model::DoTS::ExternalNASequence;
use GUS::Model::DoTS::NALocation;
use GUS::Model::DoTS::SnpFeature;
use GUS::Model::DoTS::SeqVariation;

use GUS::Model::DoTS::RNAFeatureExon;

use ApiCommonData::Load::Plugin::InsertSnps;

use Data::Dumper;

use GUS::PluginMgr::PluginError;

#================================================================================
# Globals..(the plugin being tested is a global which will be reinstanciated 
# after every test
#================================================================================


my $insertSnps;
my %naSequenceIds;
my ($realTranscriptId, $testLocation, $testMap);

#================================================================================
# Set the global stuff using setup
#================================================================================

sub set_up {
  my ($self) = @_;

  my $args = {reference => '3D7',
              organism => 'Plasmodium falciparum',
              snpExternalDatabaseName => 'Broad SNPs',
              snpExternalDatabaseVersion => '09-21-2006',
              naExternalDatabaseName => 'Sanger P. falciparum chromosomes',
              naExternalDatabaseVersion => '2005-09-26',
              seqTable => 'DoTS::ExternalNASequence',
              ontologyTerm => 'SNP',
              snpFile => '/files/cbil/data/cbil/plasmoDB//5.2/analysis_pipeline/snp/PfalciparumChroms_broad_snpsMummer.gff',
             };

  $self->SUPER::set_up('ApiCommonData::Load::Plugin::InsertSnps', $args);

  $insertSnps = $self->getPlugin();

  my $dbh = $insertSnps->getQueryHandle();
  $self->_getStuffFromDatabase($dbh);
}

#================================================================================
# Helper Methods
#================================================================================

sub _getStuffFromDatabase {
  my ($self, $dbh) = @_;

  $self->makeNaSequences($dbh);
  $self->makeRealTranscript($dbh);
  $self->makeTestLocationAndMap();
}

#--------------------------------------------------------------------------------

sub makeNaSequences {
  my ($self, $dbh) = @_;

  my $sql = "select source_id, na_sequence_id from dots.EXTERNALNASEQUENCE where regexp_like(source_id, 'MAL\\d+')";
  my $sh = $dbh->prepare($sql);
  $sh->execute();

  while(my ($sourceId, $id) = $sh->fetchrow_array()) {
    $naSequenceIds{$sourceId} = $id;
  }
  $sh->finish();
}

#--------------------------------------------------------------------------------

sub makeRealTranscript {
  my ($self, $dbh) = @_;

  my $sql = "select na_feature_id from dots.TRANSCRIPT where source_id = 'PFD0872w-1'";
  #my $sql = "select na_feature_id from dots.TRANSCRIPT where source_id = 'PFI0455w-1'";

  my $sh = $dbh->prepare($sql);
  $sh->execute();

  while(my ($id) = $sh->fetchrow_array()) {
    $realTranscriptId = $id;
  }
  $sh->finish();
}

#--------------------------------------------------------------------------------

sub makeTestLocationAndMap {
 
  unless($realTranscriptId) {
    throw Error::Simple( "No transcript Id Set");
  }

  $testLocation = [ { na_feature_id => -1, 
                       start => 10,
                       end => 100, 
                     },
                     { na_feature_id => $realTranscriptId, 
                       start => 110, 
                       end => 199, 
                     },
                     { na_feature_id => -1, 
                       start => 250,
                       end => 4000, 
                     },
                     { na_feature_id => $realTranscriptId, 
                       start => 4050,
                       end => 4060, 
                     },
                    { na_feature_id => -1, 
                      start => 5000,
                      end => 5050, 
                    },
                   ];

  $testMap = {id => $testLocation};
}


#================================================================================
# The Tests !! 
#================================================================================

sub test__getCodingSequence {
  my ($self) = @_;

  #print STDERR "Enter Sub: test_getCodingSequence\n";

  my $shouldBeNull = $insertSnps->_getCodingSequence('', '', '', '');
  $self->assert_null($shouldBeNull);

  my $transcript = GUS::Model::DoTS::Transcript->new();

  # Test the error is thrown (ie if the transcript has no children)...
  try {
    $insertSnps->_getCodingSequence($transcript, 1, 1, '');
    throw Error::Simple( "TEST ERROR:  Should Not get here");
  } catch  GUS::PluginMgr::PluginError with { };

  my $loc1 = GUS::Model::DoTS::NALocation->new({start_min => 1, end_max => 10, is_reversed => 0});
  my $loc2 = GUS::Model::DoTS::NALocation->new({start_min => 21, end_max => 30, is_reversed => 0});

  my $exon1 = GUS::Model::DoTS::ExonFeature->new({coding_start => 3, coding_end => 8});
  my $exon2 = GUS::Model::DoTS::ExonFeature->new({coding_start => 23, coding_end => 28});

  my $rnaFeatureExon1 = GUS::Model::DoTS::RNAFeatureExon->new();
  my $rnaFeatureExon2 = GUS::Model::DoTS::RNAFeatureExon->new();

  $rnaFeatureExon1->setParent($exon1);
  $rnaFeatureExon2->setParent($exon2);

  $rnaFeatureExon1->setParent($transcript);
  $rnaFeatureExon2->setParent($transcript);

  $exon1->{'sequence'} = 'ABCDEFGHIJ';
  $exon2->{'sequence'} = 'ABCDEFGHIJ';

  #$exon1->setParent($transcript);
  #$exon2->setParent($transcript);

  $loc1->setParent($exon1);
  $loc2->setParent($exon2);

  my $codingSequence = $insertSnps->_getCodingSequence($transcript, 1, 1, '');
  $self->assert_str_equals('CDEFGHCDEFGH', $codingSequence);

  # Test coding sequence for a snp in and intron
  my $intronSnp = $insertSnps->_getCodingSequence($transcript, 2, 2, '*');
  $self->assert_str_equals('CDEFGHCDEFGH', $intronSnp);

  # Test swap position on the ends of a sequence chunk
  my $endCds = $insertSnps->_getCodingSequence($transcript, 3, 3, '*');
  $self->assert_str_equals('*DEFGHCDEFGH', $endCds);

  my $otherEndCds = $insertSnps->_getCodingSequence($transcript, 8, 8, '*');
  $self->assert_str_equals('CDEFG*CDEFGH', $otherEndCds);

  # Test swapping more than one base
  my $multiple = $insertSnps->_getCodingSequence($transcript, 5, 8, '****');
  $self->assert_str_equals('CD****CDEFGH', $multiple);

  # Test overlapping Cds with intron... Should ignore the snp (ie treat as noncoding)
  my $overlapping = $insertSnps->_getCodingSequence($transcript, 5, 9, '*****');
  $self->assert_str_equals('CDEFGHCDEFGH', $overlapping);
}

#--------------------------------------------------------------------------------

sub test_getTranscript {
  my ($self) = @_;

  #print STDERR "Enter Sub: test_getTranscript\n";

  $insertSnps->{'transcriptExtDbRlsId'} = 21;
  $insertSnps->{'naExtDbRlsId'} = 21;

  my $naSeqToLocations = $insertSnps->getAllTranscriptLocations();
  # Test that it returns undef correctly
  my $nullTranscript = $insertSnps->getTranscript('id', 5, 5, $testMap);
  $self->assert_null($nullTranscript);

  # Test That it fails correctly
  try {
    my $shouldFail = $insertSnps->getTranscript('id', 11, 11, $testMap);
    throw Error::Simple( "TEST ERROR:  Should Not get here");
  } catch GUS::PluginMgr::PluginError with { };

  try {
    my $shouldFail = $insertSnps->getTranscript('id', 5010, 5010, $testMap);
    throw Error::Simple( "TEST ERROR:  Should Not get here");
  } catch GUS::PluginMgr::PluginError with { };

  # Test the edge guys
  my $frontEdge = $insertSnps->getTranscript('id', 110, 110, $testMap);
  my $frontEdgeId = $frontEdge->getId();
  $self->assert_num_equals($realTranscriptId, $frontEdgeId);

  my $backEdge = $insertSnps->getTranscript('id', 199, 199, $testMap);
  my $backEdgeId = $backEdge->getId();
  $self->assert_num_equals($realTranscriptId, $backEdgeId);

  # Test that given a real chrom and an naSeqId and snpPosition it retrieves the correct transcript

  my $naSeqId = $naSequenceIds{MAL4};
  my $location = 810102;

  my $transcript = $insertSnps->getTranscript($naSeqId, $location, $location, $naSeqToLocations);
  my $sourceId = $transcript->getSourceId();
  $self->assert_equals('PFD0872w-1',  $sourceId);

}

#--------------------------------------------------------------------------------

sub test_getAllTranscriptLocations {
  my ($self) = @_;

#  #print STDERR "Enter Sub: test_getAllTranscriptLocations\n";

  $insertSnps->{'transcriptExtDbRlsId'} = 21;
  $insertSnps->{'naExtDbRlsId'} = 21;

  my $naSeqToLocations = $insertSnps->getAllTranscriptLocations();

  foreach my $naseq (keys %$naSeqToLocations) {
    my @transcripts = @{$naSeqToLocations->{$naseq}};
    my $end = -1;

    foreach my $transcript (@transcripts) {
      $self->assert($end < $transcript->{end});
      $end = $transcript->{end};
    }
  }
}

#--------------------------------------------------------------------------------

sub test_getCodingSubstitutionPositions {
  my ($self) = @_;

  #print STDERR "Enter Sub: test_getCodingSubstitutionPositions\n";

  my $cds = 'ABCDEFGH';
  my $mockCds = 'ABCDE*GH';

  my ($start, $end) = $insertSnps->getCodingSubstitutionPositions($cds, $mockCds);
  $self->assert_num_equals(6, $start);
  $self->assert_num_equals(6, $end);

  # Test ends
  my $frontCds = '*BCDEFGH';  
  my ($frontStart, $frontEnd) = $insertSnps->getCodingSubstitutionPositions($cds, $frontCds);
  $self->assert_num_equals(1, $frontStart);
  $self->assert_num_equals(1, $frontEnd);

  my $endCds = 'ABCDEFG*';  
  my ($endStart, $endEnd) = $insertSnps->getCodingSubstitutionPositions($cds, $endCds);
  $self->assert_num_equals(8, $endStart);
  $self->assert_num_equals(8, $endEnd);

  # Test Multiple
  my $multiple = 'A***EFGH';
  my ($multipleStart, $multipleEnd) = $insertSnps->getCodingSubstitutionPositions($cds, $multiple);
  $self->assert_num_equals(2, $multipleStart);
  $self->assert_num_equals(4, $multipleEnd);
}

#--------------------------------------------------------------------------------

sub test__swapBaseInSequence {
  my ($self) = @_;

  #print STDERR "Enter Sub: test_swapBaseInSequence\n";

  my $string = 'ABCDEFGH';

  my $start = 1;
  my $end = length($string);

  my $pos = 2;
  my $snp = '*';

  # Test easy snp change
  my $new = $insertSnps->_swapBaseInSequence($string, $start, $end, $pos, $pos, $snp, 0);
  $self->assert_str_equals('A*CDEFGH', $new);

  # Test isReversed
  my $reversed = $insertSnps->_swapBaseInSequence($string, $end, $start, $pos, $pos, $snp, 1);
  $self->assert_str_equals('A*CDEFGH', $new);

  # Test Ends
  my $frontPos = 1;
  my $front = $insertSnps->_swapBaseInSequence($string, $start, $end, $frontPos, $frontPos, $snp, 0);
  $self->assert_str_equals('*BCDEFGH', $front);

  my $backPos = 8;
  my $back = $insertSnps->_swapBaseInSequence($string, $start, $end, $backPos, $backPos, $snp, 0);
  $self->assert_str_equals('ABCDEFG*', $back);

  # Test Multiple Swaps
  my $mSnp = '***';
  my $mSnpEnd = 4;
  my $multiple = $insertSnps->_swapBaseInSequence($string, $start, $end, $pos, $mSnpEnd, $mSnp, 0);
  $self->assert_str_equals('A***EFGH', $multiple);

  # Test Multiple Reverse Swaps
  my $mSnp = '***';
  my $multiple = $insertSnps->_swapBaseInSequence($string, $start, $end, $pos, $mSnpEnd, $mSnp, 1);
  $self->assert_str_equals('ABCD***H', $multiple);

  # Test Insertion (An insertion will still swap the sequence contained by the snp start && snp end
  # ie. 'B' will be replaced with '*B*'
  my $insertionSnp = '*b*';
  my $insertion = $insertSnps->_swapBaseInSequence($string, $start, $end, $pos, $pos, $insertionSnp, 0);
  $self->assert_str_equals('A*b*CDEFGH', $insertion);
}

#--------------------------------------------------------------------------------

sub test__isSnpPositionOk {
  my ($self) = @_;

  #print STDERR "Enter Sub: test_isSnpPositionOk\n";

  $insertSnps->{'naExtDbRlsId'} = $insertSnps->getExtDbRlsId($insertSnps->getArg('naExternalDatabaseName'),$insertSnps->getArg('naExternalDatabaseVersion'));

  my $naSeq = $insertSnps->getNaSeq('MAL4');
  my $snpLocation = GUS::Model::DoTS::NALocation->new({start_min => 6, end_max => 6, is_reversed => 0});

  # MAL4 Postion 6-10 should be a TAAAC

  my $isOk = $insertSnps->_isSnpPositionOk($naSeq, 'T', $snpLocation,);
  $self->assert($isOk);

  try {
    my $isNotOk = $insertSnps->_isSnpPositionOk($naSeq, '*', $snpLocation);
    throw Error::Simple( "TEST ERROR:  Should Not get here");
  } catch GUS::PluginMgr::PluginUserError with { };

  try {
    # Test the reverse strand
    my $reverse = $insertSnps->_isSnpPositionOk($naSeq, 'A', $snpLocation);
    throw Error::Simple( "TEST ERROR:  Should Not get here");
  } catch GUS::PluginMgr::PluginUserError with { };

  # Test a multiple base snp
  $snpLocation->setEndMax(10);
  my $multiple = $insertSnps->_isSnpPositionOk($naSeq, 'TAAAC', $snpLocation);
  $self->assert($multiple);

  try {
    my $reverseMultiple = $insertSnps->_isSnpPositionOk($naSeq, 'GTTTA', $snpLocation);
    throw Error::Simple( "TEST ERROR:  Should Not get here");
  } catch GUS::PluginMgr::PluginUserError with { };
}

#--------------------------------------------------------------------------------

sub test__getAminoAcidSequenceOfSnp {
  my ($self) = @_;

  #print STDERR "Enter Sub: test_getAminoAcidSequenceOfSnp\n";

  my $codingSequence = "ATGAGAAAATTATACTGCGTATTATTATTGAGCGCCTTTGAGTTTACATATATGATAAAC";
  my $aminoAcidSequence = "MRKLYCVLLLSAFEFTYMIN";

  my $testSeq = $insertSnps->_getAminoAcidSequenceOfSnp($codingSequence, 1, length($codingSequence));
  $self->assert_str_equals($aminoAcidSequence, $testSeq);

  my $testSnp = $insertSnps->_getAminoAcidSequenceOfSnp($codingSequence, 6, 6);
  $self->assert_str_equals('C', $testSnp);

  my $testMultiple = $insertSnps->_getAminoAcidSequenceOfSnp($codingSequence, 6, 11);
  $self->assert_str_equals('CVLLLS', $testMultiple);
}

#--------------------------------------------------------------------------------

sub test_calculateAminoAcidPosition {
  my ($self) = @_;

  #print STDERR "Enter Sub: test_calculateAminoAcidPosition\n";

  my $aaPosition;

  $aaPosition = $insertSnps->calculateAminoAcidPosition(1);
  $self->assert_num_equals(1, $aaPosition);

  $aaPosition = $insertSnps->calculateAminoAcidPosition(2);
  $self->assert_num_equals(1, $aaPosition);

  $aaPosition = $insertSnps->calculateAminoAcidPosition(3);
  $self->assert_num_equals(1, $aaPosition);

  $aaPosition = $insertSnps->calculateAminoAcidPosition(7);
  $self->assert_num_equals(3, $aaPosition);

  $aaPosition = $insertSnps->calculateAminoAcidPosition(8);
  $self->assert_num_equals(3, $aaPosition);

  $aaPosition = $insertSnps->calculateAminoAcidPosition(9);
  $self->assert_num_equals(3, $aaPosition);
}

#--------------------------------------------------------------------------------

sub test_getSeqVarSoTerm {
  my ($self) = @_;

  #print STDERR "Enter Sub: test_getSeqVarSoTerm\n";

  my $snp = $insertSnps->getSeqVarSoTerm(1, 1, 'A');
  $self->assert_str_equals('substitution', $snp);

  my $insertion = $insertSnps->getSeqVarSoTerm(1, 1, 'AA');
  $self->assert_str_equals('insertion', $insertion);

  my $deletion = $insertSnps->getSeqVarSoTerm(1, 1, '-');
  $self->assert_str_equals('deletion', $deletion);

  try {
    my $shouldFail = $insertSnps->getSeqVarSoTerm(1, 0, 'A');
    throw Error::Simple( "TEST ERROR:  Should Not get here");
  } catch GUS::PluginMgr::PluginUserError with { };

}

#--------------------------------------------------------------------------------

sub test_createMockSequence {
  my ($self) = @_;

  #print STDERR "Enter Sub: test_createMockSequence\n";

  my $mockSeq = $insertSnps->createMockSequence(1, 10);
  $self->assert_str_equals('**********', $mockSeq);

  my $another = $insertSnps->createMockSequence(10, 10);
  $self->assert_str_equals('*', $another);
}

sub test_makeSnpFeatureDescriptionFromSeqVars {
  my $self = shift;

  #print STDERR "Enter Sub: test_makeSnpFeatureDescriptionFromSeqVars\n";

  my $nonCodingSnpFeature =  GUS::Model::DoTS::SnpFeature->new({source_id => 'noncoding', 
                                                       is_coding => '0',
                                                      });

  my $codingSnpFeature =  GUS::Model::DoTS::SnpFeature->new({source_id => 'coding', 
                                                       is_coding => '1',
                                                      });


  my $seqVar1 = GUS::Model::DoTS::SeqVariation->new({strain => 's train ',
                                                     allele => 'a attg gcc ',
                                                     product => 'pro duc t',
                                                    });

  my $seqVar2 = GUS::Model::DoTS::SeqVariation->new({strain => 'strain',
                                                     allele => 'aattggcc',
                                                     product => 'product',
                                                    });

  $seqVar1->setParent($codingSnpFeature);
  $seqVar2->setParent($codingSnpFeature);

  $seqVar1->setParent($nonCodingSnpFeature);
  $seqVar2->setParent($nonCodingSnpFeature);

  my $non = $insertSnps->_makeSnpFeatureDescriptionFromSeqVars($nonCodingSnpFeature, 0);
  $self->assert_equals('"strain:aattggcc" "strain:aattggcc"', $non->getStrains);
  $self->assert_equals('"strain:ggccaatt" "strain:ggccaatt"', $non->getStrainsRevcomp);


 my $cod = $insertSnps->_makeSnpFeatureDescriptionFromSeqVars($nonCodingSnpFeature, 1);
  $self->assert_equals('"strain:aattggcc:product" "strain:aattggcc:product"', $cod->getStrains);
  $self->assert_equals('"strain:ggccaatt:product" "strain:ggccaatt:product"', $cod->getStrainsRevcomp);

}

sub test_addMajorMinorInfo {
  my $self = shift;

  #print STDERR "Enter Sub: test_addMajorMinorInfo\n";

  my $snpFeature =  GUS::Model::DoTS::SnpFeature->new({source_id => 'test_1', 
                                                                is_coding => '0',
                                                               });


  my $seqVar1 = GUS::Model::DoTS::SeqVariation->new({strain => 'strain',
                                                     allele => 'a',
                                                     product => 'a_product',
                                                    });

  my $seqVar2 = GUS::Model::DoTS::SeqVariation->new({strain => 'strain',
                                                     allele => 'a',
                                                     product => 'a_product',
                                                    });

  my $seqVar3 = GUS::Model::DoTS::SeqVariation->new({strain => 'strain',
                                                     allele => 'a',
                                                     product => 'a_product',
                                                    });

  my $seqVar4 = GUS::Model::DoTS::SeqVariation->new({strain => 'strain',
                                                     allele => 'c',
                                                     product => 'c_product',
                                                    });


  my $seqVar5 = GUS::Model::DoTS::SeqVariation->new({strain => 'strain',
                                                     allele => '',
                                                     product => 'null_product',
                                                    });

  $seqVar1->setParent($snpFeature);
  $seqVar2->setParent($snpFeature);
  $seqVar3->setParent($snpFeature);
  $seqVar4->setParent($snpFeature);
  $seqVar5->setParent($snpFeature);

  my $test = $insertSnps->_addMajorMinorInfo($snpFeature);

  $self->assert_equals('a', $test->getMajorAllele());
  $self->assert_equals(3, $test->getMajorAlleleCount());
  $self->assert_equals('a_product', $test->getMajorProduct());

  $self->assert_equals('c', $test->getMinorAllele());
  $self->assert_equals(1, $test->getMinorAlleleCount());
  $self->assert_equals('c_product', $test->getMinorProduct());


  my $snpFeature2 =  GUS::Model::DoTS::SnpFeature->new({source_id => 'test_2', 
                                                                is_coding => '0',
                                                               });


  my $seqVar2_1 = GUS::Model::DoTS::SeqVariation->new({strain => 'strain',
                                                     allele => 'a',
                                                     product => 'a_product',
                                                    });

  my $seqVar2_2 = GUS::Model::DoTS::SeqVariation->new({strain => 'strain',
                                                     allele => 'a',
                                                     product => 'a_product',
                                                    });

  $seqVar2_1->setParent($snpFeature2);
  $seqVar2_2->setParent($snpFeature2);

  try {
    $insertSnps->_addMajorMinorInfo($snpFeature2);
    $self->assert(0, "SHOULD HAVE THROWN ERROR");
  } catch GUS::PluginMgr::PluginUserError with { };

  my $snpFeature3 =  GUS::Model::DoTS::SnpFeature->new({source_id => 'test_3', 
                                                                is_coding => '0',
                                                               });


  my $seqVar3_1 = GUS::Model::DoTS::SeqVariation->new({strain => 'strain',
                                                     allele => 'a',
                                                     product => 'a_product',
                                                    });

  my $seqVar3_2 = GUS::Model::DoTS::SeqVariation->new({strain => 'strain',
                                                     allele => 'a',
                                                     product => 'a_product',
                                                    });

  my $seqVar3_3 = GUS::Model::DoTS::SeqVariation->new({strain => 'strain',
                                                     allele => 'c',
                                                     product => '',
                                                    });

  $seqVar3_1->setParent($snpFeature3);
  $seqVar3_2->setParent($snpFeature3);
  $seqVar3_3->setParent($snpFeature3);

  my $test2 = $insertSnps->_addMajorMinorInfo($snpFeature3);

  $self->assert_equals('a', $test2->getMajorAllele());
  $self->assert_equals(2, $test2->getMajorAlleleCount());
  $self->assert_equals('a_product', $test2->getMajorProduct());

  $self->assert_equals('c', $test2->getMinorAllele());
  $self->assert_equals(1, $test2->getMinorAlleleCount());
  $self->assert_null($test2->getMinorProduct());


}

1;
