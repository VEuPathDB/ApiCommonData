package ApiCommonData::Load::Util;

use strict;

use GUS::Model::DoTS::TranslatedAAFeature;
use GUS::Model::DoTS::TranslatedAASequence;

# Note: this method was previously called getNASequenceId, which was misleading
# return null if not found:  be sure to check handle that condition!!
sub getSplicedNASequenceId {
  my ($plugin, $sourceId) = @_;

  if (!$plugin->{sourceIdFeatureIdMap}) {
    $plugin->{sourceIdFeatureIdMap} = {};
    my $sql = "
SELECT DISTINCT source_id, na_sequence_id
FROM Dots.SplicedNASequence
";
    my $stmt = $plugin->prepareAndExecute($sql);
    while ( my($source_id, $na_sequence_id) = $stmt->fetchrow_array()) {
      $plugin->{sourceIdFeatureIdMap}->{$source_id} = $na_sequence_id;
    }
  }
  return $plugin->{sourceIdFeatureIdMap}->{$sourceId};
}



# return null if not found:  be sure to check handle that condition!!
sub getGeneFeatureId {
  my ($plugin, $sourceId) = @_;

  if (!$plugin->{sourceIdFeatureIdMap}) {

    $plugin->{sourceIdFeatureIdMap} = {};

    my $sql = "
SELECT source_id, na_feature_id
FROM Dots.GeneFeature
UNION
SELECT g.name, gf.na_feature_id
FROM Dots.GeneFeature gf, Dots.NAFeatureNAGene nfng, Dots.NAGene g
WHERE nfng.na_feature_id = gf.na_feature_id
AND nfng.na_gene_id = g.na_gene_id
";
    my $stmt = $plugin->prepareAndExecute($sql);
    while ( my($source_id, $na_feature_id) = $stmt->fetchrow_array()) {
      $plugin->{sourceIdFeatureIdMap}->{$source_id} = $na_feature_id;
    }
  }

  return $plugin->{sourceIdFeatureIdMap}->{$sourceId};
}

# return null if not found:  be sure to check handle that condition!!
# NOTE: the provided source_id must be an AAFeature source_id, not a 
# GeneFeature source_id
sub getAAFeatureId {
  my ($plugin, $sourceId) = @_;

  if (!$plugin->{sourceIdFeatureIdMap}) {

    $plugin->{sourceIdFeatureIdMap} = {};

    my $sql = "
SELECT source_id, aa_feature_id
FROM Dots.AAFeature
";
    my $stmt = $plugin->prepareAndExecute($sql);
    while ( my($source_id, $na_feature_id) = $stmt->fetchrow_array()) {
      $plugin->{sourceIdFeatureIdMap}->{$source_id} = $na_feature_id;
    }
  }

  return $plugin->{sourceIdFeatureIdMap}->{$sourceId};
}

# return null if not found:  be sure to check handle that condition!!
# This will only return NASequences from the ExternalNASequence and
# VirtualSequence subclasses.
sub getNASequenceId {
  my ($plugin, $sourceId) = @_;

  if (!$plugin->{sourceIdFeatureIdMap}) {

    $plugin->{sourceIdFeatureIdMap} = {};

    my $sql = "
SELECT source_id, na_sequence_id
FROM Dots.ExternalNASequence
UNION
SELECT source_id, na_sequence_id
FROM Dots.VirtualSequence";
    my $stmt = $plugin->prepareAndExecute($sql);
    while ( my($source_id, $na_sequence_id) = $stmt->fetchrow_array()) {
      $plugin->{sourceIdFeatureIdMap}->{$source_id} = $na_sequence_id;
    }
  }

  return $plugin->{sourceIdFeatureIdMap}->{$sourceId};
}

# return null if not found:  be sure to check handle that condition!!
sub getAASequenceId {
  my ($plugin, $sourceId) = @_;

  if (!$plugin->{sourceIdFeatureIdMap}) {

    $plugin->{sourceIdFeatureIdMap} = {};

    my $sql = "
SELECT source_id, aa_sequence_id
FROM Dots.AASequence
";
    my $stmt = $plugin->prepareAndExecute($sql);
    while ( my($source_id, $aa_sequence_id) = $stmt->fetchrow_array()) {
      $plugin->{sourceIdFeatureIdMap}->{$source_id} = $aa_sequence_id;
    }
  }

  return $plugin->{sourceIdFeatureIdMap}->{$sourceId};
}

sub getAASeqIdFromFeatId {
  my ($featId) = shift;

  my $gusTAAF = GUS::Model::DoTS::TranslatedAAFeature->new( { 'na_feature_id' => $featId, } );

  $gusTAAF->retrieveFromDB()
    or die "no translated aa sequence: $featId";

  my $gusAASeq = $gusTAAF->getAaSequenceId();

  return $gusAASeq;
}


# get an aa seq id from a source_id or source_id alias.
sub getAASeqIdFromGeneId {
  my ($plugin, $geneId) = @_;

  my $geneFeatId = getGeneFeatureId($plugin, $geneId);

  return undef unless $geneFeatId;

    my $sql = "
SELECT taf.aa_sequence_id
FROM Dots.Transcript t, Dots.TranslatedAAFeature taf
WHERE t.parent_id = '$geneFeatId'
AND taf.na_feature_id = t.na_feature_id
";
  my $stmt = $plugin->prepareAndExecute($sql);
  my ($aaSeqId) = $stmt->fetchrow_array();
  my ($tooMany) = $stmt->fetchrow_array();
  $plugin->error("trying to map gene source id '$geneId' to a single aa_sequence_id, but found more than one aa_sequence_id: ") if $tooMany;
  return $aaSeqId;
}

sub getTranslatedAAFeatureIdFromGeneSourceId {
    my ($plugin, $sourceId) = @_;

    my $geneFeatId = getGeneFeatureId($plugin, $sourceId);
    my $sql = "
SELECT taf.aa_feature_id
FROM Dots.Transcript t, Dots.TranslatedAAFeature taf
WHERE t.parent_id = '$geneFeatId'
AND taf.na_feature_id = t.na_feature_id
";
    my $stmt = $plugin->prepareAndExecute($sql);
    my ($aaFeatId) = $stmt->fetchrow_array();
    my ($tooMany) = $stmt->fetchrow_array();
    $plugin->error("trying to map gene source id '$sourceId' to a single aa_sequence_id, but found more than one aa_sequence_id: ") if $tooMany;
    return $aaFeatId;
}

# returns null if not found
sub getTranscriptSequenceIdFromGeneSourceId {
    my ($plugin, $sourceId) = @_;

    my $geneFeatId = getGeneFeatureId($plugin, $sourceId);

    return undef unless $geneFeatId;
    my $sql = "
SELECT t.na_sequence_id
FROM Dots.Transcript t
WHERE t.parent_id = $geneFeatId
";
    my $stmt = $plugin->prepareAndExecute($sql);
    my $transcriptCount = 0;
    my ($na_sequence_id) = $stmt->fetchrow_array();
    my ($toomany) = $stmt->fetchrow_array();

    $plugin->error("trying to map gene source id '$sourceId' to a single aa_feature_id, but found more than one aa_feature_id") if $toomany;
    return $na_sequence_id;
}

sub getGeneFeatureIdFromSourceId {
  my $sourceId = shift;

  my $gusGF = GUS::Model::DoTS::GeneFeature->new( { 'source_id' => $sourceId, } );

  $gusGF->retrieveFromDB() ||
    die "can't find gene feature for source_id: $sourceId";

  return $gusGF->getId();
}

sub getCodingSequenceFromExons {
  my ($gusExons) = @_;

  die "No Exons found" unless(scalar(@$gusExons) > 0);

  foreach (@$gusExons) {
    die "Expected DoTS Exon... found " . ref($_)
      unless(UNIVERSAL::isa($_, 'GUS::Model::DoTS::ExonFeature'));
  }

  # this code gets the feature locations of the exons and puts them in order
  my @exons = map { $_->[0] }
    sort { $a->[3] ? $b->[1] <=> $a->[1] : $a->[1] <=> $b->[1] }
      map { [ $_, $_->getFeatureLocation ]}
	@$gusExons;

  my $codingSequence;

  for my $exon (@exons) {
    my $chunk = $exon->getFeatureSequence();

    my ($exonStart, $exonEnd, $exonIsReversed) = $exon->getFeatureLocation();

    my $codingStart = $exon->getCodingStart();
    my $codingEnd = $exon->getCodingEnd();

    next unless ($codingStart && $codingEnd);

    my $trim5 = $exonIsReversed ? $exonEnd - $codingStart : $codingStart - $exonStart;
    substr($chunk, 0, $trim5, "") if $trim5 > 0;

    my $trim3 = $exonIsReversed ? $codingEnd - $exonStart : $exonEnd - $codingEnd;
    substr($chunk, -$trim3, $trim3, "") if $trim3 > 0;

    $codingSequence .= $chunk;
  }

  return($codingSequence);
}



1;


