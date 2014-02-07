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

my ($newSampleFile, $cacheFile, $transcriptExtDbRlsSpec, $organismAbbrev, $undoneStrainsFile, $gusConfigFile, $varscanDirectory, $referenceStrain, $minAllelePercent, $help, $debug);

&GetOptions("new_sample_file=s"=> \$newSampleFile,
            "cache_file=s"=> \$cacheFile,
            "gusConfigFile|gc=s"=> \$gusConfigFile,
            "undone_strains_file=s" => \$undoneStrainsFile,
            "varscan_directory=s" => \$varscanDirectory,
            "transcript_extdb_spec=s" => \$transcriptExtDbRlsSpec,
            "organism_abbrev=s" =>\$organismAbbrev,
            "reference_strain=s" => \$referenceStrain,
            "minAllelePercent=i"=> \$minAllelePercent, 
            "debug" => \$debug,
            "help|h" => \$help,
    );

if($help) {
  &usage();
}

$minAllelePercent = 60 unless($minAllelePercent);
$gusConfigFile = $ENV{GUS_HOME} . "/config/gus.config" unless(-e $gusConfigFile);

unless(-e $newSampleFile && -e $gusConfigFile && -e $cacheFile && -e $undoneStrainsFile) {
  &usage("Required File Missing");
}

unless(-d $varscanDirectory) {
  &usage("Required Directory Missing");
}

unless($transcriptExtDbRlsSpec && $organismAbbrev && $referenceStrain) {
  &usage("Missing Required param value");
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

my $tempCacheFile = $dirname . "/cache.tmp";
my $snpOutputFile = $dirname . "/snp.tmp";

my ($snpFh, $cacheFh);
open($cacheFh, "> $tempCacheFile") or die "Cannot open file $tempCacheFile for writing: $!";
open($snpFh, "> $snpOutputFile") or die "Cannot open file $snpOutputFile for writing: $!";

my $strainVarscanFileHandles = &openVarscanFiles($varscanDirectory);

my @allStrains = keys %{$strainVarscanFileHandles};

my $strainExtDbRlsIds = &queryExtDbRlsIdsForStrains(\@allStrains, $dbh, $organismAbbrev);
my $transcriptExtDbRlsId = &queryExtDbRlsIdFromSpec($dbh, $transcriptExtDbRlsSpec);

my $agpMap = &queryForAgpMap($dbh);
my ($transcriptSummary, $exonLocs) = &getTranscriptLocations($dbh, $transcriptExtDbRlsId, $agpMap);

open(UNDONE, $undoneStrainsFile) or die "Cannot open file $undoneStrainsFile for reading: $!";
my @undoneStrains =  map { chomp; $_ } <UNDONE>;
close UNDONE;

my $merger = ApiCommonData::Load::MergeSortedFiles::SeqVarCache->new($newSampleFile, $cacheFile, \@undoneStrains);

my ($prevSequenceId, $prevTranscriptMaxEnd, $prevTranscripts);
while($merger->hasNext()) {
  my $variations = $merger->nextSNP();

  # sanity check and get the location and seq id
  my ($sequenceId, $location) = &snpLocationFromVariations($variations);

  # some variables are needed to store attributes of the SNP
  my ($referenceAllele, $positionInCds, $product, $positionInProtein, $referenceVariation);

  my $cachedReferenceVariation = &cachedReferenceVariation($variations, $referenceStrain);

  my $transcripts = &lookupTranscriptsByLocation($sequenceId, $location, $exonLocs);

  print STDERR "HAS TRANSCRIPTS=" . defined($transcripts) . "\n"  if($debug);

  # clear the transcripts cache once we pass the max exon for a group of transcripts
  if($sequenceId ne $prevSequenceId || $location > $prevTranscriptMaxEnd) {
    &cleanCdsCache($transcriptSummary, $prevTranscripts);
  }

  # for the refereence, get   positionInCds, positionInProtein, product, codon?
  if($cachedReferenceVariation) {
    print STDERR "HAS_CACHED REFERENCE VARIATION\n" if($debug);
    $referenceVariation = $cachedReferenceVariation;
    $product = $cachedReferenceVariation->{product};
    $positionInCds = $cachedReferenceVariation->{position_in_cds};
    $positionInProtein = &calculateAminoAcidPosition($positionInCds, $positionInCds);
    $referenceAllele = $cachedReferenceVariation->{base};
  }
  else {
    print STDERR "REFERENCE VARIATION NOT CACHED\n" if($debug);
    $referenceAllele = &querySequenceSubstring($dbh, $sequenceId, $location, $location);
    ($product, $positionInCds, $positionInProtein) = &processVariation($transcriptExtDbRlsId, $transcripts, $transcriptSummary, $sequenceId, $location, $referenceAllele);

    # add a variation for the reference
    $referenceVariation = {'base' => $referenceAllele,
                              'external_database_release_id' => $transcriptExtDbRlsId,
                              'location' => $location,
                              'sequence_source_id' => $sequenceId,
                              'matches_reference' => 1,
                              'position_in_cds' => $positionInCds,
                              'strain' => $referenceStrain,
                              'product' => $product,
    };

    print STDERR "REFERENCE PRODUCT=$product\n";
    print STDERR "REFERENCE CDS POS=$positionInCds\n";
    print STDERR "\n";
    push @$variations, $referenceVariation;
  }

  # No need to continue if there is no variation at this point:  Important for when we undo!!
  next unless(&hasVariation($variations));
  print STDERR "Has at leaset one variation.  cont....\n" if($debug);

 # loop over all strains  add coverage vars
  my @variationStrains = map { $_->{strain} } @$variations;
  my $coverageVariations = &makeCoverageVariations(\@allStrains, \@variationStrains, $strainVarscanFileHandles, $referenceVariation,$minAllelePercent);
  push @$variations, @$coverageVariations;

  # loop through variations and print
  foreach my $variation (@$variations) {
    my $strain = $variation->{strain};

    my $extDbRlsId;
    if($strain ne $referenceStrain) {
      $extDbRlsId = $strainExtDbRlsIds->{$strain};
    }

    if(my $cachedExtDbRlsId = $variation->{external_database_release_id}) {
      die "cachedExtDbRlsId did not match" if($strain ne $referenceStrain && $extDbRlsId != $cachedExtDbRlsId);
      &printVariation($variation, $cacheFh);
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

      my ($p, $cdsPos, $proteinPos) = &processVariation($extDbRlsId, $transcripts, $transcriptSummary, $strainSequenceSourceId, $location, $allele);
      $variation->{product} = $p;
      $variation->{position_in_cds} = $cdsPos;

    }

    $variation->{external_database_release_id} = $extDbRlsId;
    
    &printVariation($variation, $cacheFh);
  }
  print $cacheFh "\n";

  my $snp = &makeSNPFeatureFromVariations($variations);
  &printSNP($snp, $snpFh);

  # need to track these so we know when to clear the cache
  my @transcriptEnds = sort map {$transcriptSummary->{max_exon_end}} @$transcripts;
  $prevTranscriptMaxEnd = $transcriptEnds[scalar @transcriptEnds];
  $prevSequenceId = $sequenceId;
  $prevTranscripts = $transcripts;
  
  $db->undefPointerCache();
}

close $cacheFh;
close $snpFh;
&closeVarscanFiles($strainVarscanFileHandles);

# Rename the output file to full cache file
#unlink $cacheFile or warn "Could not unlink $cacheFile: $!";
#system("mv $tempCacheFile $cacheFile");

# overwrite existing sample file w/ empty file
#open(TRUNCATE, ">$newSampleFile") or die "Cannot open file $newSampleFile for writing: $!";
#close(TRUNCATE);

1;

#--------------------------------------------------------------------------------
# BEGIN SUBROUTINES
#--------------------------------------------------------------------------------
sub queryForAgpMap {
  my ($dbh) = @_;

  my %agpMap;

  my $sql = "select sp.virtual_na_sequence_id
                                , p.na_sequence_id as piece_na_sequence_id
                               , decode(sp.strand_orientation, '+', '+1', '-', '-1', '+1') as piece_strand
                               , p.length as piece_length
                               , sp.distance_from_left as virtual_start_min
                               , sp.distance_from_left + p.length as virtual_end_max
                               , p.source_id as piece_source_id
                               , vs.source_id as virtual_source_id
                   from dots.sequencepiece sp
                           , dots.nasequence p
                           ,  dots.nasequence vs
                   where  sp.piece_na_sequence_id = p.na_sequence_id
                    and sp.virtual_na_sequence_id = vs.na_sequence_id";

  my $sh = $dbh->prepare($sql);
  $sh->execute();

  while(my $hash = $sh->fetchrow_hashref()) {
    my $ctg = Bio::Location::Simple->new( -seq_id => $hash->{PIECE_SOURCE_ID}, 
                                          -start => 1, 
                                          -end =>  $hash->{PIECE_LENGTH}, 
                                          -strand => $hash->{PIECE_STRAND});

    my $ctg_on_chr = Bio::Location::Simple->new( -seq_id =>  $hash->{VIRTUAL_SOURCE_ID}, 
                                                 -start => $hash->{VIRTUAL_START_MIN},
                                                 -end =>  $hash->{VIRTUAL_END_MAX} , 
                                                 -strand => '+1' );

    my $agp = Bio::Coordinate::Pair->new( -in  => $ctg, -out => $ctg_on_chr );
    my $pieceSourceId = $hash->{PIECE_SOURCE_ID};
 
    $agpMap{$pieceSourceId} = $agp;
  }

  $sh->finish();

  return \%agpMap;
}

sub usage {
  my ($m) = @_;

  if($m) {
    print STDERR $m . "\n";
    die "Error running program";
  }

  print STDERR "usage:  processSequenceVariations.pl --new_sample_file=<FILE> --cache_file=<FILE> [--gusConfigFile=<GUS_CONFIG>] --undone_strains_file=<FILE> --varscan_directory=<DIR> --transcript_extdb_spec=s --organism_abbrev=s --reference_strain=s [--minAllelePercent=i]\n";
  exit;
}

sub printVariation {
  my ($variation, $fh) = @_;

  my @keys = ('external_database_release_id',
              'strain',
              'sequence_source_id',
              'location',
              'base',
              'matches_reference',
              'position_in_cds',
              'product',
              'pvalue',
              'percent',
              'coverage',
              'quality');

  print $fh join("\t", map {$variation->{$_}} @keys) . "\n";

}

sub printSNP {
  my ($snp, $fh) = @_;

  print $fh $snp->{ref_loc}."\n";
}


sub makeSNPFeatureFromVariations {
  my ($variations) = @_;

  return { ref_loc => 232
  };

}

sub makeCoverageVariations {
  my ($allStrains, $variationStrains, $strainVarscanFileHandles, $referenceVariation, $minAllelePercent) = @_;

  my @rv;

  foreach my $strain (@$allStrains) {
    my $hasVariation;

    foreach my $varStrain (@$variationStrains) {
      if($varStrain eq $strain) {
        $hasVariation = 1;
        last;
      }
    }
    unless($hasVariation) {
      my $fh = $strainVarscanFileHandles->{$strain} ;
      my $variation = &makeCoverageVariation($fh, $referenceVariation, $strain, $minAllelePercent);

      if($variation) {
        push @rv, $variation;
      }
    }
  }
  return \@rv;
}

sub makeCoverageVariation {
  my ($fh, $referenceVariation, $strain, $minAllelePercent) = @_;

  my $rv;

  my $location = $referenceVariation->{location};
  my $sequenceId = $referenceVariation->{sequence_source_id};
  my $referenceAllele = $referenceVariation->{base};

  my $pos;
  while(1) {
    $pos = tell $fh;
    my $line = <$fh> or last;
    chomp $line;
    
    my @a = split(/\t/, $line);
    my $varSequence = $a[0];
    my $varLocation = $a[1];
    
    if($varSequence eq $sequenceId && $varLocation == $location) {
      my $varRef = $a[2];
      my $varCons = $a[3];

      if($varRef ne $referenceAllele) {
        die "Calculated Reference Allele [$referenceAllele] does not match Varscan Ref [$varRef] for Sequence [$sequenceId] and Location [$location]";
      }

      next unless($varRef eq $varCons);
      
      my $varCoverage = $a[4] + $a[5];
      chop $a[6];
      my $varPercent = $a[2] eq $a[3] ? 100 - $a[6] : $a[6];

      if($varPercent >= $minAllelePercent) {
      
        $rv = {'base' => $referenceAllele,
               'location' => $location,
               'sequence_source_id' => $sequenceId,
               'matches_reference' => 1,
               'strain' => $strain,
        };
        last;
      }
      # I've read enough to know when I've read too much
      if($varSequence gt $sequenceId || ($varSequence eq $sequenceId && $varLocation > $location)) {
        seek $fh, $pos, 0 or die "Couldn't seek to $pos: $!\n";
        last;
      }
    }
  }
  return $rv;
}



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
  my ($dbh, $sequenceId, $start, $end) = @_;

  my $length = $end - $start + 1;

  my $sql = "select substr(s.sequence, ?, ?) as base
                      from dots.nasequence s
                     where s.source_id = ?";

  my $sh = $dbh->prepare($sql);
  $sh->execute($start, $length, $sequenceId);

  my ($base) = $sh->fetchrow_array();
  $sh->finish();

  return $base;
}

sub processVariation {
  my ($transcriptExtDbRlsId, $transcripts, $transcriptSummary, $sequenceId, $location, $base) = @_;

  my %products;
  my %positionInCdss;
  my %positionInProteins;

  foreach my $transcript (@$transcripts) {
    next if($transcriptSummary->{$transcript}->{is_non_coding}); # don't bother for non coding transcripts

    print STDERR "TRANSCRIPT=$transcript\n";

    my ($consensusCodingSequence, $mockCodingSequence, $isCoding);

    if($transcriptSummary->{$transcript}->{cache}->{$transcriptExtDbRlsId}) {
      print STDERR "Using sequence from CACHE\n";

      $consensusCodingSequence = $transcriptSummary->{$transcript}->{cache}->{$transcriptExtDbRlsId}->{consensus_cds};
      $mockCodingSequence = $transcriptSummary->{$transcript}->{cache}->{$transcriptExtDbRlsId}->{mock_cds};
    }
    else { # first time through
      print STDERR "Putting Sequence in CACHE\n" if($debug);

      $consensusCodingSequence = &getCodingSequence($dbh, $sequenceId, $transcriptSummary, $transcript, $location, $location, '', $transcriptExtDbRlsId);
      $mockCodingSequence = &getMockSequenceForTranscript($sequenceId, $location, $location, $transcript, $transcriptSummary, $transcriptExtDbRlsId);

      $transcriptSummary->{$transcript}->{cache}->{$transcriptExtDbRlsId}->{consensus_cds} = $consensusCodingSequence;
      $transcriptSummary->{$transcript}->{cache}->{$transcriptExtDbRlsId}->{mock_cds} = $mockCodingSequence;
    }

    $isCoding = $consensusCodingSequence ne $mockCodingSequence;

    if($isCoding) {
      my ($codingSnpStart, $codingSnpEnd) = &getCodingSubstitutionPositions($consensusCodingSequence, $mockCodingSequence);

      unless($codingSnpStart == $codingSnpEnd) {
        die "Should be exactly one coding position for this snp";
      }

      $positionInCdss{$codingSnpStart}++;

      if($transcriptSummary->{$transcript}->{is_reversed}) {
        $base = CBIL::Bio::SequenceUtils::reverseComplementSequence($base);
      }

    my $newCodingSequence = &swapBaseInSequence($consensusCodingSequence, 1, 1, $codingSnpStart, $codingSnpStart, $base, '');
    my $positionInProtein = &calculateAminoAcidPosition($codingSnpStart, $codingSnpStart);
    my $product = &getAminoAcidSequenceOfSnp($newCodingSequence, $positionInProtein, $positionInProtein);
  
    $products{$product}++;
    $positionInProteins{$positionInProtein}++;
    }
    else {
      $transcriptSummary->{$transcript}->{is_non_coding} = 1;
    }
  }

  my $rvProduct = scalar keys %products == 1 ? (keys %products)[0] : "NA";
  my $rvPositionInCds = scalar keys %positionInCdss == 1 ? (keys %positionInCdss)[0] : "NA";
  my $rvPositionInProtein = scalar keys %positionInProteins == 1 ? (keys %positionInProteins)[0] : "NA";
  print STDERR "RESULT=" . join("\t", ($rvProduct, $rvPositionInCds, $rvPositionInProtein)) . "\n";
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
    $sh->execute($organismAbbrev, $match);

    my $ct;
    while(my ($name, $extDbName, $extDbVersion) = $sh->fetchrow_array()) {
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
        print STDERR "OPEN GZ FILE: $file for Strain $strain\n" if($debug);
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
  my ($transcriptSummary, $transcripts) = @_;

  foreach my $transcript (@$transcripts) {
    $transcriptSummary->{$transcript}->{cache} = undef;
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

sub lookupTranscriptsByLocation {
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
      return($location->{transcripts});
    }
  }
  return(undef);

}


sub getTranscriptLocations {
  my ($dbh, $transcriptExtDbRlsId, $agpMap) = @_;

  my %exonLocs;
  my %transcriptSummary;

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
GROUP BY s.source_id, el.start_min, el.end_max, ef.coding_start, ef.coding_end, el.is_reversed
ORDER BY s.source_id, el.start_min
";

  my $sh = $dbh->prepare($sql);
  $sh->execute();

  while(my ($transcripts, $sequenceSourceId, $exonStart, $exonEnd, $cdsStart, $cdsEnd, $isReversed) = $sh->fetchrow_array()) {
    my @transcripts = split(",", $transcripts);

    # if this sequence is a PIECE in another sequence... lookup the higher level sequence
    if(my $agp = $agpMap->{$sequenceSourceId}) {
      my $exonMatch = Bio::Location::Simple->
          new( -seq_id => 'exon', -start => $exonStart  , -end => $exonEnd , -strand => +1 );

      my $matchOnVirtual = $agp->map( $exonMatch );

      $sequenceSourceId = $matchOnVirtual->seq_id();
      $exonStart = $matchOnVirtual->start();
      $exonEnd = $matchOnVirtual->end();
    }

    my $location = { transcripts => \@transcripts,
                     end => $exonEnd,
                     start => $exonStart,
                   };

    push(@{$exonLocs{$sequenceSourceId}}, $location);

    foreach my $transcriptId (@transcripts) {
      if(!$transcriptSummary{$transcriptId}->{max_exon_end} || $exonEnd > $transcriptSummary{$transcriptId}->{max_exon_end}) {
        $transcriptSummary{$transcriptId}->{max_exon_end} = $exonEnd;
      }
    }
  }

  $sh->finish();

  return \%transcriptSummary, \%exonLocs;
}



sub getCodingSequence {
  my ($dbh, $sequenceId, $transcriptSummary, $transcriptId, $snpStart, $snpEnd, $base, $seqExtDbRlsId) = @_;

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

    my $chunk = &querySequenceSubstring($dbh, $sequenceId, $exonStart, $exonEnd);

    my $codingStart = $exon->getCodingStart();
    my $codingEnd = $exon->getCodingEnd();
    next unless ($codingStart && $codingEnd);

    # For a Snp to be considered coding...it must be totally included in the coding sequence
    my $isForwardCoding = $codingStart <= $snpStart && $codingEnd >= $snpEnd && !$exonIsReversed;
    my $isReverseCoding = $snpStart >= $codingEnd && $snpEnd <= $codingStart && $exonIsReversed;

    if($isReverseCoding) {
      $transcriptSummary->{$transcript}->{is_reversed} = 1;
    }

    if($base && ($isForwardCoding || $isReverseCoding)) {
      $chunk = &swapBaseInSequence($chunk, $exonStart, $exonEnd, $snpStart, $snpEnd, $base, $exonIsReversed);
    }

    my $trim5 = $exonIsReversed ? $exonEnd - $codingStart : $codingStart - $exonStart;
    substr($chunk, 0, $trim5, "") if $trim5 > 0;
    my $trim3 = $exonIsReversed ? $codingEnd - $exonStart : $exonEnd - $codingEnd;
    substr($chunk, -$trim3, $trim3, "") if $trim3 > 0;

    $transcriptSequence .= $chunk;
  }

  return($transcriptSequence);
}


sub swapBaseInSequence {
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

sub getMockSequenceForTranscript {
  my ($sequenceId, $snpStart, $snpEnd, $transcriptId, $transcriptSummary, $seqExtDbRlsId) = @_;

  my $mockSequence = &createMockSequence($snpStart, $snpEnd);
  my $mockCodingSequence = &getCodingSequence($dbh, $sequenceId, $transcriptSummary, $transcriptId, $snpStart, $snpEnd, $mockSequence, $seqExtDbRlsId);

  $transcriptSummary->{$transcriptId}->{cache}->{$seqExtDbRlsId}->{mock_cds} = $mockCodingSequence;

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

# TODO:  Is this needed???
sub isSynonymous {
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

sub getAminoAcidSequenceOfSnp {
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


1;
