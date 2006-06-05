package ApiCommonData::Load::Plugin::InsertMascotSummaries;


@ISA = qw(GUS::PluginMgr::Plugin);

use strict;
use File::Find;
use FileHandle;

use GUS::PluginMgr::Plugin;

# read from
use GUS::Model::DoTS::Transcript;
use GUS::Model::DoTS::TranslatedAASequence;
use GUS::Model::DoTS::TranslatedAAFeature;
use GUS::Model::SRes::SequenceOntology;

# write to
use GUS::Model::DoTS::AALocation;
use GUS::Model::DoTS::NALocation;
use GUS::Model::DoTS::MassSpecFeature;
use GUS::Model::DoTS::MassSpecSummary;
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
    my $summary = {};
    
#    my $extDbRlsId = $self->getExtDbRlsId($self->getArg("externalDatabaseSpec"));

    open(F, $inputFile) or die "Could not open $inputFile: $!\n";
    while (<F>) {
        chomp;
        if (m/^# /) {
            chomp(my $ln = <F>);
            unless ($self->addMassSpecSummary($ln, $summary)) {
                warn "Protein match from '$summary->{sourcefile}' not found in DoTS.Transcript, skipping\n";
                $self->{summariesSkipped}++;
                $self->nextRecord(*F);
            }
        } else {
            m/^## / and next;
            $self->addMassSpecFeature($_, $summary);
        }
    }
    
    $self->setResultDescr(<<"EOF")

Added $self->{featuresAdded} features and $self->{summariesAdded} summaries.
$self->{summariesSkipped} summaries skipped.
EOF

}

sub addMassSpecSummary {
    my ($self, $ln, $h) = @_;

    ( $h->{proteinId},
      $h->{description},
      $h->{seqMolWt},
      $h->{seqPI},
      $h->{score},
      $h->{percentCoverage},
      $h->{spanCount},
      $h->{spectrumCount},
      $h->{sourcefile},
    ) = split "\t", $ln;

    my $transcript = GUS::Model::DoTS::Transcript->new({source_id=>$h->{proteinId}});
    unless ($transcript->retrieveFromDB()) {
        $self->logVerbose("$h->{proteinId} not found, looking for $h->{description}\n");
        $transcript = GUS::Model::DoTS::Transcript->new({source_id=>$h->{description}});
        $transcript->retrieveFromDB() or return undef;
    }

    my $translatedAAFeature = $transcript->getChild("DoTS::TranslatedAAFeature", 1);

    my $aaSeq = GUS::Model::DoTS::TranslatedAASequence->new({
        aa_sequence_id => $translatedAAFeature->getAaSequenceId()
    });
    $aaSeq->retrieveFromDB;

    $h->{aaSequenceId} = $aaSeq->getId();
    $h->{naSequenceId} = $transcript->getNaSequenceId();
    $h->{naFeatureId}  = $transcript->getId();
    $h->{sourceId}     = $transcript->getSourceId();
    $h->{seqLength}    = $aaSeq->getLength();
    $h->{devStage}     = 'DEBUG';

    my $mss = GUS::Model::DoTS::MassSpecSummary->new({
       'aa_sequence_id'          => $h->{aaSequenceId},
       'is_expressed'            => 1,
       'developmental_stage'     => $h->{devStage},
       'number_of_spans'         => $h->{spanCount},
       'prediction_algorithm_id' => $self->getPredictionAlgId,
       'spectrum_count'          => $h->{spectrumCount},
       'aa_seq_length'           => $h->{seqLength},
       'aa_seq_molecular_weight' => $h->{seqMolWt},
       'aa_seq_pi'               => $h->{seqPI},
       'sequence_count'          => 1,
       'aa_seq_percent_covered'  => $h->{percentCoverage},
    });

    unless ($mss->retrieveFromDB()) {
        $mss->submit();
        $self->{summariesAdded}++;
    }
    
    return $mss;
}

sub addMassSpecFeature {
    my ($self, $ln, $h) = @_;
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

    my $description = <<"EOF";
ions score: $pep->{ions_score}
modification: $pep->{modification}
match: $h->{sourceId}
summary: '$h->{sourcefile}'
EOF
    my $translatedAAFeature = GUS::Model::DoTS::TranslatedAAFeature->new({
        'na_feature_id' => $h->{naFeatureId}
    });
    $translatedAAFeature->retrieveFromDB();
    
    my $msFeature = GUS::Model::DoTS::MassSpecFeature->new({
        'aa_sequence_id'          => $h->{aaSequenceId},
        'prediction_algorithm_id' => $self->getPredictionAlgId,
        #           'external_database_release_id' => $self->getArg->('extDbRelId'), #DEBUG
        'developmental_stage'     => $h->{devStage},
        'description'             => $description,
        'is_predicted'            => 1,
    });

    #$msFeature->retrieveFromDB();
    
    my $aaLoc = GUS::Model::DoTS::AALocation->new({
                     'start_min' => $pep->{start},
                     'start_max' => $pep->{start},
                     'end_min'   => $pep->{end},
                     'end_max'   => $pep->{end},
                 });

    my $naLoc = $self->addNALocation($h, $pep);

     $msFeature->setParent($naLoc);
     $msFeature->addChild($aaLoc);
    #$msFeature->submit();# unless $aaLoc->retrieveFromDB(); #unless $msFeature->retrieveFromDB();
    
    $translatedAAFeature->addChild($msFeature);
    
    $translatedAAFeature->submit();
    
    $self->{featuresAdded}++;

}

sub mapToNASequence {
    my ($self, $naFeatureId, $pepStart, $pepEnd) = @_;

    my $naLocations = [];

    # CDS in chromosome coordinates
    my $cds = new Bio::Location::Split;
    foreach (@{$self->getExons($naFeatureId)}) {
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

sub addNALocation {
    my ($self, $h, $pep) = @_;
    my $naLocations = $self->mapToNASequence(
        $h->{naFeatureId}, $pep->{start}, $pep->{end}
    );

    my $naFeature = GUS::Model::DoTS::NAFeature->new({
        na_sequence_id => $h->{naSequenceId},
        name                            => 'located_sequence_feature',
#        external_database_release_id    =>,
        source_id                       => $h->{sourceId},
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

# Return AoA ref of exon coordinates for the encoding NA seq. An ORF has one 'exon'.
# The lookups of exonfeatures and coordinates depend on data modeling. E.g.
# exonfeatures may be a child of RnaType or of Transcript. ORFs are assumed
# to not have an exonfeature. So some fishing is required.
# Open Reading Frames must have a sequence ontology id for ORF set in Transcript
# or they will not be located.
sub getExons {
    my ($self, $id) = @_;
    my @exons; my $exonCoords = [];

# todo: add ext db rls id
    my $transcript = GUS::Model::DoTS::Transcript->new({ na_feature_id => $id });
    unless ($transcript->retrieveFromDB()) {
      $self->logVerbose("No Transcript row was fetched with source_id = $id\n");
      return undef;
    }

    my $so = GUS::Model::SRes::SequenceOntology->new(
        {sequence_ontology_id => $transcript->getSequenceOntologyId()}
    );
    $so->retrieveFromDB;
    my $soTerm = $so->get('term_name');

    if ($soTerm =~ /^ORF/i) {
        @exons = $transcript;
    } else {
        @exons = $transcript->getChildren("DoTS::ExonFeature", 1);
        unless (@exons) {
            my $rna = $transcript->getParent("DoTS::RnaType", 1);
            @exons = $rna->getChildren("DoTS::ExonFeature", 1) if $rna;
        }
    }

    unless (@exons) {
      $self->error(<<"EOF")
      Can not find an exon/CDS for transcript $id
      as a  child of either dots.Transcript or dots.RnaType.
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

  fileArg({
      name            =>  'lookUpFile',
      descr           =>  'lookup file to map old to new identifiers',
      constraintFunc  =>  undef,
      reqd            =>  0,
      isList          =>  0,
      mustExist       =>  1,
      format          =>  'Text'
    }),

  stringArg({
      name            =>  'restart',
      descr           =>  'For restarting script...takes list of row_alg_invocation_ids to exclude',
      constraintFunc  =>  undef,
      reqd            =>  0,
      isList          =>  0
    }),
  ];

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

select aa_location_id, start_min, end_max, aal.aa_feature_id
from dots.massspecsummary mss,
dots.massspecfeature msf,
dots.aalocation aal,
dots.translatedaasequence taas
where mss.AA_SEQUENCE_ID = msf.AA_SEQUENCE_ID
and msf.AA_FEATURE_ID = aal.AA_FEATURE_ID
and mss.aa_sequence_id = taas.aa_sequence_id
and taas.source_id = 'AAEL01000400-5-3912-3475'




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
                             