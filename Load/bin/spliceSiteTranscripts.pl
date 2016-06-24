#!/usr/bin/perl

use strict;

use lib "$ENV{GUS_HOME}/lib/perl";
use Getopt::Long;

use GUS::ObjRelP::DbiDatabase;
use CBIL::Util::PropertySet;

use GUS::Community::GeneModelLocations;
use Bio::Location::Simple;

use CBIL::Bio::SequenceUtils;

use Data::Dumper;

my ($gusConfigFile,$verbose,$outFile,$project,$genomeExtDbRlsSpec, $cdsOnly, $soTermName);
&GetOptions("verbose!"=> \$verbose,
            "gusConfigFile=s" => \$gusConfigFile,
            "genomeExtDbRlsSpec=s" => \$genomeExtDbRlsSpec,

    ); 


if(!$gusConfigFile) {
  $gusConfigFile = $ENV{GUS_HOME} . "/config/gus.config";
}

my @properties = ();

print STDERR "Establishing dbi login\n" if $verbose;
die "Config file $gusConfigFile does not exist." unless -e $gusConfigFile;

my $gusconfig = CBIL::Util::PropertySet->new($gusConfigFile, \@properties, 1);

my $db = GUS::ObjRelP::DbiDatabase->new($gusconfig->{props}->{dbiDsn},
                                        $gusconfig->{props}->{databaseLogin},
                                        $gusconfig->{props}->{databasePassword},
					$verbose,0,1,
					$gusconfig->{props}->{coreSchemaName},
				       );

my $dbh = $db->getQueryHandle();

my $genomeExtDbRlsId = &getExtDbRlsIdFromSpec($dbh, $genomeExtDbRlsSpec);

my $geneModelLocations = GUS::Community::GeneModelLocations->new($dbh, $genomeExtDbRlsId, 1, undef, undef, 1);

my $sh = $dbh->prepare("select sequence from dots.splicednasequence where source_id = ?");

my $genomicSeqSh = $dbh->prepare("select substr(s.sequence, ?, ?) as base from dots.nasequence s where s.source_id = ?");

my $codonLength = 3;

foreach my $geneSourceId (@{$geneModelLocations->getAllGeneIds()}) {
  next unless($geneSourceId eq 'PF3D7_0905700');

  my $geneHash = $geneModelLocations->getGeneModelHashFromGeneSourceId($geneSourceId);

  my $strand = $geneHash->{strand};
  my $sequenceSourceId = $geneHash->{sequence_source_id};
  my $lastGeneEndOrSeqStart = $geneHash->{last_gene_end_or_seq_start};
  my $nextGeneStartOrSeqEnd = $geneHash->{next_gene_start_or_seq_end};

  print STDERR "LAST=$lastGeneEndOrSeqStart\n";
  print STDERR "FIRST=$nextGeneStartOrSeqEnd\n";

  foreach my $transcriptSourceId (@{$geneModelLocations->getTranscriptIdsFromGeneSourceId($geneSourceId)}) {

    print STDERR "TRANSCRIPT=$transcriptSourceId\n";

    $sh->execute($transcriptSourceId);
    my ($transcriptSequence) = $sh->fetchrow_array();
    $sh->finish();
    next unless $transcriptSequence;

    my $transcriptSequenceLength = length($transcriptSequence);

    my @atgLocations;
    my $offset = 0;

    if(my $proteinIds = $geneModelLocations->getProteinIdsFromTranscriptSourceId($transcriptSourceId)) {

      my $proteinSourceId = $proteinIds->[0]; # I can just take the first one because I'm only interested in the transcript
      
      my $transcriptToGenomicMapper = $geneModelLocations->getTranscriptToGenomicCoordMapper($proteinSourceId);      
      my $cdsToGenomicMapper = $geneModelLocations->getCdsToGenomicCoordMapper($proteinSourceId);      
      my $genomicToTranscriptMapper = $geneModelLocations->getGenomicToTranscriptCoordMapper($proteinSourceId);

      my $cdsGenomicLocation = $cdsToGenomicMapper->cds();
      my $cdsEndPos = $strand == -1 ? $cdsGenomicLocation->start : $cdsGenomicLocation->end;

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

        my $transcriptCursorLoc = Bio::Location::Simple->new(
                                            -start => $transcriptCursorStart, 
                                            -end => $transcriptCursorEnd,
                                            -strand => 1);

        my $cursorGenomicLoc = $transcriptToGenomicMapper->map($transcriptCursorLoc);

        my $leaderFeatures = &overlappingLeaderFeatures($sequenceSourceId, $cursorGenomicLoc->start() , $cursorGenomicLoc->end());

        if(lc($codon) eq 'atg') {
          if($strand == -1) {
            push @atgLocations, $cursorGenomicLoc->end();
          }
          else {
            push @atgLocations, $cursorGenomicLoc->start();
          }
        }

      }

      my $transcriptGenomicLocation = $transcriptToGenomicMapper->cds();
      print Dumper $transcriptGenomicLocation;

      my ($genomicSeqStart, $genomicSeqLength);
      if($strand == -1) {
        $genomicSeqStart = $transcriptGenomicLocation->end() + 1;
        $genomicSeqLength = $nextGeneStartOrSeqEnd - $transcriptGenomicLocation->end() - 1; # subtract 1 here because I don't want to include either the last or the first
      }
      else {
        $genomicSeqStart = $lastGeneEndOrSeqStart +1;
        $genomicSeqLength = $transcriptGenomicLocation->start - $lastGeneEndOrSeqStart - 1; # subtract 1 here because I don't want to include either the last or the first
      }

      print STDERR "SeqStart=$genomicSeqStart\tSeqLength=$genomicSeqLength\n";

      $genomicSeqSh->execute($genomicSeqStart, $genomicSeqLength, $sequenceSourceId);
      my ($genomicSequence) = $genomicSeqSh->fetchrow_array();
      $genomicSeqSh->finish();
      die "Could not retrieve genomicSequence for $sequenceSourceId w/ start=$genomicSeqStart and length=$genomicSeqLength" unless $genomicSequence;

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
          $genomicSequenceCursorStart = $genomicCursorEnd - $codonLength + 1;
        }

        $offset = $offset - $codonLength;

        my $codon = substr($genomicSequence, $offset, $codonLength);

        my $leaderFeatures = &overlappingLeaderFeatures($sequenceSourceId, $genomicSequenceCursorStart , $genomicSequenceCursorEnd);

        if(lc($codon) eq 'atg') {
          if($strand == -1) {
            push @atgLocations, $genomicSequenceCursorEnd;
          }
          else {
            push @atgLocations, $genomicSequenceCursorStart;
          }
        }
      }
    }
  }
}


$db->logout();


sub overlappingLeaderFeatures {
  my ($sequenceSourceId, $start , $end) = @_;

  


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
