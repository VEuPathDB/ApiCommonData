package ApiCommonData::Load::Util;

use strict;

use GUS::Model::DoTS::TranslatedAAFeature;
use GUS::Model::DoTS::TranslatedAASequence;

# Note: this method was previously called getNASequenceId, which was misleading
# return null if not found:  be sure to check handle that condition!!
sub getSplicedNASequenceId {
  my ($plugin, $sourceId) = @_;

  if (!$plugin->{_sourceIdSplicedNASeqIdMap}) {
    $plugin->{_sourceIdSplicedNASeqIdMap} = {};
    my $sql = "
SELECT DISTINCT source_id, na_sequence_id
FROM Dots.SplicedNASequence
";
    my $stmt = $plugin->prepareAndExecute($sql);
    while ( my($source_id, $na_sequence_id) = $stmt->fetchrow_array()) {
      $plugin->{_sourceIdSplicedNASeqIdMap}->{$source_id} = $na_sequence_id;
    }
  }
  return $plugin->{_sourceIdSplicedNASeqIdMap}->{$sourceId};
}



# return null if not found:  be sure to check handle that condition!!
sub getGeneFeatureId {
  my ($plugin, $sourceId, $geneExtDbRlsId) = @_;

  if (!$plugin->{_sourceIdGeneFeatureIdMap}) {

    $plugin->{_sourceIdGeneFeatureIdMap} = {};

    my $sql_preferred = "
SELECT source_id, na_feature_id
FROM Dots.GeneFeature
";

    my $sql = "
select dbref.primary_identifier, gf.na_feature_id
from   SRes.DBRef DBRef, DoTS.GeneFeature gf, DoTS.DBRefNaFeature naf, SRes.externaldatabaserelease edr
where  edr.external_database_release_id = dbref.external_database_release_id
and    dbref.db_ref_id = naf.db_ref_id
and    naf.na_feature_id = gf.na_feature_id
and    edr.id_is_alias = 1 
";



    if($geneExtDbRlsId){

    $sql_preferred = "
SELECT source_id, na_feature_id
FROM Dots.GeneFeature
where external_database_release_id in ($geneExtDbRlsId)
";

    $sql = "
select dbref.primary_identifier, gf.na_feature_id
from   SRes.DBRef DBRef, dots.GeneFeature gf,DoTS.DBRefNaFeature naf, sres.externaldatabaserelease edr
where  edr.external_database_release_id = dbref.external_database_release_id
and    dbref.db_ref_id = naf.db_ref_id
and    naf.na_feature_id = gf.na_feature_id
and    edr.id_is_alias = 1 
and    gf.external_database_release_id in  ($geneExtDbRlsId)
";

    }
 
    my %nonUniqueIds;
    
    my $stmt = $plugin->prepareAndExecute($sql);
    while ( my($source_id, $na_feature_id) = $stmt->fetchrow_array()) {
      if (exists ($plugin->{_sourceIdGeneFeatureIdMap}->{$source_id})) {
         $nonUniqueIds{$source_id} = $na_feature_id;
         delete $plugin->{_sourceIdGeneFeatureIdMap}->{$source_id};
      }
      if (not exists $nonUniqueIds{$source_id}) {
        $plugin->{_sourceIdGeneFeatureIdMap}->{$source_id} = $na_feature_id;
      }
    }
    $stmt->finish();

    my $prefStmt = $plugin->prepareAndExecute($sql_preferred);
    while ( my($source_id, $na_feature_id) = $prefStmt->fetchrow_array()) {
     if (exists ($plugin->{_sourceIdGeneFeatureIdMap}->{$source_id})) {
         $nonUniqueIds{$source_id} = $na_feature_id;
         delete $plugin->{_sourceIdGeneFeatureIdMap}->{$source_id};
      }
      if (not exists $nonUniqueIds{$source_id}) {
        $plugin->{_sourceIdGeneFeatureIdMap}->{$source_id} = $na_feature_id;
      }
    }
    $prefStmt->finish();
  }

  return $plugin->{_sourceIdGeneFeatureIdMap}->{$sourceId};
}


# return null if not found:  be sure to check handle that condition!!
sub getNaFeatureIdsFromSourceId {
  my ($plugin, $sourceId, $naFeatureView) = @_;

  if (!$plugin->{_sourceIdNaFeatureIdMap}) {

    $plugin->{_sourceIdNaFeatureIdMap} = {};

    my $sql = "select source_id, na_feature_id from dots.${naFeatureView}";

    my $stmt = $plugin->prepareAndExecute($sql);
    while ( my($source_id, $na_feature_id) = $stmt->fetchrow_array()) {
      push @{$plugin->{_sourceIdNaFeatureIdMap}->{$source_id}}, $na_feature_id;
    }
    $stmt->finish();
  }

  return $plugin->{_sourceIdNaFeatureIdMap}->{$sourceId};
}


# return null if not found:  be sure to check handle that condition!!
# NOTE: the provided source_id must be an AAFeature source_id, not a 
# GeneFeature source_id
sub getAAFeatureId {
  my ($plugin, $sourceId) = @_;

  if (!$plugin->{_sourceIdAaFeatureIdMap}) {

    $plugin->{_sourceIdAaFeatureIdMap} = {};

    my $sql = "
SELECT source_id, aa_feature_id
FROM Dots.AAFeature
";
    my $stmt = $plugin->prepareAndExecute($sql);
    while ( my($source_id, $na_feature_id) = $stmt->fetchrow_array()) {
      $plugin->{_sourceIdAaFeatureIdMap}->{$source_id} = $na_feature_id;
    }
  }

  return $plugin->{_sourceIdAaFeatureIdMap}->{$sourceId};
}

# return null if not found:  be sure to check handle that condition!!
# This will only return NASequences from the ExternalNASequence and
# VirtualSequence subclasses.
sub getNASequenceId {
  my ($plugin, $sourceId) = @_;

  if (!$plugin->{_sourceIdNASequenceIdMap}) {

    $plugin->{_sourceIdNASequenceIdMap} = {};

    my $sql = "
SELECT source_id, na_sequence_id
FROM Dots.ExternalNASequence
UNION
SELECT source_id, na_sequence_id
FROM Dots.VirtualSequence";
    my $stmt = $plugin->prepareAndExecute($sql);
    while ( my($source_id, $na_sequence_id) = $stmt->fetchrow_array()) {
      $plugin->{_sourceIdNASequenceIdMap}->{$source_id} = $na_sequence_id;
    }
  }

  return $plugin->{_sourceIdNASequenceIdMap}->{$sourceId};
}

# return null if not found:  be sure to check handle that condition!!
sub getAASequenceId {
  my ($plugin, $sourceId) = @_;

  if (!$plugin->{_sourceIdAaSequenceIdMap}) {

    $plugin->{_sourceIdAaSequenceIdMap} = {};

    my $sql = "
SELECT source_id, aa_sequence_id
FROM Dots.AASequence
";
    my $stmt = $plugin->prepareAndExecute($sql);
    while ( my($source_id, $aa_sequence_id) = $stmt->fetchrow_array()) {
      $plugin->{_sourceIdAaSequenceIdMap}->{$source_id} = $aa_sequence_id;
    }
  }

  return $plugin->{_sourceIdAaSequenceIdMap}->{$sourceId};
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
# warning: this method issues a query each time it is called, ie, it is
#          slow when used repeatedly.  should be rewritten to do a batch
sub getAASeqIdFromGeneId {
  my ($plugin, $geneSourceId, $geneExtDbRlsId, $optionalOrganismAbbrev) = @_;
  
  my $geneFeatId;
  if($optionalOrganismAbbrev){ 
      $geneFeatId = getGeneFeatureId($plugin, $geneSourceId, $geneExtDbRlsId,$optionalOrganismAbbrev);
  }else{
       $geneFeatId = getGeneFeatureId($plugin, $geneSourceId, $geneExtDbRlsId);
  }



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
  $plugin->error("trying to map gene source id '$geneSourceId' to a single aa_sequence_id, but found more than one aa_sequence_id: ") if $tooMany;
  return $aaSeqId;
}

# get an aa seq id from a source_id or source_id alias.
# only gets one protein per source_id (arbitrarily chosen)
sub getOneAASeqIdFromGeneId {
  my ($plugin, $geneSourceId) = @_;


  if (!$plugin->{_sourceIdOneAaSeqIdMap}) {

    $plugin->{_sourceIdOneAaSeqIdMap} = {};

my $sql ="
SELECT srcIdNaFeatId.source_id, taf.aa_sequence_id
FROM Dots.Transcript t, Dots.TranslatedAAFeature taf,
   (
     SELECT source_id, na_feature_id
     FROM Dots.GeneFeature
     UNION
     SELECT g.name, gf.na_feature_id
     FROM Dots.GeneFeature gf, Dots.NAFeatureNAGene nfng, Dots.NAGene g
     WHERE nfng.na_feature_id = gf.na_feature_id
     AND nfng.na_gene_id = g.na_gene_id
   ) srcIdNaFeatId
WHERE t.parent_id = srcIdNaFeatId.na_feature_id
AND taf.na_feature_id = t.na_feature_id
";
    my $stmt = $plugin->prepareAndExecute($sql);
    while ( my($source_id, $aa_sequence_id) = $stmt->fetchrow_array()) {
      $plugin->{_sourceIdOneAaSeqIdMap}->{$source_id} = $aa_sequence_id;
    }
  }

  return $plugin->{_sourceIdOneAaSeqIdMap}->{$geneSourceId};
}

# warning: this method issues a query each time it is called, ie, it is
#          slow when used repeatedly.  should be rewritten to do a batch
sub getTranslatedAAFeatureIdFromGeneSourceId {
    my ($plugin, $sourceId, $geneExtDbRlsId, $optionalOrganismAbbrev) = @_;

    my $geneFeatId;
      if($optionalOrganismAbbrev){  
	  $geneFeatId = getGeneFeatureId($plugin, $sourceId, $geneExtDbRlsId,$optionalOrganismAbbrev);
      }else{
	  $geneFeatId = getGeneFeatureId($plugin, $sourceId);
      }

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
# warning: this method issues a query each time it is called, ie, it is
#          slow when used repeatedly.  should be rewritten to do a batch
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

sub getExtDbRlsVerFromExtDbRlsName {
  my ($plugin, $extDbRlsName) = @_;

  my $sql = "select version from sres.externaldatabaserelease edr, sres.externaldatabase ed
             where ed.name = '$extDbRlsName'
             and edr.external_database_id = ed.external_database_id";

  my $stmt = $plugin->prepareAndExecute($sql);
  
  my @verArray;

  while ( my($version) = $stmt->fetchrow_array()) {
      push @verArray, $version;
  }
  $stmt->finish();

  die "No ExtDbRlsVer found for '$extDbRlsName'" unless(scalar(@verArray) > 0);

  die "trying to find unique ext db version for '$extDbRlsName', but more than one found" if(scalar(@verArray) > 1);

  return @verArray[0];

}


1;

