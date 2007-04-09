package ApiCommonData::Load::Plugin::InsertMascotSummaries;


@ISA = qw(GUS::PluginMgr::Plugin);

use strict;
use File::Find;
use FileHandle;

use GUS::PluginMgr::Plugin;

# read from
use GUS::Model::DoTS::Transcript;
use GUS::Model::DoTS::GeneFeature;
use GUS::Model::DoTS::Miscellaneous;
use GUS::Model::DoTS::TranslatedAASequence;
use GUS::Model::DoTS::TranslatedAAFeature;
use GUS::Model::SRes::SequenceOntology;

# write to
use GUS::Model::DoTS::AALocation;
use GUS::Model::DoTS::NALocation;
use GUS::Model::DoTS::MassSpecFeature;
use GUS::Model::ApiDB::MassSpecSummary;
use GUS::Model::DoTS::NAFeature;

# utility
use Bio::Location::Split;
use Bio::Location::Simple;
use Bio::Coordinate::GeneMapper;

# debugging
use Data::Dumper;

sub new {
    my ($class) = @_;
    my $self = {};
    bless($self, $class);

    $self->initialize({
        requiredDbVersion => 3.5,
        cvsRevision       => '$Revision$',
        name              => ref($self),
        argsDeclaration   => declareArgs(),
        documentation     => getDocumentation(),
    });
    return $self;
}

sub run {
    my ($self) = @_;
    $self->{featuresAdded} = $self->{summariesAdded} = $self->{summariesSkipped} = 0;
    
    my $inputFile = $self->getArg('inputFile');    
    my $record = {};
    my $recordSet = [];
    my $mss;
    
    $self->{extDbRlsId} = $self->getExtDbRlsId($self->getArg('externalDatabaseSpec'));

    open(F, $inputFile) or die "Could not open $inputFile: $!\n";
    while (<F>) {
        chomp;
        next if m/^\s*$/;
        if (m/^# /) {
            chomp(my $ln = <F>);
            undef $record;
            $record = $self->initRecord($ln);
            if ( ! $record->{naFeatureId}) {
                warn "'$record->{proteinId}' ",
                     &{sub{"or '$record->{description}' " if ($record->{description})}},
                     &{sub{"from '$record->{sourcefile}' " if ($record->{sourcefile})}},
                     "not found, skipping\n" if  $self->getArg('veryVerbose');
                $self->{summariesSkipped}++;
                $self->nextRecord(*F);
                next;
            }
            push @{$recordSet}, $record;
        } else {
            m/^## / and next;
            $self->addMassSpecFeatureToRecord($_, $record);
        }
    }

    $self->convertOrfRecordsToGenes($recordSet);

    $self->insertRecordsIntoDb($recordSet);    

    $self->setResultDescr(<<"EOF");
    
Added $self->{featuresAdded} @{[ ($self->{featuresAdded} == 1) ? 'feature':'features' ]} and $self->{summariesAdded} @{[ ($self->{summariesAdded} == 1) ? 'summary':'summaries' ]}.
Skipped $self->{summariesSkipped} @{[ ($self->{summariesSkipped} == 1) ? 'summary':'summaries' ]}.
EOF
}

sub initRecord {
    my ($self, $ln, $record) = @_;
    
    ( $record->{proteinId},
      $record->{description},
      $record->{seqMolWt},
      $record->{seqPI},
      $record->{score},
      $record->{percentCoverage},
      $record->{spanCount},
      $record->{spectrumCount},
      $record->{sourcefile},
    ) = split "\t", $ln;
    # Try looking up a proper source_id and na_sequence_id. Mascot datasets
    # may contain matches to proteins for which we don't have records (and
    # therefore no na_feature_id) - we skip those.
    ($record->{sourceId}, $record->{naFeatureId}) = 
        $self->getSourceIdAndNaFeatureId($record->{proteinId}, 
                                         $record->{description});

    ($record->{aaSequenceId}) = 
        $self->getAaSequenceId($record->{naFeatureId});

    return $record;
}

sub getSourceIdAndNaFeatureId {
    my ($self, @candidate_ids) = @_;
    
    # in a hetergeneous data set (old Wastling data for example)
    # we need to fish for the correct record, if any.
    my $sth = $self->getQueryHandle()->prepare(<<"EOSQL");
        select m.source_id, m.na_feature_id
        from dots.miscellaneous m
        where (m.source_id = ?
           or  m.source_id = ?
           or  m.source_id like ?
           or  m.source_id like ?)
        union
        select g.source_id, taf.na_feature_id
        from dots.translatedaafeature taf,
             dots.genefeature g,
             dots.transcript t
        where taf.na_feature_id = t.na_feature_id
          and t.parent_id = g.na_feature_id 
          and (g.source_id  = ?
           or  g.source_id  = ?
           or  t.protein_id = ?
           or  t.protein_id = ?)
EOSQL

    $sth->execute(
        $candidate_ids[0], $candidate_ids[1], # look for orf by source_id
        ($candidate_ids[0]) ? $candidate_ids[0].'%' : '', # orf id may be
        ($candidate_ids[1]) ? $candidate_ids[1].'%' : '', # truncated a little
        $candidate_ids[0], $candidate_ids[1], # look for gene by source_id
        $candidate_ids[0], $candidate_ids[1], # look for gene by protein_id
    );
    
    my $res = $sth->fetchall_arrayref();
    
    if (scalar @{$res} > 1) {
      warn "$candidate_ids[0] returns more than one row. This protein will be skipped.\n"
    }
    
    return undef if (scalar @{$res} != 1);

    return ($res->[0]->[0], $res->[0]->[1]);
}

sub getAaSequenceId {
    my ($self, $naFeatureId) = @_;
    my $transcript = GUS::Model::DoTS::Transcript->new({ na_feature_id => $naFeatureId});
    unless ($transcript->retrieveFromDB()) {
      my $transcript = GUS::Model::DoTS::Miscellaneous->new({ na_feature_id => $naFeatureId});
        unless ($transcript->retrieveFromDB()) {
          $self->error(
            "No GeneFeature or Miscellaneous row with na_feature_id = $naFeatureId\n");
        }
    }

    my $translatedAAFeature = $transcript->getChild("DoTS::TranslatedAAFeature", 1);

    my $aaSeq = GUS::Model::DoTS::TranslatedAASequence->new({
        aa_sequence_id => $translatedAAFeature->getAaSequenceId()
    });
    $aaSeq->retrieveFromDB or $self->error("No aa_sequence_id for na_feature_id = '$naFeatureId'");

    return $aaSeq->getId();
}

sub convertOrfRecordsToGenes { # if possible, otherwise leave as is.
    my ($self, $recordSet) = @_;
    for my $record (@{$recordSet}) {
        $self->mapOrfToGene($record) if (isOrf($record->{naFeatureId}));
    }
}

sub mapOrfToGene {
    my ($self, $record) = @_;
    # Given an Orf, find gene it belongs to:
    #    Find gene whose coordinates overlap with orf.
    #    Declare match if all peptide seqs are substrings of protein seq.
    #       Strictly, an ORF may not wholly belong to the gene model, but if
    #       all the peptides match then we have the gene we are really after.
    # If an ORF partially belongs to a gene model and there's a peptide
    # that isn't spanned by the gene then we leave the ORF record as is.

    my $recNaFeatureId = $record->{naFeatureId};
    
    my $sth = $self->getQueryHandle()->prepare(<<"EOSQL");
        select gt.source_id, gt.na_feature_id, taas.sequence
        from
        dots.transcript orf,
        dots.transcript gt,
        dots.nalocation gtnal,
        dots.nalocation orfnal,
        dots.translatedaafeature taaf,
        dots.translatedaasequence taas,
        sres.sequenceontology so
        where
        orf.na_feature_id = ?
        and gt.na_feature_id = gtnal.na_feature_id
        and orf.na_feature_id = orfnal.na_feature_id
        and orf.na_sequence_id = gt.na_sequence_id
        and gtnal.start_max < orfnal.end_min
        and gtnal.end_min > orfnal.start_max
        and gt.na_feature_id = taaf.na_feature_id
        and taaf.aa_sequence_id = taas.aa_sequence_id
        and gt.sequence_ontology_id = so.sequence_ontology_id
        and so.term_name != 'ORF'
            -- orf and gene must be same strand and frame --
        and orfnal.is_reversed = gtnal.is_reversed
        and mod(gtnal.start_max, 3) = mod(orfnal.start_max, 3)
EOSQL

    my %row;
    $sth->execute($recNaFeatureId);
    $sth->bind_columns( \( @row{ @{$sth->{NAME_lc} } } ));
    
    my $res = $sth->fetchall_arrayref();
    if (scalar @{$res} == 0) {
        warn "ORF $record->{sourceId} not mapped to a gene, will leave as ORF.\n" if $self->getArg('verbose');
        return;
    }
    if (scalar @{$res}  > 1) {
        $self->error("dots.transcript.na_feature_id '$recNaFeatureId' corresponds to more than one gene. This is not supported.");
    }
    
    
    my $proteinSeq = $row{sequence};

    $proteinSeq or $self->error("No sequence found for $record->{sourceId}");
    
    my @newCoords;
    
    for my $pep (@{$record->{peptides}}) {
        my $start = index($proteinSeq, $pep->{sequence}) +1;
        if ($start == 0) {
            warn "Peptide set on ORF $record->{sourceId} not fully mapped to a gene, will leave as ORF.\n" if $self->getArg('verbose');
            return;
        }
        my $end   = length($pep->{sequence}) + $start -1;
        push @newCoords, ($start, $end);
    }

    # Have successful mapping of ORF to gene. Change source_id/na_feature_id 
    # and update peptide coordinates relative to new protein coord.
    $record->{sourceId} = $row{source_id};
    $record->{naFeatureId} = $row{na_feature_id};
    for my $pep (@{$record->{peptides}}) {
        $pep->{start} = shift @newCoords;
        $pep->{end}   = shift @newCoords;
    }

}

sub isOrf {
    my ($naFeatureId) = @_;
    
    my $naFeature = GUS::Model::DoTS::NAFeature->new({'na_feature_id' => $naFeatureId}); 
    $naFeature->retrieveFromDB() || die "Failed to retrieve na_feature_id '$naFeatureId'";;

    my $so = GUS::Model::SRes::SequenceOntology->new({'term_name' => 'ORF'});
    $so->retrieveFromDB() || die "Failed to retrieve SO Id for ORF";
    
    return ($naFeature->getSequenceOntologyId == $so->getId());

}

sub addMassSpecFeatureToRecord {
    my ($self, $ln, $record) = @_;
    
    my $pep = {};
    ( $pep->{start},
      $pep->{end},
      $pep->{observed},
      $pep->{mr_expect},
      $pep->{mr_calc},
      $pep->{delta},
      $pep->{miss},
      $pep->{sequence},
      $pep->{modification},
      $pep->{query},
      $pep->{hit},
      $pep->{ions_score}
    ) = split "\t", $ln;

    $self->setPepStartEnd($pep, $record->{aaSequenceId}) if (!$pep->{start} or !$pep->{end});
    
    $pep->{description} = <<"EOF";
match: $record->{sourceId}
ions score: $pep->{ions_score}
modification: $pep->{modification}
report: '$record->{sourcefile}'
EOF

    push @{$record->{peptides}}, $pep;
}

sub setPepStartEnd {
    my ($self, $pep, $aaSequenceId) = @_;

    my $aaSeq = GUS::Model::DoTS::TranslatedAASequence->new({
        aa_sequence_id => $aaSequenceId
    });
    $aaSeq->retrieveFromDB or $self->error("failed to find aa_sequence_id $aaSequenceId in TranslatedAASequence\n");
    
    my $proteinSeq = $aaSeq->getSequence();
    
    $pep->{start} = index($proteinSeq, $pep->{sequence}) +1;
    if ($pep->{start} == 0) {
        self->error("peptide '$pep->{sequence}' not found for aaSequenceId $aaSequenceId'\n");
    }
    $pep->{end} = length($pep->{sequence}) + $pep->{start} -1;
    
}

sub insertRecordsIntoDb {
    my ($self, $recordSet) = @_;
    for my $record (@{$recordSet}) {
        my $mss = $self->insertMassSpecSummary($record);
        $self->insertMassSpecFeatures($record, $mss);
    }
}


sub insertMassSpecSummary {
    my ($self, $record) = @_;
    
    my $transcript = GUS::Model::DoTS::Transcript->new({ na_feature_id => $record->{naFeatureId}});
    unless ($transcript->retrieveFromDB()) {
      my $transcript = GUS::Model::DoTS::Miscellaneous->new({ na_feature_id => $record->{naFeatureId}});
        unless ($transcript->retrieveFromDB()) {
          $self->error(
            "No GeneFeature or Miscellaneous row with na_feature_id = $record->{naFeatureId}\n");
        }
    }

    my $translatedAAFeature = $transcript->getChild("DoTS::TranslatedAAFeature", 1);

    my $aaSeq = GUS::Model::DoTS::TranslatedAASequence->new({
        aa_sequence_id => $translatedAAFeature->getAaSequenceId()
    });
    $aaSeq->retrieveFromDB;

    $record->{aaSequenceId} = $aaSeq->getId();
    $record->{naSequenceId} = $transcript->getNaSequenceId();
    $record->{naFeatureId}  = $transcript->getId();
    $record->{sourceId}     = $transcript->getSourceId();
    $record->{seqLength}    = $aaSeq->getLength();
    $record->{devStage}     = $self->getArg('developmentalStage') || 'unknown';

    my $mss = GUS::Model::ApiDB::MassSpecSummary->new({
       'aa_sequence_id'          => $record->{aaSequenceId},
       'is_expressed'            => 1,
       'developmental_stage'     => $record->{devStage},
       'number_of_spans'         => $record->{spanCount},
       'prediction_algorithm_id' => $self->getPredictionAlgId,
       'spectrum_count'          => $record->{spectrumCount},
       'aa_seq_length'           => $record->{seqLength},
       'aa_seq_molecular_weight' => $record->{seqMolWt},
       'aa_seq_pi'               => $record->{seqPI},
       'sequence_count'          => 1,
       'aa_seq_percent_covered'  => $record->{percentCoverage},
    });

    $mss->submit();
    $self->{summariesAdded}++;
    
    return $mss;
}

sub insertMassSpecFeatures {
    my ($self, $record, $mss) = @_;
    
    for my $pep (@{$record->{peptides}}) {
        my $translatedAAFeature = GUS::Model::DoTS::TranslatedAAFeature->new({
            'na_feature_id' => $record->{naFeatureId}
        });
        $translatedAAFeature->retrieveFromDB();
        
        my $msFeature = GUS::Model::DoTS::MassSpecFeature->new({
            'aa_sequence_id'          => $record->{aaSequenceId},
            'prediction_algorithm_id' => $self->getPredictionAlgId,
            #           'external_database_release_id' => $self->getArg->('extDbRelId'), #DEBUG
            'developmental_stage'     => $record->{devStage},
            'description'             => $pep->{description},
            'source_id'               => $mss->getMassSpecSummaryId,
            'is_predicted'            => 1,
        });
        
        my $aaLoc = GUS::Model::DoTS::AALocation->new({
                         'start_min' => $pep->{start},
                         'start_max' => $pep->{start},
                         'end_min'   => $pep->{end},
                         'end_max'   => $pep->{end},
                     });
    
        my $naLoc = $self->addNALocation(
                        $record->{sourceId}, 
                        $record->{naFeatureId},
                        $record->{naSequenceId},
                        $pep
                      );
    
        $msFeature->setParent($naLoc);
        $msFeature->addChild($aaLoc);    
        $translatedAAFeature->addChild($msFeature);
        
        $translatedAAFeature->submit();
        
        $self->{featuresAdded}++;
    }

    $self->undefPointerCache();
}

sub addNALocation {
    my ($self, $sourceId, $naFeatureId, $naSequenceId, $pep) = @_;
    my $naLocations = $self->mapToNASequence(
        $naFeatureId, $pep->{start}, $pep->{end}
    );

    my $naFeature = GUS::Model::DoTS::NAFeature->new({
        na_sequence_id                  => $naSequenceId,
        name                            => 'located_sequence_feature',
        external_database_release_id    => $self->{extDbRlsId},
        source_id                       => $sourceId,
        prediction_algorithm_id         => $self->getPredictionAlgId,
    });

 #   $naFeature->retrieveFromDB();

    foreach (@$naLocations) {
        $naFeature->addChild(
            GUS::Model::DoTS::NALocation->new({
                    'start_min'   => $_->[0],
                    'start_max'   => $_->[0],
                    'end_min'     => $_->[1],
                    'end_max'     => $_->[1],
                    'is_reversed' => $_->[2] == -1 ? 1 : 0,
            })
        );
    }
    $naFeature->submit();
    return $naFeature;
}

sub mapToNASequence {
    my ($self, $naFeatureId, $pepStart, $pepEnd) = @_;
    my $naLocations = [];

    my $exons = $self->getExons($naFeatureId) or $self->error("no exons for na_feature_id '$naFeatureId'\n");

    # CDS in chromosome coordinates
    my $cds = new Bio::Location::Split;
    foreach (@{$exons}) {
        $cds->add_sub_Location(new Bio::Location::Simple(
            -start  =>  @$_[0],
            -end    =>  @$_[1],
            -strand =>  @$_[2]
        ));
    }

    my $gene = Bio::Coordinate::GeneMapper->new(
        -in    => 'peptide',
        -out   => 'chr',
        -exons => [$cds->sub_Location],
    );


    my $peptideCoords = Bio::Location::Simple->new (
        -start => $pepStart,
        -end   => $pepEnd,
    );

    my $map = $gene->map($peptideCoords);

    foreach (sort { $a->start <=> $b->start } $map->each_Location ) {
        push @$naLocations, [$_->start, $_->end, $_->strand];
    }

    return $naLocations;
}

# Return AoA ref of exon coordinates for the encoding NA seq. An ORF has one 'exon'.
# ORFs are assumed to not have an exonfeature. So some fishing is required.
sub getExons {
    my ($self, $id) = @_;
    my @exons; my $exonCoords = [];
    my $exonParent;
    
    my $transcript = GUS::Model::DoTS::Transcript->new({ na_feature_id => $id });
    if ($transcript->retrieveFromDB()) {
        # is a gene
        $exonParent = GUS::Model::DoTS::GeneFeature->new({
            na_feature_id => $transcript->get('parent_id')});
        @exons = $exonParent->getChildren("DoTS::ExonFeature", 1);
    } else {
        # should be an orf
        $exonParent = GUS::Model::DoTS::Miscellaneous->new({ na_feature_id => $id });
        unless ($exonParent->retrieveFromDB()) {
          $self->logVerbose(
            "No Transcript or Miscellaneous row was fetched with na_feature_id = $id\n");
             return undef;
        }
        @exons = $exonParent;
   }


    unless (@exons) {
      $self->error(<<"EOF")
      Can not find an exon/CDS for transcript $id.
      Can't map its peptide hits to the chromosome.\n
EOF
    }

    for my $exon (@exons) {
        my ($exonStart, $exonEnd, $exonIsReversed) = $exon->getFeatureLocation();

        my $codingStart = ($exon->isValidAttribute('coding_start')) ?
            $exon->getCodingStart() || $exonStart :
            $exonStart;

        my $codingEnd = ($exon->isValidAttribute('coding_end')) ?
            $exon->getCodingEnd() || $exonEnd :
            $exonEnd;

        my $strand = ($exonIsReversed) ? -1 : 1;
        
        ($codingStart > $codingEnd) && 
            (($codingStart, $codingEnd) = ($codingEnd, $codingStart));

        push @$exonCoords, [$codingStart, $codingEnd, $strand];
    }
    return $exonCoords;
}

sub getPredictionAlgId {
    my ($self) = @_;
    $self->{predictionAlgId} and return $self->{predictionAlgId};
    my $pid = GUS::Model::Core::Algorithm->
        new({ name        => 'Mascot',
              description => 'Matrix Science mass spectrometry search' });

    $pid->submit() unless $pid->retrieveFromDB();
    $self->{predictionAlgId} = $pid->getId;
}

sub nextRecord {
    my ($self, $fileptr) = @_;
    my $pos;
    my $ln = readline $fileptr;
    while ($ln && $ln !~ m/^# /) {
        $pos = tell $fileptr;
        $ln = readline $fileptr;
    }
    seek($fileptr, $pos, 0);
}

########################################################################
########################################################################

sub declareArgs {
  [

  fileArg({
      name            =>  'inputFile',
      descr           =>  'Name of file containing the mass spec features',
      constraintFunc  =>  undef,
      reqd            =>  1,
      isList          =>  0,
      mustExist       =>  1,
      format          =>  'Text'
    }),

  stringArg({
      name            =>  'externalDatabaseSpec', # For proteome
      descr           =>  'external database release `name|version` for these data',
      constraintFunc  =>  undef,
      reqd            =>  1,
      isList          =>  0
    }),

  stringArg({
      name            =>  'developmentalStage',
      descr           =>  'organism developmental stage analyzed',
      constraintFunc  =>  undef,
      reqd            =>  0,
      isList          =>  0
    }),

  ];

}

sub undoTables {
    qw(
    DoTS.AALocation
    DoTS.MassSpecFeature
    DoTS.MassSpecSummary
    DoTS.NALocation
    DoTS.NAFeature
    DoTSVer.MassSpecFeatureVer
    Core.AlgorithmParam
    Core.AlgorithmInvocation
    );
}


sub getDocumentation {
my $purpose = <<PURPOSE;
Load tab delimited data culled from Mascot Protein Views.
Genome NaLocations corresponding to the peptides will be added iff sequence 
ontologies are set for protein sequences.
PURPOSE

my $purposeBrief = <<PURPOSEBRIEF;
Load tab delimited data culled from Mascot Protein Views.
PURPOSEBRIEF

my $notes = <<NOTES;

One MassSpecFeature is created for each peptide entry in the file. Even when
two peptides have the same sequence and map to the same location they are 
treated as two features because they were derived from different analyses.

Open reading frame reports are converted to genes when possible 
and the orf-associated peptide coordinates are adjusted.

Sample tab-delimited input:
# source_id	description	seqMolWt	seqPI	score	percentCoverage	spanCount	spectrumCount	sourcefile
Liv008927	AAEL01000002-1-20221-21813	60509	4.82	117	3	2	2	CrypProt LTQ spot k2 Protein View.htm
## start	end	observed	mr_expect	mr_calc	delta	miss	sequence	modification	query	hit	ions_score
301	309	530.12	1058.23	1057.54	0.69	0	VNADLLEER		11	1	88
311	320	588.39	1174.77	1175.59	-0.81	0	VLVGEMEIDR	Oxidation (M) 	14	1	29
# source_id	description	seqMolWt	seqPI	score	percentCoverage	spanCount	spectrumCount	sourcefile
Liv070540	AAEE01000003-3-1125870-1128359	92046	4.49	430	17	9	9	CrypProt LTQ spot L Protein View.htm
## start	end	observed	mr_expect	mr_calc	delta	miss	sequence	modification	query	hit	ions_score
79	85	422.79	843.57	842.44	1.13	0	LFGFFGR		8	1	30
164	182	648.42	1942.22	1940.88	1.35	0	SAPAPVAEHFDGESSSEPK		39	8	7
205	217	621.99	1241.96	1242.65	-0.68	0	GAIPGIVSEESGK		22	1	63
258	274	907.65	1813.28	1812.92	0.36	0	SLQEGLPESVVLNEGSR		36	1	91
387	409	839.66	2515.95	2516.07	-0.11	1	YLEDTADDSKEGSEASTADLEDR		50	1	43
462	468	439.03	876.04	876.47	-0.43	0	VPTEYIR		9	1	46
555	574	745.40	2233.16	2233.03	0.13	1	ESEVTNREESVSVPAEESQK		46	2	14
575	598	881.96	2642.85	2642.23	0.62	1	AAVESSVEEESEKPEELPDNNKGR		51	1	97
793	806	766.35	1530.69	1530.77	-0.08	0	NLLVSAPSQEQMAK	Oxidation (M) 	30	1	46

NOTES

my $tablesAffected =
[
  [
    'DoTS.AALocation' =>
    'Protein coordinate location of the mass spec feature (peptide)'
  ],
  [
    'DoTS.MassSpecFeature' =>
    'Mass spec predicted peptides'
  ],
  [
    'DoTS.MassSpecSummary' =>
    'Summary information from the protein hit in one Mascot Search Result. Has one or more MassSpecFeatures.'
  ],
  [
    'DoTS.NALocation' =>
    'Genomic coordinate location encoding a peptide.'
  ],
  [
    'DoTS.NAFeature' =>
    'NALocations are associated with MassSpecFeatures by NAFeature.'
  ],
  [
    'Core.Algorithm' =>
    'An entry for `Mascot` will be added if one does not already exist.'
  ],
];


my $tablesDependedOn =
[
  [
    'DoTS.Transcript' =>
    'Id of the matched protein is looked up in Transcript. If the id is not found then that Mascot search match is skipped.'
  ],
  [
    'DoTS.TranslatedAAFeature' =>
    'TranslatedAASequences are associated with Transcripts by TranslatedAAFeatures.'
  ],
  [
    'DoTS.TranslatedAASequence' =>
    'For protein sequence length.'
  ],
  [
    'SRes.SequenceOntology' =>
    'Used to distinguish ORF sequences from sequences which have ExonFeatures.'
  ],
];

my $howToRestart = <<RESTART;
RESTART

my $failureCases = <<FAIL;
The id of a matched protein must be in DoTS.Transcript.source_id otherwise
that match will be skipped.

Any ORF sequences must have a Sequence Ontology term name of 'ORF' otherwise
the mapping of peptide to genome will fail and all further processing will stop.

FAIL

my $documentation = {
    purpose          => $purpose,
    purposeBrief     => $purposeBrief,
    tablesAffected   => $tablesAffected,
    tablesDependedOn => $tablesDependedOn,
    howToRestart     => $howToRestart,
    failureCases     => $failureCases,
    notes            => $notes
    };
}
1;

__END__

select aa_location_id, start_min, end_max, mss.MASS_SPEC_SUMMARY_ID
from dots.massspecsummary mss,
dots.massspecfeature msf,
dots.aalocation aal,
dots.translatedaasequence taas
where mss.mass_spec_summary_id = msf.source_id
and msf.aa_feature_id = aal.aa_feature_id
and mss.aa_sequence_id = taas.aa_sequence_id
and taas.source_id = 'AAEL01000400-5-3912-3475'

select na_location_id, start_min, end_max
from dots.massspecsummary mss,
dots.massspecfeature msf,
dots.nalocation nal,
dots.translatedaasequence taas,
dots.translatedaafeature taaf,
dots.transcript t
where mss.mass_spec_summary_id = msf.source_id
and msf.nA_FEATURE_ID = nal.nA_FEATURE_ID
and mss.aa_sequence_id = taas.aa_sequence_id
and taas.aa_sequence_id = taaf.aa_sequence_id
and taaf.na_feature_id = t.na_feature_id
and t.source_id = 'AAEL01000400-5-3912-3475'



MassSpecSummary ----------- Algorithm
   /|\                    /
  / | \                  /
 F  F  MassSpecFeature(F)
 |  |     |              \
 |  |     |               \ 
 L  L     AALocation(L)    \
                           NAFeature
                          /    |   \
                         N     N    NALocation(N)  [may be split across intron]
                             