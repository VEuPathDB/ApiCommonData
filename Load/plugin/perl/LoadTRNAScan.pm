package ApiCommonData::Load::Plugin::LoadTRNAScan;
@ISA = qw(GUS::PluginMgr::Plugin);

use strict;
use warnings;

use GUS::PluginMgr::Plugin;


use GUS::Model::DoTS::ExternalNASequence;
use GUS::Model::DoTS::GeneFeature;
use GUS::Model::DoTS::ExonFeature;
use GUS::Model::DoTS::Transcript;
use GUS::Model::DoTS::NALocation;
use GUS::Model::DoTS::RNAType;
use GUS::Model::SRes::SequenceOntology;
use ApiCommonData::Load::Util;

# ----------------------------------------------------------
# Load Arguments
# ----------------------------------------------------------

sub getArgsDeclaration {
  my $argsDeclaration  =
    [
     fileArg({ name => 'data_file',
	       descr => 'text file containing output of tRNAScan',
	       constraintFunc=> undef,
	       reqd  => 1,
	       isList => 0,
	       mustExist => 1,
	       format=>'Text'
	     }),
     stringArg({ name => 'scanDbName',
		 descr => 'externaldatabase name for the tRNAScan used to create the data file',
		 constraintFunc=> undef,
		 reqd  => 1,
		 isList => 0
	       }),
     stringArg({ name => 'scanDbVer',
		 descr => 'externaldatabaserelease version used for the tRNAScan used to create the dta file',
		 constraintFunc=> undef,
		 reqd  => 1,
		 isList => 0
	       }),
     stringArg({ name => 'genomeDbName',
		 descr => 'externaldatabase name for genome sequences scanned',
		 constraintFunc=> undef,
		 reqd  => 1,
		 isList => 0
	       }),
     stringArg({ name => 'genomeDbVer',
		 descr => 'externaldatabaserelease version used for genome sequences scanned',
		 constraintFunc=> undef,
		 reqd  => 1,
		 isList => 0
	       }),
     stringArg({ name => 'soVersion',
		 descr => 'version of Sequence Ontology to use',
		 constraintFunc => undef,
		 reqd => 1,
		 isList => 0,
	       }),
     stringArg({ name => 'seqTable',
		 descr => 'table where we can find the na sequences to map the tRNA predictions to',
		 constraintFunc => undef,
		 reqd => 0,
		 isList => 0,
		 enum => "DoTS::ExternalNASequence, DoTS::VirtualSequence",
		 default => "DoTS::ExternalNASequence",
	       })
    ];

  return $argsDeclaration;
}


# ----------------------------------------------------------
# Documentation
# ----------------------------------------------------------

sub getDocumentation {

  my $description = <<DESCR;
Application to load output of tRNAScan-SE
DESCR

  my $purpose = <<PURPOSE;
Parse tRNAScan-SE output and load the results into GUS
PURPOSE

  my $purposeBrief = <<PURPOSEBRIEF;
Load tRNAScan
PURPOSEBRIEF

  my $notes = <<NOTES;
Example of tRNAScan_SE output
Sequence                tRNA    Bounds  tRNA    Anti    Intron Bounds   Cove
Name            tRNA #  Begin   End     Type    Codon   Begin   End     Score
--------        ------  ----    ------  ----    -----   -----   ----    ------
PB_PH0733       1       206     278     Pseudo  GCT     0       0       22.82
NOTES

  my $tablesAffected = <<AFFECT;
DoTS.GeneFeature,DoTS.Transcript,DoTS.ExonFeature,DoTS.NALoacation,DoTS.RNAType
AFFECT

  my $tablesDependedOn = <<TABD;
DoTS.ExternalNASequence or DoTS.VirtualSequence,SRes.ExternalDatabase,SRes.ExternalDatabaseRelease
TABD

  my $howToRestart = <<RESTART;
No restart provided. Must undo and reload.
RESTART

  my $failureCases = <<FAIL;
Will fail if db_id, db_rel_id for either the tRNAScan or the genome scanned are absent and when a source_id is not in one of the DoTS.ExternalNASequence or DoTS.VirtualSequence tables
FAIL

  my $documentation = { purpose          => $purpose,
			purposeBrief     => $purposeBrief,
			tablesAffected   => $tablesAffected,
			tablesDependedOn => $tablesDependedOn,
			howToRestart     => $howToRestart,
			failureCases     => $failureCases,
			notes            => $notes
		      };

  return ($documentation);

}


sub new {
  my $class = shift;
  my $self = {};
  bless($self, $class);

  my $documentation = &getDocumentation();

  my $args = &getArgsDeclaration();

  my $configuration = { requiredDbVersion => 3.5,
			cvsRevision => '$Revision$',
			name => ref($self),
			argsDeclaration => $args,
			documentation => $documentation
		      };

  $self->initialize($configuration);

  return $self;
}

sub run {
  my $self = shift;

  my $scanReleaseId = $self->getExtDbRlsId($self->getArg('scanDbName'),
					       $self->getArg('scanDbVer')) || $self->error("Can't find db_rel_id for tRNAScan");

  my $genomeReleaseId = $self->getExtDbRlsId($self->getArg('genomeDbName'),
						 $self->getArg('genomeDbVer')) || $self->error("Can't find db_el_id for genome");

  my $rnaId = $self->getSoId("tRNA_encoding") || $self->error ("Can't retrieve so_id for tRNA_gene");

  my $primTransc = $self->getSoId("transcript") || $self->error ("Can't retrieve so_id for transcript");

  my $exon = $self->getSoId("exon") || $self->error ("Can't retrieve so_id for exon");

  my $procTransc = $self->getSoId("processed_transcript") || $self->error ("Can't retrieve so_id for processed_transcript");

  my %soIds = ('geneFeat' => $rnaId,
	       'transcript' => $primTransc,
	       'exonFeat' => $exon,
	       'procTransc' => $procTransc
	      );

  my $tRNAs = $self->parseFile();

  my $result = $self->loadScanData($scanReleaseId,$genomeReleaseId,$tRNAs,\%soIds);

  return "$result tRNAScan results parsed and loaded";
}

sub getSoId {
  my ($self,$termName) = @_;

  my $soVersion = $self->getArg('soVersion');

  my $so =  GUS::Model::SRes::SequenceOntology->new({'term_name' => $termName,
						     'so_version' => $soVersion });
  $so->retrieveFromDB();

  my $soId = $so->getId();

  $self->undefPointerCache();

  return $soId;
}

sub parseFile {
  my ($self) = @_;

  my $dataFile = $self->getArg('data_file');

  open(FILE,$dataFile) || $self->error("$dataFile can't be opened for reading");

  my %tRNAs;

  my %num;

  while(<FILE>){
    chomp;

    if ($_ =~ /^Sequence|^Name|^---|^\s+$/){next;}

    my @line = split(/\t/,$_);

    my $seqSourceId = $line[0];

    $seqSourceId =~ s/\s//g;

    my $tRNAType = $line[4];

    my $start = $line[2] > $line[3] ? $line[3] : $line[2];

    my $end = $line[2] > $line[3] ? $line[2] : $line[3];

    my ($intronStart,$intronEnd);

    if ($line[6] && $line[7]) {

      $intronStart = $line[2] > $line[3] ? $line[7] : $line[6];

      $intronEnd = $line[2] > $line[3] ? $line[6] : $line[7];
    }

    my $score = $line[8];

    my $anticodon = $line[5];

    my $isReversed = ($line[2] > $line[3]) ? 1 : 0;

    $num{$seqSourceId}{$tRNAType}++;

    my $number = $num{$seqSourceId}{$tRNAType};

    $tRNAs{$seqSourceId}{"$tRNAType$number"}={'start'=>$start,'end'=>$end,'intronStart'=>$intronStart,'intronEnd'=>$intronEnd,'score'=>$score,'anticodon'=>$anticodon,'isReversed'=>$isReversed};
  }

  return \%tRNAs;
}

sub loadScanData {
  my ($self,$scanReleaseId,$genomeReleaseId,$tRNAs,$soIds) = @_;
  my $processed;

  my $seqTable = $self->getArg('seqTable');

  foreach my $seqSourceId (keys %{$tRNAs}) {
    my $extNaSeq = $self->getExtNASeq($genomeReleaseId,$seqSourceId,$seqTable);

    foreach my $tRNA (keys %{$tRNAs->{$seqSourceId}}) {
      $self->getGeneFeat($scanReleaseId,$soIds,$seqSourceId,$tRNA,$tRNAs,$extNaSeq);
    }

    $processed++;

#MAY NEED TO SUBMIT THE SPLICEDNASEQUENCE AS WELL
    $extNaSeq->submit();
    $self->undefPointerCache();
  }

  return $processed;
}

sub getExtNASeq {
  my ($self,$genomeReleaseId,$seqSourceId,$table) = @_;

  my $seqTable = "GUS::Model::$table";
  eval "require $seqTable";

  my $extNaSeq = $seqTable->new({'external_database_release_id' => $genomeReleaseId,
							     'source_id' => $seqSourceId });
  $extNaSeq->retrieveFromDB() || die "Sequence '$seqSourceId' not found with extDbRlsId = $genomeReleaseId in table '$seqTable'\n";

  return $extNaSeq;
}

sub getGeneFeat {
  my ($self,$scanReleaseId,$soIds,$seqSourceId,$tRNA,$tRNAs,$extNaSeq) = @_;

  my $isPseudo = ($tRNA =~ /Pseudo/) ? 1 : 0;

  my $product = $tRNA;

  $product =~ s/\d//g;

  my $sourceId = "${seqSourceId}_tRNA_$tRNA";

  $sourceId =~ s/\s//g;

  my $geneFeat = GUS::Model::DoTS::GeneFeature->new({'name' => "tRNA_encoding",
						     'sequence_ontology_id' => $soIds->{'geneFeat'},
						     'external_database_release_id' => $scanReleaseId,
						     'source_id' => $sourceId,
						     'is_predicted' => 1,
						     'score' => $tRNAs->{$seqSourceId}->{$tRNA}->{'score'},
						     'is_pseudo' => $isPseudo,
						     'product' => "tRNA $product"});

  $geneFeat->retrieveFromDB();

  $extNaSeq->addChild($geneFeat);

  my $start = $tRNAs->{$seqSourceId}->{$tRNA}->{'start'};

  my $end = $tRNAs->{$seqSourceId}->{$tRNA}->{'end'};

  my $isReversed = $tRNAs->{$seqSourceId}->{$tRNA}->{'isReversed'};

  my $naLoc = $self->getNaLocation($start,$end,$isReversed);

  $geneFeat->addChild($naLoc);

  my $transcript = $self->getTranscript($seqSourceId,$tRNAs,$scanReleaseId,$soIds,$tRNA,$extNaSeq,$isPseudo,$product,$sourceId, $geneFeat);

}

sub getTranscript {
  my ($self,$seqSourceId,$tRNAs,$scanReleaseId,$soIds,$tRNA,$extNaSeq,$isPseudo,$product,$sourceId, $geneFeat) = @_;

  $sourceId .= "-1";

  my $transcript = GUS::Model::DoTS::Transcript->new({'name' => "transcript",
						      'sequence_ontology_id' => $soIds->{'transcript'},
						      'external_database_release_id' => $scanReleaseId,
						      'source_id' => $sourceId,
						      'is_predicted' => 1,
						      'is_pseudo' => $isPseudo,
						      'product' => "tRNA $product"});

  $transcript->retrieveFromDB();

  $geneFeat->addChild($transcript);

  my $rnaType = $self->getRNAType($tRNAs->{$seqSourceId}->{$tRNA}->{'anticodon'});

  $transcript->addChild($rnaType);

  my $exonFeats = $self->getExonFeats($soIds,$scanReleaseId,$seqSourceId,$tRNA,$tRNAs,$extNaSeq);

  foreach my $exon (@{$exonFeats}) {
    my $rnaFeatureExon = GUS::Model::DoTS::RNAFeatureExon->new();
    $rnaFeatureExon->setParent($transcript);
    $rnaFeatureExon->setParent($exon);

    $exon->setParent($geneFeat);
  }

  my $start = $tRNAs->{$seqSourceId}->{$tRNA}->{'start'};

  my $end = $tRNAs->{$seqSourceId}->{$tRNA}->{'end'};

  my $isReversed = $tRNAs->{$seqSourceId}->{$tRNA}->{'isReversed'};

  my $naLoc = $self->getNaLocation($start,$end,$isReversed);

  $transcript->addChild($naLoc);

  my $taxonId = $extNaSeq->getTaxonId();

  my $transcriptSeq = $self->getTranscriptSeq($exonFeats, $taxonId, $scanReleaseId, $soIds);

  $transcriptSeq->addChild($transcript);

  return $transcript;
}


sub getRNAType {
  my ($self,$anticodon) = @_;

  my $rnaType = GUS::Model::DoTS::RNAType->new({'anticodon' => $anticodon,
						'name' => "auxiliary info"});

  return $rnaType;
}

sub getExonFeats {
  my ($self,$soIds,$scanReleaseId,$seqSourceId,$tRNA,$tRNAs,$extNaSeq) = @_;

  my $exon;
  my $orderNum;

  my @exons;

  if ($tRNAs->{$seqSourceId}->{$tRNA}->{'intronStart'}) {
    $orderNum = $tRNAs->{$seqSourceId}->{$tRNA}->{'isReversed'} == 1 ? 2 : 1;

    $exon = $self->makeExonFeat($seqSourceId,$soIds,$orderNum,$scanReleaseId,$tRNAs->{$seqSourceId}->{$tRNA}->{'start'},$tRNAs->{$seqSourceId}->{$tRNA}->{'intronStart'},$tRNAs->{$seqSourceId}->{$tRNA}->{'isReversed'});

    $extNaSeq->addChild($exon);

    push (@exons,$exon);

    $orderNum = $tRNAs->{$seqSourceId}->{$tRNA}->{'isReversed'} == 1 ? 1 : 2;

    $exon = $self->makeExonFeat($seqSourceId,$soIds,$orderNum,$scanReleaseId,$tRNAs->{$seqSourceId}->{$tRNA}->{'intronEnd'},$tRNAs->{$seqSourceId}->{$tRNA}->{'end'},$tRNAs->{$seqSourceId}->{$tRNA}->{'isReversed'});

    $extNaSeq->addChild($exon);

    push (@exons,$exon);
  }
  else {
    $orderNum = $tRNAs->{$seqSourceId}->{$tRNA}->{'isReversed'} == 1 ? 2 : 1;

    $exon = $self->makeExonFeat($seqSourceId,$soIds,$orderNum,$scanReleaseId,$tRNAs->{$seqSourceId}->{$tRNA}->{'start'},$tRNAs->{$seqSourceId}->{$tRNA}->{'end'},$tRNAs->{$seqSourceId}->{$tRNA}->{'isReversed'});

    $extNaSeq->addChild($exon);

    push (@exons,$exon);
  }

  return \@exons;
}

sub makeExonFeat {
  my ($self,$seqSourceId,$soIds,$orderNum,$scanReleaseId,$start,$end,$isReversed) = @_;

  $seqSourceId = "${seqSourceId}-1-$orderNum";

  my $codingStart = $isReversed ? $end : $start;
  my $codingEnd = $isReversed ? $start : $end;

  my $exon = GUS::Model::DoTS::ExonFeature->new({'name' => "exon",
						 'source_id' => $seqSourceId,
						 'sequence_ontology_id' => $soIds->{'exonFeat'},
						 'order_number' => $orderNum,
						 'coding_start' => $codingStart,
						 'coding_end' => $codingEnd,
						 'external_database_release_id' => $scanReleaseId});

  my $naLoc = $self->getNaLocation($start,$end,$isReversed);

  $exon->addChild($naLoc);

  return $exon;
}

sub getNaLocation {
  my ($self,$start,$end,$isReversed) = @_;

  my $naLoc = GUS::Model::DoTS::NALocation->new({'start_min' => $start,
						 'start_max' => $start,
						 'end_min' => $end,
						 'end_max' => $end,
						 'is_reversed' => $isReversed});

  return $naLoc;
}

sub getTranscriptSeq{
  my ($self, $exonFeats, $taxonId, $scanReleaseId, $soIds) = @_;

  my $transcriptNaSeq =
    GUS::Model::DoTS::SplicedNASequence->new({sequence_ontology_id => $soIds->{'procTransc'},
                                              sequence_version => 1,
                                              taxon_id => $taxonId,
                                              external_database_release_id => $scanReleaseId
                                             });

  my $transcriptSeq = ApiCommonData::Load::Util::getCodingSequenceFromExons($exonFeats);


  $transcriptNaSeq->setSequence($transcriptSeq);

  return $transcriptNaSeq;
}


sub undoTables {
  return ('DoTS.NALocation',
	  'DoTS.RnaFeatureExon',
	  'DoTS.RNAType',
	  'DoTS.Transcript',
	  'DoTS.SplicedNASequence',
	  'DoTS.ExonFeature',
	  'DoTS.GeneFeature'
	 );
}
