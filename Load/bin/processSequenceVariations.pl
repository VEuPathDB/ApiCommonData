#!/usr/bin/perl

use strict;

use File::Basename;
use Data::Dumper;

use GUS::Model::DoTS::Transcript;

use Getopt::Long;
use GUS::ObjRelP::DbiDatabase;
use GUS::Supported::GusConfig;

use Bio::Tools::GFF;
use Bio::Seq;
use CBIL::Bio::SequenceUtils;

use DBI;
use DBD::Oracle;

use ApiCommonData::Load::MergeSortedFiles;

my ($newSampleFile, $cacheFile, $transcriptExtDbRlsSpec, $organismAbbrev, $undoneStrainsFile, $gusConfigFile, $varscanDirectory, $referenceStrain);

&GetOptions("new_sample_file=s"=> \$newSampleFile,
            "cache_file=s"=> \$cacheFile,
            "gusConfigFile|gc=s"=> \$gusConfigFile,
            "transcript_extdb_spec=s" => \$transcriptExtDbRlsSpec,
            "organism_abbrev=s" =>\$organismAbbrev,
            "undone_strains_file=s" => \$undoneStrainsFile,
            "varscan_directory=s" => \$varscanDirectory,
            "reference_strain=s" => \$referenceStrain,
    );

unless(-e $gusConfigFile) {
  $gusConfigFile = $ENV{GUS_HOME} . "/config/gus.config";
}

my $gusConfig = GUS::Supported::GusConfig->new($gusConfigFile);

my $db = GUS::ObjRelP::DbiDatabase->new($gusConfig->getDbiDsn(),
                                         $gusConfig->getDatabaseLogin(),
                                         $gusConfig->getDatabasePassword(),
                                         0, 0, 1,
                                         $gusConfig->getCoreSchemaName()
                                        );

my $dbh = $db->getQueryHandle();

my $dirname = dirname($cacheFile);

my $tempOutputFile = $dirname . "/cache.tmp";

open(OUT, "> $tempOutputFile") or die "Cannot open file $tempOutputFile for writing: $!";

my $strainVarscanFileHandles = &openVarscanFiles($varscanDirectory);

my @allStrains = keys %{$strainVarscanFileHandles};

my $strainExtDbRlsIds = &queryExtDbRlsIdsForStrains(\@allStrains, $dbh, $organismAbbrev);
my $transcriptExtDbRlsId = &queryExtDbRlsIdFromSpec($dbh, $transcriptExtDbRlsSpec);

my ($transcriptLocs, $exonLocs) = &getTranscriptLocations($dbh, $transcriptExtDbRlsId);

open(UNDONE, $undoneStrainsFile) or die "Cannot open file $undoneStrainsFile for reading: $!";
my @undoneStrains =  map { chomp; $_ } <UNDONE>;
close UNDONE;

my $merger = ApiCommonData::Load::MergeSortedFiles::SeqVarCache->new($newSampleFile, $cacheFile, \@undoneStrains);

while($merger->hasNext()) {
  my $variations = $merger->nextSNP();

  # loop throught to make sure the seqid/location are same for all
  my ($sequenceId, $location) = &snpLocationFromVariations($variations);

  # some variables are needed to store attributes of the SNP
  my ($referenceAllele, $positionInCds, $product, $positionInProtein);

  my $cachedReferenceVariation = &cachedReferenceVariation($variations, $referenceStrain);
  my $transcripts = &lookupTranscripts($sequenceId, $location, $exonLocs);

  # for the refereence, get   positionInCds, positionInProtein, product, codon?
  if($cachedReferenceVariation) {
    $product = $cachedReferenceVariation->{product};
    $positionInCds = $cachedReferenceVariation->{position_in_cds};
    $positionInProtein = &calculateAminoAcidPosition($positionInCds, $positionInCds);
    $referenceAllele = $cachedReferenceVariation->{base};
  }
  else {
    $referenceAllele = &queryReferenceAllele($dbh, $sequenceId, $location);
    ($product, $positionInCds, $positionInProtein) = &processVariation($transcriptExtDbRlsId, $transcripts, $transcriptLocs, $sequenceId, $location, $referenceAllele);

    # add a variation for the reference
    push @$variations, {'base' => $referenceAllele,
                        'external_database_release_id' => $transcriptExtDbRlsId,
                        'location' => $location,
                        'sequence_source_id' => $sequenceId,
                        'matches_reference' => 1,
                        'position_in_cds' => $positionInCds,
                        'strain' => $referenceStrain,
                        'product' => $product,
    };
  }

  # Check for a variation at this point;  Important for when we undo strains
  next unless(&hasVariation($variations));

 # TODO:  loop over all strains  add coverage vars

  foreach my $variation (@$variations) {
    my $strain = $variation->{strain};

    my $extDbRlsId;
    if($strain ne $referenceStrain) {
      $extDbRlsId = $strainExtDbRlsIds->{$strain};
    }

    if(my $cachedExtDbRlsId = $variation->{external_database_release_id}) {
      die "cachedExtDbRlsId did not match" if($strain ne $referenceStrain && $extDbRlsId != $cachedExtDbRlsId);
      &printVariation($variation);
      next;
    }

    my $allele = $variation->{base};

    if($allele eq $referenceAllele) {
      $variation->{matches_reference} = 1;
    }
    else {
      $variation->{matches_reference} = 0;
    }

    if($positionInCds) {
      my $strainSequenceSourceId = $sequenceId . "." . $strain;

      my ($p, $cdsPos, $proteinPos) = &processVariation($extDbRlsId, $transcripts, $transcriptLocs, $strainSequenceSourceId, $location, $allele);
      $variation->{product} = $p;
      $variation->{position_in_cds} = $cdsPos;

    }
    else {
      $variation->{external_database_release_id} = $extDbRlsId;
    }
    &printVariation($variation);
  }

  
  # TODO write the SNP Feature from variations
}

# TODO clean transcript cache once we hit a new transcript

# TODO unlink the existing FullCache File

# TODO unlink the NewSampleCache File - Should replace w/ Empty File

# TODO Rename the OutputFile to FullCache File


&closeVarscanFiles($strainVarscanFileHandles);


sub hasVariation {
  my ($variations) = @_;

  my %alleles;
  foreach(@$variations) {
    my $base = $_->{base};
    $alleles{$base}++;
  }

  return scalar(keys(%alleles)) > 1;
}

sub querySequenceSubstring {
  my ($dbh, $sequenceId, $seqExtDbRlsId, $start, $end ) = @_;

  my $length = $end - $start + 1;

  my $sql = "select substr(s.sequence, ?, ?) as base
                      from dots.nasequence s
                     where s.source_id = ?
                     and s.external_database_release_id = ?";

  my $sh = $dbh->prepare($sql);
  $sh->execute($start, $length, $sequenceId, $seqExtDbRlsId);

  my ($base) = $sh->fetchrow_array();
  $sh->finish();

  return $base;
}

sub processVariation {
  my ($transcriptExtDbRlsId, $transcripts, $transcriptLocs, $sequenceId, $location, $base) = @_;

  my %products;
  my %positionInCdss;
  my %positionInProteins;

  foreach my $transcript (@$transcripts) {
    next if($transcriptLocs->{$transcript}->{is_non_coding}); # don't bother for non coding transcripts

    my $consensusCodingSequence = $transcriptLocs->{$transcript}->{$transcriptExtDbRlsId}->{consensus_cds};
    unless($consensusCodingSequence) {
      $consensusCodingSequence = &getCodingSequenceForTranscript($dbh, $sequenceId, $location, $location, $transcript, $transcriptLocs, $transcriptExtDbRlsId);
    }

    my $isCoding;
    if($transcriptLocs->{$transcript}->{is_coding}) {
      $isCoding = 1;
    }
    else { # first time through
      my $mockCodingSequence = &getMockSequenceForTranscript($sequenceId, $location, $location, $transcript, $transcriptLocs, $transcriptExtDbRlsId);

      my $isCoding = $consensusCodingSequence ne $mockCodingSequence;

      if($isCoding) {
        my ($codingSnpStart, $codingSnpEnd) = &getCodingSubstitutionPositions($consensusCodingSequence, $mockCodingSequence);
        unless($codingSnpStart == $codingSnpEnd) {
          die "Should be exactly one coding position for this snp";
        }
        $positionInCdss{$codingSnpStart}++;
        $transcriptLocs->{$transcript}->{position_in_cds} = $codingSnpStart;
      }
      $transcriptLocs->{$transcript}->{is_coding} = $isCoding;
      $transcriptLocs->{$transcript}->{is_non_coding} = 1 unless($isCoding);
    }
      
      if($isCoding) {
        my $posInCds = $transcriptLocs->{$transcript}->{position_in_cds};

        if($transcriptLocs->{$transcript}->{is_reversed}) {
          $base = CBIL::Bio::SequenceUtils::reverseComplementSequence($base);
        }

        my $newCodingSequence = &_swapBaseInSequence($consensusCodingSequence, 1, 1, $posInCds, $posInCds, $base, '');

        my $positionInProtein = &calculateAminoAcidPosition($posInCds, $posInCds);

        my $product = &_getAminoAcidSequenceOfSnp($newCodingSequence, $positionInProtein, $positionInProtein);
        $products{$product}++;
        $positionInProteins{$positionInProtein}++;
      }
  }

  my $rvProduct = scalar keys %products == 1 ? (keys %products)[0] : "NA";
  my $rvPositionInCds = scalar keys %positionInCdss == 1 ? (keys %positionInCdss)[0] : "NA";
  my $rvPositionInProtein = scalar keys %positionInProteins == 1 ? (keys %positionInProteins)[0] : "NA";

  return($rvProduct, $rvPositionInCds, $rvPositionInProtein);
}

sub cachedReferenceVariation {
    my ($variations, $referenceStrain) = @_;

    foreach(@$variations) {
      return $_ if($_->{strain} eq $referenceStrain);
    }
}

sub getCodingSubstitutionPositions {
  my ($codingSequence, $mockCodingSequence) = @_;

  my @cdsArray = split("", $codingSequence);
  my @mockCdsArray = split("", $mockCodingSequence);

  my @results;

  for(my $i = 0; $i < scalar(@cdsArray); $i++) {
    push(@results, ($i + 1)) if($cdsArray[$i] ne $mockCdsArray[$i] && $mockCdsArray[$i] eq '*');
  }
  my $snpStart = $results[0];
  my $snpEnd = $results[scalar(@results) - 1];

  return($snpStart, $snpEnd);
}


sub hasCachedReference {
  my ($variations) = @_;

  
}

sub snpLocationFromVariations {
  my ($variations) = @_;

  my $sequenceIdRv;
  my $locationRv;

  foreach(@$variations) {
    my $sequenceSourceId = $_->{sequence_source_id};
    my $location = $_->{location};

    die "sequenceSourceId and location required for every variation" unless($sequenceSourceId && $location);

    if(($sequenceIdRv && $sequenceIdRv ne $sequenceSourceId) || ($locationRv && $locationRv != $location)) {
      print STDER Dumper $variations;
      die "Multiple variation locations found for a snp";
    }

    $sequenceIdRv = $sequenceSourceId;
    $locationRv = $location;
  }
  return($sequenceIdRv, $locationRv);
}


sub closeVarscanFiles {
  my ($fhHash) = @_;

  foreach(keys %$fhHash) {
    close $_;
  }
}


sub queryExtDbRlsIdsForStrains {
  my ($strains, $dbh, $organismAbbrev) = @_;

  print STDERR "ORGANISM=$organismAbbrev\n\n";

  my $sql = "select d.name, d.external_database_name, d.version
from apidb.organism o, apidb.datasource d 
where o.abbrev = ?
and o.taxon_id = d.taxon_id
and d.name like ?
";

  my $sh = $dbh->prepare($sql);

  my %rv;

  foreach my $strain (@$strains) {

    my $match = "\%_${strain}_HTS_SNPSample_RSRC";
    print STDERR "MATCH=$match\n";

    $sh->execute($organismAbbrev, $match);

    my $ct;
    while(my ($name, $extDbName, $extDbVersion) = $sh->fetchrow_array()) {
      print STDERR "NAME=$name\n";
      my $spec = "$extDbName|$extDbVersion";
      my $extDbRlsId = &queryExtDbRlsIdFromSpec($dbh, $spec);

      $rv{$strain} = $extDbRlsId;
      $ct++;
    }

    $sh->finish();
    die "Expected Exactly one hts snp sample row for organism=$organismAbbrev and strain=$strain" unless $ct = 1;
  }

  return \%rv;
}


sub openVarscanFiles {
  my ($varscanDirectory) = @_;

  my %rv;

  opendir(DIR, $varscanDirectory) or die "Cannot open directory $varscanDirectory for reading: $!";

  while(my $file = readdir(DIR)) {
    my $fh;
    my $fullPath = $varscanDirectory . "/$file";

    if($file =~ /(.+)\.varscan.cons/) {
      my $strain = $1;

      if($file =~ /\.gz$/) {
        open($fh, "zcat $fullPath |") || die "unable to open file $fullPath";
      } 
      else {
       open($fh, $fullPath) || die "unable to open file $fullPath"; 
      }

      $rv{$strain} = $fh;
    }
  }
  return \%rv;
}

sub cleanCdsCache {
  my ($transcriptLocs) = @_;

  foreach my $key (keys %$transcriptLocs) {
    $transcriptLocs->{$key}->{consensus_cds} = undef;
    $transcriptLocs->{$key}->{reference_cds} = undef;
  }

}


sub queryExtDbRlsIdFromSpec {
  my ($dbh, $extDbRlsSpec) = @_;

  my $sql = "select r.external_database_release_id
from sres.externaldatabaserelease r, sres.externaldatabase d
where d.external_database_id = r.external_database_id
and d.name || '|' || r.version = '$extDbRlsSpec'";


  my $sh = $dbh->prepare($sql);
  $sh->execute();

  my ($extDbRlsId) = $sh->fetchrow_array();

  $sh->finish();
  die "Could not find ext db rls id for spec: $extDbRlsSpec" unless($extDbRlsId);

  return $extDbRlsId;
}

sub lookupTranscripts {
  my ($sequenceId, $l, $exonLocs) = @_;

  return(undef) unless(ref ($exonLocs->{$sequenceId}) eq 'ARRAY');

  my @locations = @{$exonLocs->{$sequenceId}};

  my $startCursor = 0;
  my $endCursor = scalar(@locations) - 1;
  my $midpoint;

  return(undef) if($l < $locations[$startCursor]->{start} || $l > $locations[$endCursor]->{end});

  while ($startCursor <= $endCursor) {
    $midpoint = int(($endCursor + $startCursor) / 2);

    my $location = $locations[$midpoint];

    if ($l > $location->{start}) {
      $startCursor = $midpoint + 1;
    } 
    elsif ($l < $location->{start}) {
      $endCursor = $midpoint - 1;
    }
    else {  }

    if($l >= $location->{start} && $l <= $location->{end}) {

      my $transcripts = $location->{transcripts};
      return($transcripts);
    }
  }
  return(undef);

}


sub getTranscriptLocations {
  my ($dbh, $transcriptExtDbRlsId) = @_;

  my %exonLocs;
  my %transcriptLocs;

my $sql = "SELECT listagg(tf.na_feature_id, ',') WITHIN GROUP (ORDER BY tf.na_feature_id) as transcripts,
       s.source_id, 
       el.start_min as exon_start, 
       el.end_max as exon_end,
       ef.coding_start,
       ef.coding_end,
       el.is_reversed
FROM dots.TRANSCRIPT tf, dots.rnafeatureexon rfe, 
     dots.exonfeature ef, dots.nalocation el,
     dots.nasequence s
WHERE tf.na_feature_id = rfe.rna_feature_id
AND rfe.exon_feature_id = ef.na_feature_id
AND ef.na_feature_id = el.na_feature_id
AND ef.na_sequence_id = s.na_sequence_id
AND tf.external_database_release_id = $transcriptExtDbRlsId
AND s.source_id = 'M76611'
GROUP BY s.source_id, el.start_min, el.end_max, ef.coding_start, ef.coding_end, el.is_reversed
ORDER BY s.source_id, el.start_min
";

  my $sh = $dbh->prepare($sql);
  $sh->execute();

  while(my ($transcripts, $sequenceSourceId, $exonStart, $exonEnd, $cdsStart, $cdsEnd, $isReversed) = $sh->fetchrow_array()) {
    my @transcripts = split(",", $transcripts);

    my $location = { transcripts => \@transcripts,
                     end => $exonEnd,
                     start => $exonStart,
                   };

    push(@{$exonLocs{$sequenceSourceId}}, $location);

    foreach my $transcriptId (@transcripts) {
      my $exonLocation = [$exonStart, $exonEnd, $cdsStart, $cdsEnd];
      push @{$transcriptLocs{$transcriptId}->{exons}}, $exonLocation;
      $transcriptLocs{$transcriptId}->{is_reversed} = $isReversed;

    }
  }

  $sh->finish();

  return \%transcriptLocs, \%exonLocs;
}



sub _getCodingSequence {
  my ($dbh, $sequenceId, $transcriptLocs, $transcriptId, $snpStart, $snpEnd, $base, $seqExtDbRlsId) = @_;

  return unless($transcriptId);

  my $transcript = GUS::Model::DoTS::Transcript->new({na_feature_id => $transcriptId});


  unless($transcript->retrieveFromDB()) {
    die "Could not retrieve transcript $transcriptId from the db";
  }


  my @rnaFeatureExons = $transcript->getChildren("DoTS::RNAFeatureExon",1);
  my @exons = map { $_->getParent("DoTS::ExonFeature",1) } @rnaFeatureExons;


  unless (@exons) {
    die ("Transcript with na_feature_id = $transcriptId had no exons\n");
  }

  # this code gets the feature locations of the exons and puts them in order
  @exons = map { $_->[0] }
    sort { $a->[3] ? $b->[1] <=> $a->[1] : $a->[1] <=> $b->[1] }
      map { [ $_, $_->getFeatureLocation ]}
	@exons;

  my $transcriptSequence;

  for my $exon (@exons) {

    my ($exonStart, $exonEnd, $exonIsReversed) = $exon->getFeatureLocation();

    

    my $chunk = &querySequenceSubstring($dbh, $sequenceId, $seqExtDbRlsId, $exonStart, $exonEnd);

    my $codingStart = $exon->getCodingStart();
    my $codingEnd = $exon->getCodingEnd();
    next unless ($codingStart && $codingEnd);

    # For a Snp to be considered coding...it must be totally included in the coding sequence
    my $isForwardCoding = $codingStart <= $snpStart && $codingEnd >= $snpEnd && !$exonIsReversed;
    my $isReverseCoding = $snpStart >= $codingEnd && $snpEnd <= $codingStart && $exonIsReversed;

    if($isReverseCoding) {
      $transcriptLocs->{$transcript}->{is_reversed} = 1;
    }

    if($base && ($isForwardCoding || $isReverseCoding)) {
      $chunk = &_swapBaseInSequence($chunk, $exonStart, $exonEnd, $snpStart, $snpEnd, $base, $exonIsReversed);
    }

    my $trim5 = $exonIsReversed ? $exonEnd - $codingStart : $codingStart - $exonStart;
    substr($chunk, 0, $trim5, "") if $trim5 > 0;
    my $trim3 = $exonIsReversed ? $codingEnd - $exonStart : $exonEnd - $codingEnd;
    substr($chunk, -$trim3, $trim3, "") if $trim3 > 0;

    $transcriptSequence .= $chunk;
  }

  return($transcriptSequence);
}


sub _swapBaseInSequence {
  my ($seq, $exonStart, $exonEnd, $snpStart, $snpEnd, $base, $isReversed) = @_;

  my $normSnpStart = $isReversed ? $exonEnd - $snpEnd : $snpStart - $exonStart;
  my $normSnpEnd = $isReversed ? $exonEnd - $snpStart  : $snpEnd - $exonStart;

  my ($fivePrimeFlank, $threePrimeFlank);

  # An insertion is when the snpStart is one base less than the snpEnd
  # deletion have a base of '-' and are treated identically to substitutions

  $fivePrimeFlank = substr($seq, 0, $normSnpStart);
  $threePrimeFlank = substr($seq, ($normSnpEnd  + 1));

  my $newSeq =  $fivePrimeFlank. $base .$threePrimeFlank;
  $newSeq =~ s/\-//g;

  unless($newSeq =~ /$fivePrimeFlank/ || $newSeq =~ /$threePrimeFlank/) {
    die "Error in creating new Seq: \nnew=$newSeq\nold=$seq";
  }

  return($newSeq);
}

sub getCodingSequenceForTranscript {
  my ($dbh, $sequenceId, $snpStart, $snpEnd, $transcriptId, $transcriptLocs, $seqExtDbRlsId) = @_;

  my ($codingSequence, $mockCodingSequence);
  return($codingSequence, $mockCodingSequence) unless($transcriptId);


  if($transcriptLocs->{$transcriptId}->{$seqExtDbRlsId}->{consensus_cds}) {
    $codingSequence = $transcriptLocs->{$transcriptId}->{$seqExtDbRlsId}->{consensus_cds};
  }

  else {
    $codingSequence = &_getCodingSequence($dbh, $sequenceId, $transcriptLocs, $transcriptId, $snpStart, $snpEnd, '', $seqExtDbRlsId);
    $transcriptLocs->{$transcriptId}->{$seqExtDbRlsId}->{consensus_cds} = $codingSequence;
  }

  return $codingSequence;
}


sub getMockSequenceForTranscript {
  my ($sequenceId, $snpStart, $snpEnd, $transcriptId, $transcriptLocs, $seqExtDbRlsId) = @_;

  my $mockSequence = &createMockSequence($snpStart, $snpEnd);
  my $mockCodingSequence = &_getCodingSequence($dbh, $sequenceId, $transcriptLocs, $transcriptId, $snpStart, $snpEnd, $mockSequence, $seqExtDbRlsId);

  return $mockCodingSequence;
}


sub createMockSequence {
  my ($snpStart, $snpEnd) = @_;

  my $length = $snpEnd - $snpStart + 1;
  my $mockString;

  foreach(1..$length) {
    $mockString = $mockString."*";
  }
  return($mockString);
}


sub _isSynonymous {
  my ($codingSequence, $newCodingSequence) = @_;

  my $cds = Bio::Seq->new( -seq => $codingSequence );
  my $newCds = Bio::Seq->new( -seq => $newCodingSequence );

  my $translatedCds = $cds->translate();
  my $translatedNewCds = $newCds->translate();

  return($translatedCds->seq() eq $translatedNewCds->seq());
}

sub calculateAminoAcidPosition {
  my ($codingPosition) = @_;

  my $aaPos = ($codingPosition % 3 == 0) ? int($codingPosition / 3) : int($codingPosition / 3) + 1;

  return($aaPos);
}

sub _getAminoAcidSequenceOfSnp {
  my ($codingSequence, $start, $end) = @_;

  my $normStart = $start - 1;
  my $normEnd = $end - 1;

  my $cds = Bio::Seq->new( -seq => $codingSequence );
  my $translated = $cds->translate();

  my $lengthOfSnp = $normEnd - $normStart + 1;

  return(substr($translated->seq(), $normStart, $lengthOfSnp));
}


$dbh->disconnect();
close OUT;


