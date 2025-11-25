#!/usr/bin/perl

use strict;

use lib "$ENV{GUS_HOME}/lib/perl";

use Getopt::Long;
use DBI;

use GUS::Supported::GusConfig;

use Bio::SeqFeature::Generic;
use Bio::SeqFeature::Collection;

my ($mode, $orgAbbrev, $gusConfigFile, $help, $schema, $project, $debug);
&GetOptions("orgAbbrev=s" => \$orgAbbrev,
            "mode=s" => \$mode,
            "schema=s" => \$schema,
            "project=s" => \$project,
            "help" => \$help,
            "debug" => \$debug,
            "gusConfigFile|c=s" => \$gusConfigFile,

           );

my $gusconfig = GUS::Supported::GusConfig->new($gusConfigFile);
my $dsn = $gusconfig->getDbiDsn();
my $u = $gusconfig->getDatabaseLogin();
my $pw = $gusconfig->getDatabasePassword();

my $dbh = DBI->connect($dsn, $u, $pw) or die DBI::errstr;

&usage() if($help);


if($mode eq 'load') {
    &loadRows($dbh, $schema, $orgAbbrev, $project);
}

if($mode eq 'delete') {
    &deleteRows($dbh, $schema, $orgAbbrev);
}


$dbh->disconnect();

#--------------------------------------------------------------------------------

sub deleteRows {
  my ($dbh, $schema, $orgAbbrev) = @_;

  my $sql = "delete from ${schema}.splicesitetranscript_p where org_abbrev = ?";
  my $sh = $dbh->prepare($sql);
  my $rows = $sh->execute($orgAbbrev);

  print STDERR "Deleted $rows rows from ${schema}.splicesitetranscript\n";
  $dbh->commit();
}

#--------------------------------------------------------------------------------

sub loadRows {
    my ($dbh, $schema, $orgAbbrev, $project) = @_;

  # Coding end is always bigger than coding start
  my $transcriptLocSql = "select ta.gene_source_id
, ta.source_id
, ta.coding_start
, ta.coding_end
, ta.is_reversed
from ${schema}.transcriptattributes_p ta
, (select source_id from apidb.polyagenes
   union
   select source_id from apidb.splicesitegenes) ss
where ss.source_id = ta.gene_source_id
 and ta.coding_start is not null
 and ta.org_abbrev = '$orgAbbrev'
";

  my $tsh = $dbh->prepare($transcriptLocSql);
  $tsh->execute();

  my %geneTranscriptLocations;
  while(my ($gene, $transcript, $cdsStart, $cdsEnd, $isReversed) = $tsh->fetchrow_array()) {
    push @{$geneTranscriptLocations{$gene}}, [$transcript, $cdsStart, $cdsEnd, $isReversed];
  }


  my $ssSql =  "select * from (
select ssg.source_id
  , ssf.segment_start
  , ssf.is_unique
  , ssg.dist_to_first_atg
  , sum(ssf.count_per_million) sum_cpm
  , ssf.type
  , ssf.na_sequence_id
  , ssf.strand
from apidb.splicesitegenes ssg
 , apidb.splicesitefeature ssf
 , ${schema}.GenomicSeqAttributes_p gsa
where ssg.splice_site_feature_id = ssf.splice_site_feature_id
 and ssf.na_sequence_id = gsa.na_sequence_id
 and gsa.org_abbrev = '$orgAbbrev'
--TODO Remove
--and ssg.source_id in ( 'Tb11.v5.0365')
group by ssg.source_id, ssf.segment_start, ssf.is_unique, ssg.dist_to_first_atg, ssf.type, ssf.na_sequence_id, ssf.strand
union
select ssg.source_id
  , ssf.segment_start
  , ssf.is_unique
  , null
  , sum(ssf.count_per_million) sum_cpm
  , ssf.type
  , ssf.na_sequence_id
  , ssf.strand
from apidb.polyagenes ssg
 , apidb.splicesitefeature ssf
 , ${schema}.GenomicSeqAttributes_p gsa
where ssg.splice_site_feature_id = ssf.splice_site_feature_id
and ssf.na_sequence_id = gsa.na_sequence_id
 and gsa.org_abbrev = '$orgAbbrev'
--TODO Remove
--and ssg.source_id in ( 'Tb11.v5.0365')
group by ssg.source_id, ssf.segment_start, ssf.is_unique, ssf.type, ssf.na_sequence_id, ssf.strand
)  t
order by source_id";

  my $prevGene;
  my $sh = $dbh->prepare($ssSql);
  $sh->execute();

  my $insertSql = "INSERT INTO ${schema}.SpliceSiteTranscript_p (location, type, na_sequence_id, is_unique, sum_cpm, dist_to_first_atg, transcript_source_id, dist_to_cds, is_dominant, gene_source_id, strand, project_id, org_abbrev, modification_date) VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,now())";
  my $insertSh = $dbh->prepare($insertSql);

  my (@splicedLeaderFeatures, @polyAFeatures, $minLoc, $maxLoc, $polyAStrand, $slStrand);
  while(my ($gene, $loc, $isUniq, $distToFirstAtg, $sumCpm, $type, $naSequenceId, $ssfStrand) = $sh->fetchrow_array()) {
    if($prevGene && $prevGene ne $gene) {

      &makePolyAAndSplicedLeaderRows($insertSh, $geneTranscriptLocations{$prevGene}, \@polyAFeatures, \@splicedLeaderFeatures, $minLoc, $maxLoc, $prevGene, $polyAStrand, $slStrand, $orgAbbrev, $project);

      @splicedLeaderFeatures = ();
      @polyAFeatures = ();
      $minLoc = undef;
      $maxLoc = undef;
      $polyAStrand = undef;
      $slStrand = undef;
    }

    $minLoc = $loc if(! defined($minLoc) || $loc < $minLoc);
    $maxLoc = $loc if(! defined($maxLoc) || $loc > $maxLoc);

    my $feature = Bio::SeqFeature::Generic->new(-start => $loc,
                                                -end => $loc,
                                                -primary_tag => $type,
                                                -seq_id => $naSequenceId,
                                                -tag => { 'is_unique' => $isUniq,  'sum_cpm' => $sumCpm, 'gene' => $gene, 'dist_to_first_atg' => $distToFirstAtg, 'strand' => $ssfStrand}
        );

    if($type eq 'Poly A') {
      push @polyAFeatures, $feature;
      $polyAStrand = $ssfStrand
    }
    else {
      push @splicedLeaderFeatures, $feature;
      $slStrand = $ssfStrand
    }


    $prevGene = $gene;
  }

  if($prevGene) {
    &makePolyAAndSplicedLeaderRows($insertSh, $geneTranscriptLocations{$prevGene}, \@polyAFeatures, \@splicedLeaderFeatures, $minLoc, $maxLoc, $prevGene, $polyAStrand, $slStrand, $orgAbbrev, $project);
  }

 
  $dbh->commit();
  
}

#--------------------------------------------------------------------------------

sub makePolyAAndSplicedLeaderRows {
  my ($insertSh, $transcriptLocations, $polyAFeatures, $splicedLeaderFeatures, $minLoc, $maxLoc, $gene, $polyAStrand, $slStrand, $orgAbbrev, $project) = @_;

  return unless($transcriptLocations);

  my @sortedTranscriptLocations = sort { $a->[1] <=> $b->[1] || $a->[2] <=> $b->[2] } @$transcriptLocations;

  my $splicedLeaderCollection = Bio::SeqFeature::Collection->new();
  $splicedLeaderCollection->add_features($splicedLeaderFeatures);
  &processSpliceSites($insertSh, \@sortedTranscriptLocations, $splicedLeaderCollection, $minLoc, $maxLoc, 'SL', $gene, $slStrand, $orgAbbrev, $project);

  my $polyACollection = Bio::SeqFeature::Collection->new();
  $polyACollection->add_features($polyAFeatures);
  &processSpliceSites($insertSh, \@sortedTranscriptLocations, $polyACollection, $minLoc, $maxLoc, 'PA', $gene, $polyAStrand, $orgAbbrev, $project);
}

#--------------------------------------------------------------------------------

sub processSpliceSites {
  my  ($insertSh, $transcriptLocations, $collection, $minLoc, $maxLoc, $typeAbbrev, $gene, $strand, $orgAbbrev, $project) = @_;

  my ($start, $end, @locations, $swap, $index);
  if(($typeAbbrev eq 'SL' && $strand eq '+') || ($typeAbbrev eq 'PA' && $strand eq '+')) {
    $start = $minLoc;
    $end = $maxLoc;
    $index = 1;
    @locations = @$transcriptLocations;
  }
  elsif(($typeAbbrev eq 'SL' && $strand eq '-') || ($typeAbbrev eq 'PA' && $strand eq '-')) {
    $start = $maxLoc;
    $end = $minLoc;
    $index = 2;
    $swap = 1;
    @locations = reverse @$transcriptLocations;
  }


  my $prev = $start;

  for(my $i = 0; $i < scalar @locations; $i++) {

    my $transcript = $locations[$i]->[0];
    my $value = $locations[$i]->[$index];

    &processRegion($insertSh, $collection, $prev, $value, $typeAbbrev, $swap, $transcript, $gene, $orgAbbrev, $project);

    my $pIndex = $i + 1;
    if($locations[$pIndex]) {
      if($locations[$pIndex]->[$index] == $value) { # if 2 transcripts have same loc then want to keep the prev loc
        print STDERR "Location [$value] for transcript $transcript is shared w/ another transcript.  Splice sites assigned will be the same for all\n" if($debug);
      }
      else {
        $prev = $swap ? $value - 1: $value + 1;
      }
    }
    else {
      $prev = $swap ? $value - 1: $value + 1;
    }
  }

  my $lengthLocations = scalar @locations;

  &processRegion($insertSh, $collection, $prev, $end, $typeAbbrev, $swap, undef, $gene, $orgAbbrev, $project);
}

#--------------------------------------------------------------------------------

sub processRegion {
  my ($insertSh, $collection, $start, $end, $typeAbbrev, $swap, $transcript, $gene, $orgAbbrev, $project) = @_;

  my $s = $swap ? $end : $start;
  my $e = $swap ? $start : $end;

  if($s >= $e) {
    print STDERR "Skipping segment from $s to $e for transcript [$transcript];  no splice sites in that region\n" if($debug);
    return;
  }
  my @subset = $collection->features_in_range(-start => $s,
                                              -end => $e,
                                              -contain => 1);

  my $dominantCpm = &getDominantCpm(\@subset);

  foreach my $feature (@subset) {
    &insertRow($insertSh, $feature, $transcript, $end, $dominantCpm, $gene, $orgAbbrev, $project);
  }

}

#--------------------------------------------------------------------------------

sub insertRow {
  my ($insertSh, $feature, $transcript, $end, $dominantCpm, $gene, $orgAbbrev, $project) = @_;

  my $location = $feature->start();
  my $type = $feature->primary_tag();
  my $naSequenceId = $feature->seq_id();
  my ($isUnique) = $feature->get_tag_values('is_unique');
  my ($sumCpm) = $feature->get_tag_values('sum_cpm');
  my ($distToFirstAtg) = $feature->get_tag_values('dist_to_first_atg');
  my ($strand) = $feature->get_tag_values('strand');

  my $distToCds = defined($transcript) ? abs ($location - $end) : undef;
  my $isDominant = $sumCpm == $dominantCpm ? 1 : 0;

  $insertSh->execute($location, $type, $naSequenceId, $isUnique, $sumCpm, $distToFirstAtg, $transcript, $distToCds, $isDominant, $gene, $strand, $project, $orgAbbrev);
}

#--------------------------------------------------------------------------------

sub getDominantCpm {
  my ($features) = @_;

  return unless(scalar @$features > 0);

  my %distinctCpms;
  my $rv;

  foreach my $feat (@$features) {
    my ($cpm) = $feat->get_tag_values('sum_cpm');
    $distinctCpms{$cpm}++;

    if($rv) {
      $rv = $cpm if($cpm > $rv);
    }
    else {
      $rv = $cpm
    }
  }

  if($distinctCpms{$rv} > 1) {
    return undef;
  }

  return $rv;
}

#--------------------------------------------------------------------------------


sub usage {
  my $e = shift;
  if($e) {
    print STDERR $e . "\n";
  }
  print STDERR "usage:  spliceSiteTranscripts.pl --orgAbbrev=s --gusConfigFile=FILE --mode[load,delete]";
  exit;
}

1;
