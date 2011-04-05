package ApiCommonData::Load::Plugin::Test::TestInsertSyntenySpans;
use base qw(GUS::PluginMgr::PluginTestCase);

use strict;

use Error qw(:try);

use ApiCommonData::Load::Plugin::InsertSyntenySpans;

use GUS::PluginMgr::PluginError;

use GUS::Model::ApiDB::Synteny;

use Data::Dumper;

my ($insertSyntenySpans, $negInf, $inf);

#--------------------------------------------------------------------------------

sub set_up {
  my ($self) = @_;

  my $args = {inputFile => "$ENV{GUS_HOME}/lib/perl/ApiCommonData/Load/Plugin/Test/vivax-synteny",
              seqTableA => 'DoTS.ExternalNASequence',
              seqTableB => 'DoTS.ExternalNASequence',
              extDbRlsSpecA => 'Sanger P. falciparum chromosomes|2007-06-28',
              extDbRlsSpecB => 'Jane Carlton P. vivax chromosomes|2005-09-01',
              syntenyDbRlsSpec => 'vivax-falciparum synteny from Mercator|2007-09-28',
             };

  $self->SUPER::set_up('ApiCommonData::Load::Plugin::InsertSyntenySpans', $args);

  $negInf = -9999999999;
  $inf = 9999999999;

  $insertSyntenySpans = $self->getPlugin();
}

#--------------------------------------------------------------------------------

sub test_getNaSequenceId {
  my $self = shift;

  my $seqTable = $insertSyntenySpans->getArg('seqTableA');
  my $extDbRls = $insertSyntenySpans->getExtDbRlsId($insertSyntenySpans->getArg('extDbRlsSpecA'));

  my $id = $insertSyntenySpans->getNaSequenceId('MAL1', $extDbRls, $seqTable);

  $self->assert(qr/\d+/, $id);

  try {
    $insertSyntenySpans->getNaSequenceId('MALL1', $extDbRls, $seqTable);
    $self->assert(0);
  } catch GUS::PluginMgr::PluginError with {};
}

#--------------------------------------------------------------------------------

sub test_makeSynteny {
  my $self = shift;

  my $seqTable = 'DoTS.ExternalNASequence';
  my $extDbRls = $insertSyntenySpans->getExtDbRlsId($insertSyntenySpans->getArg('extDbRlsSpecA'));
  my $id1 = $insertSyntenySpans->getNaSequenceId('MAL1', $extDbRls, $seqTable);
  my $id2 = $insertSyntenySpans->getNaSequenceId('MAL2', $extDbRls, $seqTable);

  my $synteny = $insertSyntenySpans->makeSynteny($id1, $id2, 3, 4, 5, 6, 1, $extDbRls);

  $self->assert_equals('GUS::Model::ApiDB::Synteny', ref($synteny));

  $self->assert_equals($id1, $synteny->getANaSequenceId);
  $self->assert_equals($id2, $synteny->getBNaSequenceId);
  $self->assert_equals(3, $synteny->getAStart);
  $self->assert_equals(4, $synteny->getBStart);
  $self->assert_equals(5, $synteny->getAEnd);
  $self->assert_equals(6, $synteny->getBEnd);
  $self->assert_equals(1, $synteny->getIsReversed);
  $self->assert_equals($extDbRls, $synteny->getExternalDatabaseReleaseId);
}

#--------------------------------------------------------------------------------

sub test_handleSyntenySpan {
  my $self = shift;

  my $line = "MAL13   ctg_7202        111895  790019  115060  856803  +";
  my $lineRev = "MAL13   ctg_7202        111895  790019  115060  856803  -";

  my $extDbRlsIdA = $insertSyntenySpans->getExtDbRlsId($insertSyntenySpans->getArg('extDbRlsSpecA'));
  my $extDbRlsIdB = $insertSyntenySpans->getExtDbRlsId($insertSyntenySpans->getArg('extDbRlsSpecB'));
  my $synDbRlsId = $insertSyntenySpans->getExtDbRlsId($insertSyntenySpans->getArg('syntenyDbRlsSpec'));

  my $seqTable = 'DoTS.ExternalNASequence';
  my $ida = $insertSyntenySpans->getNaSequenceId('MAL13', $extDbRlsIdA, $seqTable);
  my $idb = $insertSyntenySpans->getNaSequenceId('ctg_7202', $extDbRlsIdB, $seqTable);

  my ($synteny0, $synteny1) = $insertSyntenySpans->_handleSyntenySpan($line, $extDbRlsIdA, $extDbRlsIdB, $synDbRlsId);

  $self->assert_equals($ida, $synteny0->getANaSequenceId());
  $self->assert_equals($idb, $synteny0->getBNaSequenceId());
  $self->assert_equals(111895, $synteny0->getAStart());
  $self->assert_equals(115060, $synteny0->getBStart());
  $self->assert_equals(901913, $synteny0->getAEnd());
  $self->assert_equals(971862, $synteny0->getBEnd());
  $self->assert_equals(0, $synteny0->getIsReversed());
  $self->assert_equals($synDbRlsId, $synteny0->getExternalDatabaseReleaseId());

  $self->assert_equals($ida, $synteny1->getBNaSequenceId());
  $self->assert_equals($idb, $synteny1->getANaSequenceId());
  $self->assert_equals(111895, $synteny1->getBStart());
  $self->assert_equals(115060, $synteny1->getAStart());
  $self->assert_equals(901913, $synteny1->getBEnd());
  $self->assert_equals(971862, $synteny1->getAEnd());
  $self->assert_equals(0, $synteny1->getIsReversed());
  $self->assert_equals($synDbRlsId, $synteny1->getExternalDatabaseReleaseId());


  my ($revComp0, $revComp1) = $insertSyntenySpans->_handleSyntenySpan($lineRev, $extDbRlsIdA, $extDbRlsIdB, $synDbRlsId);
  $self->assert_equals(1, $revComp0->getIsReversed());  
  $self->assert_equals(1, $revComp1->getIsReversed());  
}


#--------------------------------------------------------------------------------

sub test_findOrthologGroups {}
sub test_findGenes{}

sub test_createSyntenyAnchors {
  my $self = shift;

  my $synteny = GUS::Model::ApiDB::Synteny->new({synteny_id => -99,
                                                 is_reversed => 0,
                                                 a_start => 1,
                                                 a_end => 100,
                                                 b_start => 500,
                                                 b_end => 800,
                                                });

  my $genePairs = [{refStart => 50, refEnd => 60, synStart => 550, synEnd => 560}];

  #======================================================================

  # Simple Example:  Syntenic region one ref gene -> one syntenic gene
  my $anchors0 = $insertSyntenySpans->createSyntenyAnchors($synteny, $genePairs);
  $self->assert_equals('ARRAY', ref($anchors0));
  $self->assert_equals(4, scalar(@$anchors0));

  $self->assert(&anchorEquals({syntenic_loc => 500,
                               ref_loc => 1,
                               prev_ref_loc => $negInf,
                               next_ref_loc => 50,
                              }, $anchors0->[0]));

  $self->assert(&anchorEquals({syntenic_loc => 550,
                               ref_loc => 50,
                               prev_ref_loc => 1,
                               next_ref_loc => 60,
                              }, $anchors0->[1]));

  $self->assert(&anchorEquals({syntenic_loc => 560,
                               ref_loc => 60,
                               prev_ref_loc => 50,
                               next_ref_loc => 100,
                              }, $anchors0->[2]));

  $self->assert(&anchorEquals({syntenic_loc => 800,
                               ref_loc => 100,
                               prev_ref_loc => 60,
                               next_ref_loc => $inf,
                              }, $anchors0->[3]));

  #======================================================================

  # one ref gene -> two syntenic genes
  push(@$genePairs, {refStart => 50, refEnd => 60, synStart => 650, synEnd => 660});

  my $anchors1 = $insertSyntenySpans->createSyntenyAnchors($synteny, $genePairs);
  $self->assert_equals('ARRAY', ref($anchors1));
  $self->assert_equals(6, scalar(@$anchors1));

  $self->assert(&anchorEquals({syntenic_loc => 500,
                               prev_ref_loc => $negInf,
                               ref_loc => 1,
                               next_ref_loc => 50,
                              }, $anchors1->[0]));

  $self->assert(&anchorEquals({syntenic_loc => 550,
                               prev_ref_loc => 1,
                               ref_loc => 50,
                               next_ref_loc => $negInf,
                              }, $anchors1->[1]));

  $self->assert(&anchorEquals({syntenic_loc => 560,
                               prev_ref_loc => 50,
                               ref_loc => 60,
                               next_ref_loc => $negInf,
                              }, $anchors1->[2]));

  $self->assert(&anchorEquals({syntenic_loc => 650,
                               prev_ref_loc => $inf,
                               ref_loc => 50,
                               next_ref_loc => 60,
                              }, $anchors1->[3]));

  $self->assert(&anchorEquals({syntenic_loc => 660,
                               prev_ref_loc => $inf,
                               ref_loc => 60,
                               next_ref_loc => 100,
                              }, $anchors1->[4]));

  $self->assert(&anchorEquals({syntenic_loc => 800,
                               prev_ref_loc => 60,
                               ref_loc => 100,
                               next_ref_loc => $inf,
                              }, $anchors1->[5]));

  #======================================================================

  # one ref gene -> two syntenic genes
  push(@$genePairs, {refStart => 50, refEnd => 60, synStart => 750, synEnd => 760});

  my $anchors2 = $insertSyntenySpans->createSyntenyAnchors($synteny, $genePairs);
  $self->assert_equals('ARRAY', ref($anchors2));
  $self->assert_equals(8, scalar(@$anchors2));

  $self->assert(&anchorEquals({syntenic_loc => 500,
                               prev_ref_loc => $negInf,
                               ref_loc => 1,
                               next_ref_loc => 50,
                              }, $anchors2->[0]));

  $self->assert(&anchorEquals({syntenic_loc => 550,
                               prev_ref_loc => 1,
                               ref_loc => 50,
                               next_ref_loc => $negInf,
                              }, $anchors2->[1]));

  $self->assert(&anchorEquals({syntenic_loc => 560,
                               prev_ref_loc => 50,
                               ref_loc => 60,
                               next_ref_loc => $negInf,
                              }, $anchors2->[2]));

  $self->assert(&anchorEquals({syntenic_loc => 650,
                               prev_ref_loc => $inf,
                               ref_loc => 50,
                               next_ref_loc => $negInf,
                              }, $anchors2->[3]));

  $self->assert(&anchorEquals({syntenic_loc => 660,
                               prev_ref_loc => $inf,
                               ref_loc => 60,
                               next_ref_loc => $negInf,
                              }, $anchors2->[4]));

  $self->assert(&anchorEquals({syntenic_loc => 750,
                               prev_ref_loc => $inf,
                               ref_loc => 50,
                               next_ref_loc => 60,
                              }, $anchors2->[5]));

  $self->assert(&anchorEquals({syntenic_loc => 760,
                               prev_ref_loc => $inf,
                               ref_loc => 60,
                               next_ref_loc => 100,
                              }, $anchors2->[6]));

  $self->assert(&anchorEquals({syntenic_loc => 800,
                               prev_ref_loc => 60,
                               ref_loc => 100,
                               next_ref_loc => $inf,
                              }, $anchors2->[7]));
}

sub anchorEquals {
  my ($expected, $actual) = @_;

  if($expected->{prev_ref_loc} == $actual->{prev_ref_loc} &&
     $expected->{ref_loc} == $actual->{ref_loc} &&
     $expected->{next_ref_loc} == $actual->{next_ref_loc} &&
     $expected->{syntenic_loc} == $actual->{syntenic_loc}) {
    return 1;
  }

  print STDERR "\n\n";

  print STDERR "expected:  " .Dumper($expected);
  print STDERR "actual:  " .Dumper($actual);

  return 0;
}


1;
