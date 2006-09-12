package ApiCommonData::Load::Plugin::InsertSnps;
@ISA = qw(GUS::PluginMgr::Plugin);


use strict;

use GUS::PluginMgr::Plugin;
use GUS::Model::SRes::SequenceOntology;
use GUS::Model::DoTS::SeqVariation;
use GUS::Model::DoTS::NALocation;
use GUS::Model::DoTS::SnpFeature;
use GUS::Model::DoTS::Transcript;

use Bio::Seq;
use CBIL::Bio::SequenceUtils;


$| = 1;

# ---------------------------------------------------------------------------
# Load Arguments
# ---------------------------------------------------------------------------

sub getArgumentsDeclaration{
  my $argsDeclaration =
    [
     stringArg({name => 'snpExternalDatabaseName',
		descr => 'sres.externaldatabase.name for SNP source',
		constraintFunc => undef,
		reqd => 1,
		isList => 0
	       }),
     stringArg({name => 'snpExternalDatabaseVersion',
		descr => 'sres.externaldatabaserelease.version for this SNP source',
		constraintFunc => undef,
		reqd => 1,
		isList => 0
	       }),
     stringArg({name => 'naExternalDatabaseName',
		descr => 'sres.externaldatabase.name for the genome sequences',
		constraintFunc => undef,
		reqd => 1,
		isList => 0
	       }),
     stringArg({name => 'naExternalDatabaseVersion',
		descr => 'sres.externaldatabaserelease.version for the genome sequences',
		constraintFunc => undef,
		reqd => 1,
		isList => 0
	       }),
     stringArg({name => 'seqTable',
		descr => 'where do we find the nucleotide sequences',
		constraintFunc => undef,
		reqd => 1,
		isList => 0
	       }),
     stringArg({name => 'organism',
		descr => 'Genus and species, example T. gondii',
		constraintFunc=> undef,
		reqd  => 1,
		isList => 0
	       }),
     stringArg({name => 'snpFile',
		descr => 'tab delimited file containing the SNP data',
		constraintFunc => undef,
		reqd => 1,
		isList => 0,
		mustExist => 1,
		format => 'GFF, Ex:995313  Stanford        SNP     3093368 3093369 .       .       .       SNP TGG_995313_Contig28_138 ; Allele RH:C ; Allele ME49:- ; Allele VEG:-'
	       }),
     stringArg({name => 'reference',
		descr => 'Strain or individual used as reference for all indels and substitutions',
		constraintFunc=> undef,
		reqd  => 1,
		isList => 0,
	       }),
     integerArg({name => 'restart',
		descr => 'for restarting use number from last processed row number in STDOUT',
	        constraintFunc => undef,
	        reqd => 0,
	        isList => 0
	    }),
     stringArg({name => 'ontologyTerm',
		descr => 'Ontology term describing the type of genetic variant being added to the database',
		constraintFunc=> undef,
		reqd  => 1,
		isList => 0,
	       }),
    ];
  return $argsDeclaration;
}

# ----------------------------------------------------------------------
# Documentation
# ----------------------------------------------------------------------

sub getDocumentation {
  my $purposeBrief = "Inserts SNP data into DoTS.SeqVariation and the location into DoTS.NALocation";

  my $purpose = "Inserts SNP information from a gff formatted file into into DoTS.SeqVariation and the location into DoTS.NALocation.";

  my $tablesAffected = [['DoTS::SeqVariation', 'One or more rows inserted per SNP, row number equal to strain number'],['DoTS::NALocation', 'A single row inserted per SNP']];

  my $tablesDependedOn = [['SRes::SequenceOntology',  'SequenceOntology term equal to SNP required']];

  my $howToRestart = "Use restart option and last processed row number from STDOUT file.";

  my $failureCases = "";

  my $notes = "";

  my $documentation = {purpose=>$purpose, purposeBrief=>$purposeBrief, tablesAffected=>$tablesAffected, tablesDependedOn=>$tablesDependedOn, howToRestart=>$howToRestart, failureCases=>$failureCases,notes=>$notes};

  return $documentation;
}

# ----------------------------------------------------------------------
# create and initalize new plugin instance.
# ----------------------------------------------------------------------

sub new {
  my ($class) = @_;
  my $self = {};
  bless($self,$class);

  my $documentation = &getDocumentation();
  my $argumentDeclaration = &getArgumentsDeclaration();


  $self->initialize({requiredDbVersion => 3.5,
		     cvsRevision => '$Revision$',
                     name => ref($self),
                     revisionNotes => '',
                     argsDeclaration => $argumentDeclaration,
                     documentation => $documentation});

  return $self;
}

# ----------------------------------------------------------------------
# run method to do the work
# ----------------------------------------------------------------------

sub run {
  my ($self) = @_;

  my $dbh = $self->getDbHandle();
  $dbh->{'LongReadLen'} = 10_000_000;

  $dbh = $self->getQueryHandle();
  $dbh->{'LongReadLen'} = 10_000_000;

  my $termName = $self->getArg('ontologyTerm');
  $self->{'soId'} = $self->getSoId($termName);

  die "The term $termName was not found in the Sequence Ontology.\n" unless $self->{'soId'};

  $self->{'snpExtDbRlsId'} = $self->getExtDbRlsId($self->getArg('snpExternalDatabaseName'),$self->getArg('snpExternalDatabaseVersion'));
  $self->{'naExtDbRlsId'} = $self->getExtDbRlsId($self->getArg('naExternalDatabaseName'),$self->getArg('naExternalDatabaseVersion'));

  my $file = $self->getArg('snpFile');

  my ($linesProcessed) = $self->processSnpFile($file);

  return "$linesProcessed lines of SNP file $file processed\n";
}

# ----------------------------------------------------------------------

sub processSnpFile{
  my ($self, $file) = @_;

  my $lineNum = $self->getArg('restart') ? $self->getArg('restart') : 0;

  my $num = 0;

  open (SNP, $file) || die "Cannot open file $file for reading: $!";

  while(<SNP>){
    chomp;
    $num++;

    next if ($self->getArg('restart') && $num <= $lineNum);

    my @line = split(/\t/,$_);

    my $snpFeature = $self->createSnpFeature(\@line);
    my $naLoc = $snpFeature->getChild('GUS::Model::DoTS::NALocation');

    my $snpStart = $naLoc->getStartMin();
    my $snpEnd = $naLoc->getEndMax();

    my $naSeqId = $snpFeature->getParent('GUS::Model::DoTS::NASequenceImp') -> getId();
    my $transcript = $self->_getTranscript($naSeqId, $snpStart, $snpEnd);

    my $codingSequence = $self->_getCodingSequence($transcript, $snpStart, $snpEnd, '');
    my $mockCodingSequence = $self->_getCodingSequence($transcript, $snpStart, $snpEnd, '*');

    my ($codingSnpStart, $codingSnpEnd) = $self->getCodingSubstitutionPositions($codingSequence, $mockCodingSequence);

    if($transcript) {
      my $geneFeatureId = $transcript->get('parent_id');
      $snpFeature->set('parent_id', $geneFeatureId);
    }

    if(my $isCoding = $codingSequence ne $mockCodingSequence) {
      $snpFeature->setIsCoding(1);
      $snpFeature->setPositionInCds($codingSnpStart);

      my $startPositionInProtein = int($codingSnpStart / 3);
      my $endPositionInProtein = int($codingSnpEnd / 3);

      ## THE POSTION IN PROTEIN IS WHERE THE SNP STARTS...
      $snpFeature->setPositionInProtein($startPositionInProtein);

      my $refAaSequence = $self->_getAminoAcidSequenceOfSnp($codingSequence, $startPositionInProtein, $endPositionInProtein);
      $snpFeature->setReferenceAa($refAaSequence);

      $self->_updateSequenceVars($snpFeature, $codingSequence, $codingSnpStart, $codingSnpEnd, $isCoding);
    }
    else {
      $snpFeature->setIsCoding(0);
    }

    $snpFeature->submit();
    exit();
    $self->undefPointerCache();

    $lineNum++;

    $self->log("processed $lineNum lines from $file.\n") if($lineNum % 10 == 0);
  }
  return $lineNum;
}

# ----------------------------------------------------------------------

sub _updateSequenceVars {
  my  ($self, $snpFeature, $cds, $start, $end, $isCoding) = @_;

  my @seqVars = $snpFeature->getChildren('GUS::Model::DoTS::SeqVariation');

  foreach my $seqVar (@seqVars) {
    my ($phenotype);

    if($isCoding) {
      my $base = $seqVar ->getAllele();
      my $newCodingSequence = $self->_swapBaseInSequence($cds, 0, 0, $start, $end, $base, '');

      my $isSynonymous = $self->_isSynonymous($cds, $newCodingSequence);

      $phenotype = $isSynonymous == 1 ? 'synonymous' : 'non-synonymous';
      $snpFeature->setHasNonsynonymousAllele(1) if($isSynonymous == 0);

      my $startPositionInProtein = int($start / 3);
      my $endPositionInProtein = int($end / 3);

      my $snpAaSequence = $self->_getAminoAcidSequenceOfSnp($newCodingSequence, $startPositionInProtein, $endPositionInProtein);
      $seqVar->setProduct($snpAaSequence);
    }
    else {
      $phenotype = 'is_non_coding';
    }

    $seqVar->setPhenotype($phenotype);
  }
}

# ----------------------------------------------------------------------

sub createSnpFeature {
  my ($self,$line) = @_;

  my $name = 'SNP';
  my $extDbRlsId = $self->{'snpExtDbRlsId'};
  my $soId = $self->{'soId'};

  my @data = split (/;/, $line->[8]);

  my $sourceId = $data[0];
  my $organism = $self->getArg('organism');

  my $start = $line->[3];
  my $end = $line->[4];

  $self->userError("Snp end is less than snp start in file: $!") if($end < $start);

  my $strand = $line->[6];

  my $isReversed = $strand eq '-' ? 1 : 0;
  $isReversed = "NA" if($strand eq '.');

  my $ref = $self->getArg('reference');

  my $standard = ($end > $start) ? 'insertion' : 'substitution';

  my $snpFeature = GUS::Model::DoTS::SnpFeature->
    new({NAME => $name,
         SEQUENCE_ONTOLOGY_ID => $soId,
         EXTERNAL_DATABASE_RELEASE_ID => $extDbRlsId,
         SOURCE_ID => $sourceId,
         REFERENCE_STRAIN => $ref,
         ORGANISM => $organism,
	});

  $snpFeature->retrieveFromDB();

  my $naSeq = $self->getNaSeq($line);
  my $naLoc = $self->getNaLoc($line);

  $naSeq->setChild($snpFeature);
  $snpFeature->addChild($naLoc);

  while ($data[1] =~ m/(\w+):([\w\-]+)/g) {
    my $strain = $1;
    my $base = $2;

    if(lc($ref) eq lc($strain)) {
      $snpFeature->setReferenceNa($base);

      unless($self->_isSnpPositionOk($naSeq, $base, $naLoc, $isReversed)) {
        $self->userError("The snp base: $base for the Reference Strain: $ref doesn't match expected");
      }
    }
    else {
      $standard = 'deletion' if ($standard eq 'substitution' && $base =~ /-/);
      $soId = $self->getSoId($standard);

      my $seqVar =  GUS::Model::DoTS::SeqVariation->
        new({'source_id' => $sourceId,
             'external_database_release_id' => $extDbRlsId,
             'name' => $name,
             'sequence_ontology_id' => $soId,
             'strain' => $strain,
             'allele' => $base,
             'organism' => $organism
            });

      $seqVar->retrieveFromDB();
      $seqVar->setParent($snpFeature);
      $seqVar->setParent($naSeq);

      $naLoc = $self->getNaLoc($line);

      $seqVar->addChild($naLoc);

    }
  }
  return $snpFeature;
}

# ----------------------------------------------------------------------

sub getSoId {
  my ($self, $termName) = @_;

  my $so = GUS::Model::SRes::SequenceOntology->new({'term_name'=>$termName});

  if (!$so->retrieveFromDB()) {
    $self->error("No row has been added for term_name = SNP in the sres.sequenceontology table\n");
  }

  my $soId = $so->getId();

  return $soId;

}

# ----------------------------------------------------------------------

sub getNaSeq {
  my ($self,$line) = @_;

  my $sourceId = $line->[0];

  my $extDbRlsId = $self->{'naExtDbRlsId'};

  my ($seqTable) = $self->getArg("seqTable");
  $seqTable = "GUS::Model::$seqTable";
  eval "require $seqTable";

  my $naSeq = $seqTable->new({'source_id'=>$sourceId,'external_database_release_id'=>$extDbRlsId});

  $naSeq->retrieveFromDB() || $self->error(" $sourceId does not exist in the database with database release = $extDbRlsId\n");

  return $naSeq;
}

# ----------------------------------------------------------------------

sub getNaLoc {
  my ($self,$line) = @_;

  my $start = $line->[3];

  my $end = $line->[4];

  my $locType;
  if ($self->getArg('ontologyTerm') eq 'SNP'){
    $locType = $end > $start ? 'insertion_site' : 'modified_base_site';
  }
  else{
    $locType = 'genetic_marker_site';
  }
  my $naLoc = GUS::Model::DoTS::NALocation->new({'start_min'=>$start,'start_max'=>$start,'end_min'=>$end,'end_max'=>$end,'location_type'=>$locType});

  return $naLoc;
}

# ----------------------------------------------------------------------

sub _getTranscript {
  my ($self, $naSeqId, $snpStart, $snpEnd) = @_;

  my $transcript;

  if (!$self->{na_feature_sql_handle}) {
    my $sql = "SELECT tf.na_feature_id
               FROM dots.TRANSCRIPT tf, dots.NaLocation nl,dots.ExternalNaSequence ens
               WHERE tf.na_feature_id = nl.na_feature_id
                AND tf.na_sequence_id = ens.na_sequence_id 
                and nl.start_min <= ?
                and nl.end_max >= ?
                and tf.na_sequence_id = ?";

    $self->{na_feature_sql_handle} = $self->getQueryHandle()->prepare($sql);
  }

  my $sh = $self->{na_feature_sql_handle};
  my $bindValues = [$snpStart, $snpEnd, $naSeqId];

  if(my ($transcriptFeatureId) = $self->sqlAsArray( Handle => $sh, Bind => $bindValues )) {

    $transcript = GUS::Model::DoTS::Transcript->new({ na_feature_id => $transcriptFeatureId });

    unless ($transcript->retrieveFromDB()) {
      $self->error("No Transcript row was fetched with na_feature_id = $transcriptFeatureId");
    }
  }
  return($transcript);
}

# ----------------------------------------------------------------------

=pod

=head2 Subroutines

=over 4

=item C<_getCodingSequence >

This method gets the exons for a transcript, orders them, and creates the coding sequence.  
If base is provided, it will be substituted in the cds

B<Parameters:>

$transcript(GUS::Model::Transcript): The transcript object.
$snpStart(scalar): Location of snp start on the genome
$snpEnd(scalar):  Location of snp end on the genome
$base(scalar): null, base, bases, or "-" (deletion) which will be substituted in cds

=back

=cut

sub _getCodingSequence {
  my ($self, $transcript, $snpStart, $snpEnd, $base) = @_;

  return unless($transcript);

  my @exons = $transcript->getChildren("DoTS::ExonFeature", 1);

  unless (@exons) {
    my $id = $transcript->getId();
    self->error ("Transcript with na_feature_id = $id had no exons\n");
  }

  # this code gets the feature locations of the exons and puts them in order
  @exons = map { $_->[0] }
    sort { $a->[3] ? $b->[1] <=> $a->[1] : $a->[1] <=> $b->[1] }
      map { [ $_, $_->getFeatureLocation ]}
	@exons;

  my $transcriptSequence;

  for my $exon (@exons) {
    my $chunk = $exon->getFeatureSequence();

    my ($exonStart, $exonEnd, $exonIsReversed) = $exon->getFeatureLocation();

    my $codingStart = $exon->getCodingStart();
    my $codingEnd = $exon->getCodingEnd();
    next unless ($codingStart && $codingEnd);

    my $isForwardCoding = $codingStart <= $snpStart && $codingEnd >= $snpEnd && !$exonIsReversed;
    my $isReverseCoding = $codingStart >= $snpStart && $codingEnd <= $snpEnd && $exonIsReversed;

    if($base && ($isForwardCoding || $isReverseCoding)) {
      $chunk = $self->_swapBaseInSequence($chunk, $exonStart, $exonEnd, $snpStart, $snpEnd, $base, $exonIsReversed);
    }

    my $trim5 = $exonIsReversed ? $exonEnd - $codingStart : $codingStart - $exonStart;
    substr($chunk, 0, $trim5, "") if $trim5 > 0;
    my $trim3 = $exonIsReversed ? $codingEnd - $exonStart : $exonEnd - $codingEnd;
    substr($chunk, -$trim3, $trim3, "") if $trim3 > 0;

    $transcriptSequence .= $chunk;
  }

  return($transcriptSequence);
}

# ----------------------------------------------------------------------

sub getCodingSubstitutionPositions {
  my ($self, $codingSequence, $mockCodingSequence) = @_;

  my @cdsArray = split("", $codingSequence);
  my @mockCdsArray = split("", $mockCodingSequence);

  my @results;

  for(my $i = 0; $i < scalar(@cdsArray); $i++) {
    push(@results, $i) if($cdsArray[$i] ne $mockCdsArray[$i]);
  }
  my $snpStart = $results[0];
  my $snpEnd = $results[scalar(@results) - 1];

  return($snpStart, $snpEnd);
}

sub _swapBaseInSequence {
  my ($self, $seq, $exonStart, $exonEnd, $snpStart, $snpEnd, $base, $isReversed) = @_;

  my $normSnpStart = $isReversed ? $exonEnd - $snpStart : $snpStart - $exonStart;
  my $normSnpEnd = $isReversed ? $exonEnd - $snpEnd  : $snpEnd - $exonStart;

  my ($fivePrimeFlank, $threePrimeFlank, $newSeq);

  # An insertion is when the snpStart is one base less than the snpEnd
  # deletion have a base of '-' and are treated identically to substitutions

  if($normSnpStart < $normSnpEnd && $base !~ /-/) {
    $fivePrimeFlank = substr($seq, 0,  ($normSnpStart + 1));
    $threePrimeFlank = substr($seq, ($normSnpStart + 1));
  }
  else {
    $fivePrimeFlank = substr($seq, 0, $normSnpStart);
    $threePrimeFlank = substr($seq, ($normSnpEnd  + 1));
  }


  my $newSeq =  $fivePrimeFlank. $base .$threePrimeFlank;
  $newSeq =~ s/\-//g;

  unless($newSeq =~ /$fivePrimeFlank/) {
    $self->error("Error in creating new Seq: \nnew=$newSeq\nold=$seq");
  }

  return($newSeq);
}

# ----------------------------------------------------------------------

sub _isSynonymous {
  my ($self, $codingSequence, $newCodingSequence) = @_;

  my $cds = Bio::Seq->new( -seq => $codingSequence );
  my $newCds = Bio::Seq->new( -seq => $newCodingSequence );

  my $translatedCds = $cds->translate();
  my $translatedNewCds = $newCds->translate();

  return($translatedCds->seq() eq $translatedNewCds->seq());
}

# ----------------------------------------------------------------------

sub _isSnpPositionOk {
  my ($self, $naSeq, $base, $naLoc, $isReverse) = @_;

  return(1) if($isReverse eq "NA");

  my $snpStart = $naLoc->getStartMin();
  my $snpEnd = $naLoc->getEndMax();

  my $lengthOfSnp = $snpEnd - $snpStart + 1;

  my $referenceBase = $naSeq->getSubstrFromClob('sequence', $snpStart, $lengthOfSnp);

  if($isReverse) {
    $referenceBase = CBIL::Bio::SequenceUtils::reverseComplementSequence($referenceBase);
  }

  return($referenceBase eq $base);
}

# ----------------------------------------------------------------------

sub _getAminoAcidSequenceOfSnp {
  my ($self, $codingSequence, $start, $end) = @_;

  my $cds = Bio::Seq->new( -seq => $codingSequence );
  my $translated = $cds->translate();

  my $lengthOfSnp = $end - $start + 1;

  return(substr($translated->seq(), $start, $lengthOfSnp));
}

# ----------------------------------------------------------------------

sub undoTables {
  my ($self) = @_;

  return ('DoTS.NALocation',
	  'DoTS.SeqVariation',
          'DoTS.SnpFeature',
	 );
}

1;
