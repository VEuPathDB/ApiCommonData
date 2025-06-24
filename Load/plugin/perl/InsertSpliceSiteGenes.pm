package ApiCommonData::Load::Plugin::InsertSpliceSiteGenes;
@ISA = qw(GUS::PluginMgr::Plugin);

use strict;

use lib "$ENV{GUS_HOME}/lib/perl";

use GUS::PluginMgr::Plugin;
use GUS::Model::ApiDB::SpliceSiteGenes;

use GUS::Community::GeneModelLocations;

use Bio::Location::Simple;
use Bio::SeqFeature::Collection;
use Bio::SeqFeature::Generic;

use CBIL::Bio::SequenceUtils;

use GUS::Model::ApiDB::PolyAGenes;
use GUS::Model::ApiDB::SpliceSiteGenes;

use Data::Dumper;

# ----------------------------------------------------------
# Load Arguments
# ----------------------------------------------------------

  my $argsDeclaration  =
    [
     stringArg({ name => 'genomeExtDbRlsSpec',
		 descr => 'ExtDbRls spec for the genome',
		 constraintFunc=> undef,
		 reqd  => 1,
		 isList => 0,
	       }),

     stringArg({ name => 'extDbRlsSpec',
		 descr => 'ExtDbRls spec for the splice site dataset',
		 constraintFunc=> undef,
		 reqd  => 1,
		 isList => 0,
	       }),

    ];


# ----------------------------------------------------------
# Documentation
# ----------------------------------------------------------

  my $description = <<DESCR;
DESCR

  my $purpose = <<PURPOSE;
PURPOSE

  my $purposeBrief = <<PURPOSEBRIEF;
Populate ApiDB.SpliceSiteGenes
PURPOSEBRIEF

  my $notes = <<NOTES;
NOTES

  my $tablesAffected = <<AFFECT;
ApiDB.OrganismProject
AFFECT

  my $tablesDependedOn = <<TABD;
TABD

  my $howToRestart = <<RESTART;
No restart provided. Undo and re-run.
RESTART

  my $failureCases = <<FAIL;
FAIL

  my $documentation = { purpose          => $purpose,
			purposeBrief     => $purposeBrief,
			tablesAffected   => $tablesAffected,
			tablesDependedOn => $tablesDependedOn,
			howToRestart     => $howToRestart,
			failureCases     => $failureCases,
			notes            => $notes
		      };


sub new {
  my ($class) = @_;
  my $self = {};
  bless($self, $class);

  $self->initialize ({ requiredDbVersion => 4,
			cvsRevision => '$Revision$',
			name => ref($self),
			argsDeclaration => $argsDeclaration,
			documentation => $documentation
		      });

  return $self;
}

sub run {
  my ($self) = @_;

my %stopCodons = (TAG => 1,
                  TAA => 1,
                  TGA => 1);

  my $totalTime;
  my $totalTimeStart = time();

  my $dbh = $self->getQueryHandle();

  my $verbose = $self->getArg('verbose');

  my $genomeExtDbRlsSpec = $self->getArg('genomeExtDbRlsSpec');
  my $genomeExtDbRlsId = $self->getExtDbRlsId($genomeExtDbRlsSpec);

  my $extDbRlsSpec = $self->getArg('extDbRlsSpec');
  my $extDbRlsId = $self->getExtDbRlsId($extDbRlsSpec);


  my $geneModelLocations = GUS::Community::GeneModelLocations->new($dbh, $genomeExtDbRlsId, 1, undef, undef, 1);

  my $sh = $dbh->prepare("select sequence from dots.splicednasequence where source_id = ?");

  my $genomicSeqSh = $dbh->prepare("select substr(s.sequence, ?, ?) as base from dots.nasequence s where s.source_id = ?");

  my ($spliceSiteCollections, $experimentType) = $self->makeSpliceSiteCollections($extDbRlsId);

  $self->log("Mapping Splice Sites to Transcripts...\n") if($verbose);

  my $codonLength = 3;
  my $logCount = 0;

  foreach my $geneSourceId (@{$geneModelLocations->getAllGeneIds()}) {

    my $geneHash = $geneModelLocations->getGeneModelHashFromGeneSourceId($geneSourceId);

    my $strand = $geneHash->{strand};

    my $minStart = defined $geneHash->{min_cds_start} ? $geneHash->{min_cds_start} : $geneHash->{start};
    my $maxEnd = defined $geneHash->{max_cds_end} ? $geneHash->{max_cds_end} : $geneHash->{end};

    my $sequenceSourceId = $geneHash->{sequence_source_id};
    my $naSequenceId = $geneHash->{na_sequence_id};

    my $lastEndMaxOrSeqStart = defined $geneHash->{last_cds_end_or_seq_start} ? $geneHash->{last_cds_end_or_seq_start} : $geneHash->{last_gene_end_or_seq_start};
    my $nextStartMinOrSeqEnd = defined $geneHash->{next_cds_start_or_seq_end} ? $geneHash->{next_cds_start_or_seq_end} : $geneHash->{next_gene_start_or_seq_end};

    my $biggestTranscript = {source_id => '', length => 0, atgloc => ''};

    next unless($maxEnd < $nextStartMinOrSeqEnd && $minStart > $lastEndMaxOrSeqStart); # SKIP where several genes overlap

    my $collection = $spliceSiteCollections->{$naSequenceId};
    next unless($collection);


    

    my ($subsetStart, $subsetEnd) = &findSubsetLocs($strand, $experimentType, $minStart, $maxEnd, $lastEndMaxOrSeqStart, $nextStartMinOrSeqEnd);


    my $collectionStrand;
    if($experimentType eq 'Splice Site') { # Spliced Leader
      $collectionStrand = $strand;
    }
    else {
      $collectionStrand = $strand * -1;
    }

    my @subset = $collection->features_in_range(-start => $subsetStart,
                                                -end => $subsetEnd,
                                                -strand => $collectionStrand,
                                                -strandmatch => 'strong', #only match features on the same strand
                                                -contain => 1);


    my (%atgLocations, %stopLocations);

    foreach my $transcriptSourceId (@{$geneModelLocations->getTranscriptIdsFromGeneSourceId($geneSourceId)}) {
      $sh->execute($transcriptSourceId);
      my ($transcriptSequence) = $sh->fetchrow_array();
      $sh->finish();
      next unless $transcriptSequence;

      my $transcriptSequenceLength = length($transcriptSequence);
      

      my $offset = 0;

      my $proteinIds = $geneModelLocations->getProteinIdsFromTranscriptSourceId($transcriptSourceId);
      if(scalar @$proteinIds > 0) {

        my $proteinSourceId = $proteinIds->[0]; # I can just take the first one because I'm only interested in the transcript
        
        my $transcriptToGenomicMapper = $geneModelLocations->getTranscriptToGenomicCoordMapper($proteinSourceId);      
        my $cdsToGenomicMapper = $geneModelLocations->getCdsToGenomicCoordMapper($proteinSourceId);      
        my $genomicToTranscriptMapper = $geneModelLocations->getGenomicToTranscriptCoordMapper($proteinSourceId);

        my $cdsGenomicLocation = $cdsToGenomicMapper->cds();
        my $cdsEndPos = $strand == -1 ? $cdsGenomicLocation->start : $cdsGenomicLocation->end;
        my $cdsStartPos = $strand == -1 ? $cdsGenomicLocation->end : $cdsGenomicLocation->start;

        $stopLocations{$cdsEndPos}++;

        # CDS end is my starting position
        my $cdsEndPosLoc = Bio::Location::Simple->new(
          -start => $cdsEndPos, 
          -end => $cdsEndPos,
          -strand => 1);


        if($biggestTranscript->{length} < $transcriptSequenceLength) {
          $biggestTranscript = {source_id => $transcriptSourceId, length => $transcriptSequenceLength, atgloc => $cdsStartPos};
        }


        my $threePrimeUtrLength = $transcriptSequenceLength - $genomicToTranscriptMapper->map($cdsEndPosLoc)->start(); # start and end are equal for cdsEndPosLoc
        $offset = $offset - $threePrimeUtrLength;

        while(length($transcriptSequence) + $offset > 0) {
          my $transcriptCursorEnd = length($transcriptSequence) + $offset;
          my $transcriptCursorStart = $transcriptCursorEnd - $codonLength + 1;

          $offset = $offset - $codonLength;

          my $codon = substr($transcriptSequence, $offset, $codonLength);

          if(lc($codon) eq 'atg') {

            my $transcriptCursorLoc = Bio::Location::Simple->new(
              -start => $transcriptCursorStart, 
              -end => $transcriptCursorEnd,
              -strand => 1);
            
            my $cursorGenomicLoc = $transcriptToGenomicMapper->map($transcriptCursorLoc);


            if($strand == -1) {
              $atgLocations{$cursorGenomicLoc->end()}++;
            }
            else {
              $atgLocations{$cursorGenomicLoc->start()}++;
            }
          }

        }

        my $transcriptGenomicLocation = $transcriptToGenomicMapper->cds();

        my ($genomicSeqStart, $genomicSeqLength);
        if($strand == -1) {
          $genomicSeqStart = $transcriptGenomicLocation->end() + 1;
          $genomicSeqLength = $nextStartMinOrSeqEnd - $transcriptGenomicLocation->end() - 1; # subtract 1 here because I don't want to include either the last or the first
        }
        else {
          $genomicSeqStart = $lastEndMaxOrSeqStart +1;
          $genomicSeqLength = $transcriptGenomicLocation->start - $lastEndMaxOrSeqStart - 1; # subtract 1 here because I don't want to include either the last or the first
        }

        next unless($genomicSeqLength > 0); # SKIP overlapping genes

        $genomicSeqSh->execute($genomicSeqStart, $genomicSeqLength, $sequenceSourceId);
        my ($genomicSequence) = $genomicSeqSh->fetchrow_array();
        $genomicSeqSh->finish();

        unless($genomicSequence) {
          print STDERR Dumper $geneHash;
          $self->error("Could not retrieve genomicSequence for $sequenceSourceId w/ start=$genomicSeqStart and length=$genomicSeqLength");
        }

        if($strand == -1) {
          $genomicSequence = CBIL::Bio::SequenceUtils::reverseComplementSequence($genomicSequence);
        }

        # reset offset
        $offset = 0;

        GS: while(length($genomicSequence) + $offset > 0) {
          my ($genomicSequenceCursorEnd, $genomicSequenceCursorStart);

          if($strand == -1) {
            $genomicSequenceCursorStart = $genomicSeqStart - $offset;
            $genomicSequenceCursorEnd = $genomicSequenceCursorStart + $codonLength - 1;
          }
          else {
            $genomicSequenceCursorEnd = length($genomicSequence) + $offset;
            $genomicSequenceCursorStart = $genomicSequenceCursorEnd - $codonLength + 1;
          }

          $offset = $offset - $codonLength;

          my $codon = substr($genomicSequence, $offset, $codonLength);

          last if($stopCodons{$codon});


          if(lc($codon) eq 'atg') {
            if($strand == -1) {
              $atgLocations{$genomicSequenceCursorEnd}++;
            }
            else {
              $atgLocations{$genomicSequenceCursorStart}++;
            }
          }
        }
      }
    }


    my $atgLocations = &sortHashKeysByStrand(\%atgLocations, $strand);
    my $stopLocations = &sortHashKeysByStrand(\%stopLocations, $strand);


    my (%maxCounts, %totalCounts, %countCounts);
    foreach my $feature (@subset) {
      my ($sample) = $feature->get_tag_values('sample');
      my ($count) = $feature->get_tag_values('count_per_million');

      my $spliceSiteType = $feature->primary_tag();

      $maxCounts{$spliceSiteType}{$sample} = $count if($count > $maxCounts{$spliceSiteType}{$sample});
      $totalCounts{$spliceSiteType}{$sample} += $count;
      $countCounts{$spliceSiteType}{$sample}{$count}++;
    }

#--------------------------------------------------------------------------------
# Finally we can associate the sl and polyA w/ the Gene
#--------------------------------------------------------------------------------

    foreach my $feature (@subset) {
      my $spliceSiteType = $feature->primary_tag();

      my ($sample) = $feature->get_tag_values('sample');
      my ($spliceSiteFeatureId) = $feature->get_tag_values('splice_site_feature_id');

      my ($count) = $feature->get_tag_values('count_per_million');

      my $isDominant;
      if($maxCounts{$spliceSiteType}{$sample} == $count && $countCounts{$spliceSiteType}{$sample}{$count} == 1) {
        $isDominant = 1;
      }
      my $percentFraction = ($count / $totalCounts{$spliceSiteType}{$sample}) * 100;


      if($spliceSiteType eq 'Splice Site') {
        my ($firstAtgLoc, $distToAtg) = &findFirstAtgLoc($feature->start(), $atgLocations , $strand);

        my ($annotAtgLoc, $distToAnnotAtg) = &findFirstAtgLoc($feature->start(), [$biggestTranscript->{atgloc}], $strand);


        my $gusSS = GUS::Model::ApiDB::SpliceSiteGenes->new({source_id => $geneSourceId,
                                                             protocol_app_node_id => $sample,
                                                             splice_site_feature_id => $spliceSiteFeatureId,
                                                             is_dominant => $isDominant,
                                                             percent_fraction => $percentFraction,
                                                             first_atg_location => $firstAtgLoc,
                                                             dist_to_first_atg => $distToAtg,
                                                             annot_atg_location => $annotAtgLoc,
                                                             dist_to_annot_atg => $distToAnnotAtg,
                                                            });


        $gusSS->submit();
      }

      if($spliceSiteType eq 'Poly A') {
        my ($distanceToStops, $hasPositiveDist) = &findStopDistances($feature->start(), $stopLocations, $strand);

        foreach my $distance (@$distanceToStops) {
          next if($distance <= 0 && $hasPositiveDist);

          my $withinCds = $distance > 0 ? 0 : 1;

          my $gusSS = GUS::Model::ApiDB::PolyAGenes->new({source_id => $geneSourceId,
                                                          protocol_app_node_id => $sample,
                                                          splice_site_feature_id => $spliceSiteFeatureId,
                                                          is_dominant => $isDominant,
                                                          percent_fraction => $percentFraction,
                                                          within_cds => $withinCds,
                                                          dist_to_cds => $distance,
                                                         });


          $gusSS->submit();
        }
      }

      $self->undefPointerCache();
    }

    if($logCount++ % 1000 == 0) {
      my $runTime = time() - $totalTimeStart;
      $self->log("Processed $logCount genes in $runTime seconds\n") ;
      $self->undefPointerCache();
    }
  }

}


sub findSubsetLocs{
  my ($strand, $experimentType, $geneStart, $geneEnd, $lastGeneEndOrSeqStart,$nextGeneStartOrSeqEnd ) = @_;

  if($strand == -1) {
    if($experimentType eq 'Splice Site') {
      return($geneStart, $nextGeneStartOrSeqEnd);
    }
    else {
      return($lastGeneEndOrSeqStart, $geneStart);
    }
  }
  else {
    if($experimentType eq 'Splice Site') {
      return($lastGeneEndOrSeqStart, $geneEnd);
    }
    else {
      return($geneEnd, $nextGeneStartOrSeqEnd);
    }

  }
}



sub findStopDistances {
  my ($loc, $stopLocations, $strand) = @_;

  return [] unless(scalar @$stopLocations > 0);

  my @distances;
  my $hasPositiveDistance;

  foreach my $stop (@$stopLocations) {
    my $dist;

    if($strand == -1) {
      $dist = $stop - $loc;
      push @distances, $dist;

    }
    else {
      $dist = $loc - $stop;
      push @distances, $dist;
    }

    if($dist > 0) {
      $hasPositiveDistance++;
    }
  }
  return(\@distances, $hasPositiveDistance);

}

sub sortHashKeysByStrand {
  my ($hash, $strand) = @_;

  my @rv = sort { 
    if($strand == -1) { 
      $b <=> $a;
    }
    else {
      $a <=> $b;
    }
  } keys %$hash;

  return \@rv;
}



sub makeSpliceSiteCollections {
  my ($self, $extDbRlsId) = @_;

  my $dbh = $self->getQueryHandle();
  my $verbose = $self->getArg('verbose');

  my $spliceSiteFeatureSh = $dbh->prepare("select distinct ssf.type
, ssf.splice_site_feature_id
, ssf.na_sequence_id
, ssf.segment_start
, ssf.strand
, ssf.count_per_million
, ssf.protocol_app_node_id
, ssf.is_unique 
from apidb.splicesitefeature ssf 
 , study.nodenodeset sl
 , study.nodeset s
where s.external_database_release_id = $extDbRlsId
and s.node_set_id = sl.node_set_id
and sl.protocol_app_node_id = ssf.protocol_app_node_id");

  $spliceSiteFeatureSh->execute();

  my %spliceSites;
  my %spliceSiteCollections;

  $self->log("Reading splice site features from database ...\n") if($verbose);

  my %experimentTypes;

  while(my ($ssType, $ssId, $ssNaSequenceId, $ssLoc, $ssStrand, $ssCount, $ssSample, $isUnique) = $spliceSiteFeatureSh->fetchrow_array()) {
    my $feature = Bio::SeqFeature::Generic->new(-start => $ssLoc, 
                                                -end => $ssLoc, 
                                                -strand => $ssStrand, 
                                                -primary_tag => $ssType, 
                                                -seq_id => $ssNaSequenceId, 
                                                -tag => {'sample' => $ssSample, 'is_unique' => $isUnique, 'splice_site_feature_id' => $ssId, 'count_per_million' => $ssCount}
        );

    push @{$spliceSites{$ssNaSequenceId}}, $feature;
    $experimentTypes{$ssType}++;
  }

  $spliceSiteFeatureSh->finish();

  $self->log("Building Collection object ...\n") if($verbose);
  foreach my $naSequenceId (keys %spliceSites) {
    my $collection = Bio::SeqFeature::Collection->new();
    $collection->add_features($spliceSites{$naSequenceId});

    $spliceSiteCollections{$naSequenceId} = $collection;
  }

  my @distinctExperimentTypes = keys %experimentTypes;
  $self->error("Cannot have more than one experiment type for this external_database_release_id ($extDbRlsId)") if(scalar(@distinctExperimentTypes) > 1);

  return(\%spliceSiteCollections, $distinctExperimentTypes[0]);
}



sub findFirstAtgLoc {
  my ($loc, $atgLocations, $strand) = @_;

  return unless(scalar @$atgLocations > 0);

  foreach my $atg (@$atgLocations) {
    if($strand == -1) {
      if($atg < $loc) {
        my $dist = $loc - $atg;
        return $atg, $dist;
      }
    }
    else {
      if($atg > $loc) {
        my $dist = $atg - $loc;
        return $atg, $dist;
      }
    }
  }
}


sub getExtDbRlsIdFromSpec {
  my ($dbh, $genomeExtDbRlsSpec) = @_;

  my ($name, $version) = split(/\|/, $genomeExtDbRlsSpec);

  my $sql = "select r.external_database_release_id 
from sres.externaldatabase d
   , sres.externaldatabaserelease r
where d.EXTERNAL_DATABASE_ID = r.EXTERNAL_DATABASE_ID
and d.name = ?
and r.version = ?";

  my $sh = $dbh->prepare($sql);
  $sh->execute($name, $version);

  my ($count, $rv);

  while(my ($id) = $sh->fetchrow_array()) {
    $rv =  $id;
    $count++;
  }

  $sh->finish();

  if($count != 1) {
    die "Could not find an external database release id for the spec $genomeExtDbRlsSpec";
  }

  return $rv;
}


sub undoTables {
  return ('ApiDB.SpliceSiteGenes', 
          'ApiDB.PolyAGenes',
           );
}
