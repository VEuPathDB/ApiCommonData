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

  my $spliceSiteCollections = $self->makeSpliceSiteCollections($extDbRlsId);

  $self->log("Mapping Splice Sites to Transcripts...\n") if($verbose);

  my $codonLength = 3;
  my $logCount = 0;

  foreach my $geneSourceId (@{$geneModelLocations->getAllGeneIds()}) {
    my $geneHash = $geneModelLocations->getGeneModelHashFromGeneSourceId($geneSourceId);

    my $strand = $geneHash->{strand};
    my $sequenceSourceId = $geneHash->{sequence_source_id};
    my $naSequenceId = $geneHash->{na_sequence_id};

    my $lastGeneEndOrSeqStart = $geneHash->{last_gene_end_or_seq_start};
    my $nextGeneStartOrSeqEnd = $geneHash->{next_gene_start_or_seq_end};

    next unless($nextGeneStartOrSeqEnd > $lastGeneEndOrSeqStart); # SKIP where several genes overlap

    my $collection = $spliceSiteCollections->{$naSequenceId};
    next unless($collection);

    my @subset = $collection->features_in_range(-start => $lastGeneEndOrSeqStart,
                                                -end => $nextGeneStartOrSeqEnd,
                                                -strand => $strand,
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

        $stopLocations{$cdsEndPos}++;

        # CDS end is my starting position
        my $cdsEndPosLoc = Bio::Location::Simple->new(
          -start => $cdsEndPos, 
          -end => $cdsEndPos,
          -strand => 1);

        # calc cds end in transcript coords
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
          $genomicSeqLength = $nextGeneStartOrSeqEnd - $transcriptGenomicLocation->end() - 1; # subtract 1 here because I don't want to include either the last or the first
        }
        else {
          $genomicSeqStart = $lastGeneEndOrSeqStart +1;
          $genomicSeqLength = $transcriptGenomicLocation->start - $lastGeneEndOrSeqStart - 1; # subtract 1 here because I don't want to include either the last or the first
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

        while(length($genomicSequence) + $offset > 0) {
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

          if(lc($codon) eq 'atg') {

            my $genomicSequenceLoc = Bio::Location::Simple->new(
              -start => $genomicSequenceCursorStart,
              -end => $genomicSequenceCursorEnd,
              -strand => 1);


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


    my (%maxCounts, %totalCounts);
    foreach my $feature (@subset) {
      my ($sample) = $feature->get_tag_values('sample');
      my ($count) = $feature->get_tag_values('count_per_million');

      my $spliceSiteType = $feature->primary_tag();

      $maxCounts{$spliceSiteType}{$sample} = $count if($count > $maxCounts{$spliceSiteType}{$sample});
      $totalCounts{$spliceSiteType}{$sample} += $count;
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
      if($maxCounts{$spliceSiteType}{$sample} == $count) {
        $isDominant = 1;
      }
      my $percentFraction = ($count / $totalCounts{$spliceSiteType}{$sample}) * 100;


      if($spliceSiteType eq 'Splice Site') {
        my ($firstAtgLoc, $distToAtg) = &findFirstAtgLoc($feature->start(), $atgLocations , $strand);

        my $gusSS = GUS::Model::ApiDB::SpliceSiteGenes->new({source_id => $geneSourceId,
                                                             protocol_app_node_id => $sample,
                                                             splice_site_feature_id => $spliceSiteFeatureId,
                                                             is_dominant => $isDominant,
                                                             percent_fraction => $percentFraction,
                                                             first_atg_location => $firstAtgLoc,
                                                             dist_to_first_atg => $distToAtg
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
    }


    if($logCount++ % 1000 == 0) {
      my $runTime = time() - $totalTimeStart;
      $self->log("Processed $logCount genes in $runTime seconds\n") ;
      $self->undefPointerCache();
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
      $dist = $stop - $loc + 1;
      push @distances, $dist;

    }
    else {
      $dist = $loc - $stop + 1;
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
 , study.studylink sl
 , study.study s
where s.external_database_release_id = $extDbRlsId
and s.study_id = sl.study_id
and sl.protocol_app_node_id = ssf.protocol_app_node_id");

  $spliceSiteFeatureSh->execute();

  my %spliceSites;
  my %spliceSiteCollections;

  $self->log("Reading splice site features from database ...\n") if($verbose);


  while(my ($ssType, $ssId, $ssNaSequenceId, $ssLoc, $ssStrand, $ssCount, $ssSample, $isUnique) = $spliceSiteFeatureSh->fetchrow_array()) {
    my $feature = Bio::SeqFeature::Generic->new(-start => $ssLoc, 
                                                -end => $ssLoc, 
                                                -strand => $ssStrand, 
                                                -primary_tag => $ssType, 
                                                -seq_id => $ssNaSequenceId, 
                                                -tag => {'sample' => $ssSample, 'is_unique' => $isUnique, 'splice_site_feature_id' => $ssId, 'count_per_million' => $ssCount}
        );

    push @{$spliceSites{$ssNaSequenceId}}, $feature;
  }

  $spliceSiteFeatureSh->finish();

  $self->log("Building Collection object ...\n") if($verbose);
  foreach my $naSequenceId (keys %spliceSites) {
    my $collection = Bio::SeqFeature::Collection->new();
    $collection->add_features($spliceSites{$naSequenceId});

    $spliceSiteCollections{$naSequenceId} = $collection;
  }

  return \%spliceSiteCollections;
}



sub findFirstAtgLoc {
  my ($loc, $atgLocations, $strand) = @_;

  return unless(scalar @$atgLocations > 0);

  foreach my $atg (@$atgLocations) {
    if($strand == -1) {
      if($atg < $loc) {
        my $dist = $loc - $atg + 1;
        return $atg, $dist;
      }
    }
    else {
      if($atg > $loc) {
        my $dist = $atg - $loc + 1;
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
  return qw(ApiDB.SpliceSiteGenes
           );
}
