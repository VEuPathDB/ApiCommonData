#!/usr/bin/perl

use strict;

use FileHandle;

use File::Basename;
use Data::Dumper;

use GUS::Model::DoTS::Transcript;

use Getopt::Long;

use GUS::ObjRelP::DbiDatabase;
use GUS::Supported::GusConfig;

use CBIL::Bio::SequenceUtils;

use Bio::Seq;
use Bio::Tools::GFF;
use Bio::Coordinate::GeneMapper;
use Bio::Coordinate::Pair;
use Bio::Location::Simple;

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
  my ($referenceAllele, $positionInCds, $product, $positionInProtein, $referenceVariation, $isCoding);

  my $cachedReferenceVariation = &cachedReferenceVariation($variations, $referenceStrain);

  my $transcripts = &lookupTranscriptsByLocation($sequenceId, $location, $exonLocs);

  my $hasTranscripts = defined($transcripts) ? 1 : 0;
  print STDERR "HAS TRANSCRIPTS=$hasTranscripts\n"  if($debug);

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
    $isCoding = $cachedReferenceVariation->{is_coding};
  }
  else {
    print STDERR "REFERENCE VARIATION NOT CACHED\n" if($debug);
    $referenceAllele = &querySequenceSubstring($dbh, $sequenceId, $location, $location);

    # These 3 are only calculated for the reference; IsCoding is set to true if the snp is contained w/in any coding transcript
    ($isCoding, $positionInCds, $positionInProtein) = &calculateCdsPosition($transcripts, $transcriptSummary, $sequenceId, $location);
    
    $product = &variationProduct($transcriptExtDbRlsId, $transcripts, $transcriptSummary, $sequenceId, $location, $positionInProtein) if($positionInProtein);

    # add a variation for the reference
    $referenceVariation = {'base' => $referenceAllele,
                              'external_database_release_id' => $transcriptExtDbRlsId,
                              'location' => $location,
                              'sequence_source_id' => $sequenceId,
                              'matches_reference' => 1,
                              'position_in_cds' => $positionInCds,
                              'strain' => $referenceStrain,
                              'product' => $product,
                           'position_in_protein' => $positionInProtein,
    };
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

      my $p = &variationProduct($extDbRlsId, $transcripts, $transcriptSummary, $strainSequenceSourceId, $location, $positionInProtein) if($positionInProtein);
      $variation->{product} = $p;
      $variation->{position_in_cds} = $positionInCds; #got this from the refernece
      $variation->{position_in_protein} = $positionInProtein; #got this from the reference
    }

    $variation->{external_database_release_id} = $extDbRlsId;
    
    &printVariation($variation, $cacheFh);
  }

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

$dbh->disconnect();
close OUT;

#--------------------------------------------------------------------------------
# BEGIN SUBROUTINES
#--------------------------------------------------------------------------------

sub calculateCdsPosition {
  my ($transcripts, $transcriptSummary, $sequenceId, $location) = @_;

  my %cdsPositions;
  my %proteinPositions;

  my $isCoding;

  foreach my $transcript (@$transcripts) {
    my $gene = Bio::Coordinate::GeneMapper->new(
      -in  => "chr",
      -out => "cds",
      -cds => Bio::Location::Simple->new(
         -start  => $transcriptSummary->{$transcript}->{min_cds_start},
         -end  => $transcriptSummary->{$transcript}->{max_cds_end},
         -strand => $transcriptSummary->{$transcript}->{cds_strand},
         -seq_id => $sequenceId,
      ),
      -exons => $transcriptSummary->{$transcript}->{exons}
    );

    my $loc =   Bio::Location::Simple->new(
      -start => $location,
      -end   => $location,,
      -strand => +1,
      -seq_id => $sequenceId,
    );

    my $map = $gene->map($loc);

    my $cdsPos = $map->start;
    if($cdsPos && $cdsPos > 1) {
      my $positionInProtein = &calculateAminoAcidPosition($cdsPos, $cdsPos);

      $cdsPositions{$cdsPos}++;
      $proteinPositions{$positionInProtein}++;

      $isCoding = 1;
    }
  }

  my $rvPositionInCds;
  my $rvPositionInProtein;

  if(scalar keys %cdsPositions == 1) {
    $rvPositionInCds = (keys %cdsPositions)[0];
  }
  if(scalar keys %proteinPositions == 1) {
    $rvPositionInProtein = (keys %proteinPositions)[0] ;
  }

  return($isCoding, $rvPositionInCds, $rvPositionInProtein);
}


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
              'position_in_protein',
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


# TODO
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

sub variationProduct {
  my ($transcriptExtDbRlsId, $transcripts, $transcriptSummary, $sequenceId, $location, $positionInProtein) = @_;

  my %products;

  foreach my $transcript (@$transcripts) {

    my $consensusCodingSequence;
    if($transcriptSummary->{$transcript}->{cache}->{$transcriptExtDbRlsId}) {
      $consensusCodingSequence = $transcriptSummary->{$transcript}->{cache}->{$transcriptExtDbRlsId}->{consensus_cds};
    }
    else { # first time through for this transcript
      $consensusCodingSequence = &getCodingSequence($dbh, $sequenceId, $transcriptSummary, $transcript, $location, $location, $transcriptExtDbRlsId);
      $transcriptSummary->{$transcript}->{cache}->{$transcriptExtDbRlsId}->{consensus_cds} = $consensusCodingSequence;
    }

    my $product = &getAminoAcidSequenceOfSnp($consensusCodingSequence, $positionInProtein, $positionInProtein);
    $products{$product}++;
  }

  my $rvProduct;
  if(scalar keys %products == 1) {
    $rvProduct = (keys %products)[0];
  }

  return($rvProduct);
}

sub cachedReferenceVariation {
    my ($variations, $referenceStrain) = @_;

    foreach(@$variations) {
      return $_ if($_->{strain} eq $referenceStrain);
    }
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
      print STDERR Dumper $variations;
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
    $fhHash->{$_}->close();
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
    my $fh = FileHandle->new;
    my $fullPath = $varscanDirectory . "/$file";

    if($file =~ /(.+)\.varscan.cons/) {
      my $strain = $1;

      if($file =~ /\.gz$/) {
        print STDERR "OPEN GZ FILE: $file for Strain $strain\n" if($debug);
        $fh->open("zcat $fullPath |") || die "unable to open file $fullPath";
    } 
      else {
        $fh->open($fullPath) || die "unable to open file $fullPath"; 
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
       decode(el.is_reversed, 1, ef.coding_end, ef.coding_start) as cds_start,
       decode(el.is_reversed, 1, ef.coding_start, ef.coding_end) as cds_end,
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

      my $cdsMatch;
      if($cdsStart && $cdsEnd) {
        $cdsMatch = Bio::Location::Simple->
            new( -seq_id => 'cds', -start => $cdsStart  , -end => $cdsEnd , -strand => +1 );
      }

      my $matchOnVirtual = $agp->map( $exonMatch );
      my $cdsMatchOnVirtual = $agp->map( $cdsMatch );

      $sequenceSourceId = $matchOnVirtual->seq_id();
      $exonStart = $matchOnVirtual->start();
      $exonEnd = $matchOnVirtual->end();
      $cdsStart = $cdsMatchOnVirtual->start();
      $cdsEnd = $cdsMatchOnVirtual->end();
    }

    my $strand = $isReversed ? -1 : +1;
    my $loc = Bio::Location::Simple->new( -seq_id => $sequenceSourceId, -start => $exonStart  , -end => $exonEnd , -strand => $strand);

    my $location = { transcripts => \@transcripts,
                     start => $exonStart,
                     end => $exonEnd,
                   };

    push(@{$exonLocs{$sequenceSourceId}}, $location);

    foreach my $transcriptId (@transcripts) {
      push @{$transcriptSummary{$transcriptId}->{exons}}, $loc;

      if($cdsStart && $cdsEnd) {
        $transcriptSummary{$transcriptId}->{cds_strand} = $strand;
        if(!{$transcriptSummary{$transcriptId}->{max_cds_end}} || $cdsEnd > $transcriptSummary{$transcriptId}->{max_cds_end}) {
          $transcriptSummary{$transcriptId}->{max_cds_end} = $cdsEnd;
        }
        if(!$transcriptSummary{$transcriptId}->{min_cds_start} || $cdsStart < $transcriptSummary{$transcriptId}->{min_cds_start}) {
          $transcriptSummary{$transcriptId}->{min_cds_start} = $cdsStart;
        }
      }

      if(!$transcriptSummary{$transcriptId}->{max_exon_end} || $exonEnd > $transcriptSummary{$transcriptId}->{max_exon_end}) {
        $transcriptSummary{$transcriptId}->{max_exon_end} = $exonEnd;
      }
    }
  }

  $sh->finish();

  return \%transcriptSummary, \%exonLocs;
}



sub getCodingSequence {
  my ($dbh, $sequenceId, $transcriptSummary, $transcriptId, $snpStart, $snpEnd, $seqExtDbRlsId) = @_;

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

    my $codingStart = $exon->getCodingStart();
    my $codingEnd = $exon->getCodingEnd();
    next unless ($codingStart && $codingEnd);

    my $chunk =   &querySequenceSubstring($dbh, $sequenceId, $exonStart, $exonEnd);
    $chunk = CBIL::Bio::SequenceUtils::reverseComplementSequence($chunk) if($exonIsReversed);

    my $trim5 = $exonIsReversed ? $exonEnd - $codingStart : $codingStart - $exonStart;
    substr($chunk, 0, $trim5, "") if $trim5 > 0;
    my $trim3 = $exonIsReversed ? $codingEnd - $exonStart : $exonEnd - $codingEnd;
    substr($chunk, -$trim3, $trim3, "") if $trim3 > 0;

    $transcriptSequence .= $chunk;
  }

  return($transcriptSequence);
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




1;
