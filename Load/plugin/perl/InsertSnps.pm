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

  my ($linesProcessed) = $self->processSnpFile();

  my $file = $self->getArg('snpFile');

  return "$linesProcessed lines of SNP file $file processed\n";
}

sub processSnpFile{
  my ($self) = @_;

  my $lineNum = $self->getArg('restart') ? $self->getArg('restart') : 0;

  my $termName = $self->getArg('ontologyTerm');

  $self->{'soId'} = $self->getSoId($termName);

  die "The term $termName was not found in the Sequence Ontology.\n" unless $self->{'soId'};

  $self->{'snpExtDbRlsId'} = $self->getExtDbRlsId($self->getArg('snpExternalDatabaseName'),$self->getArg('snpExternalDatabaseVersion'));

  $self->{'naExtDbRlsId'} = $self->getExtDbRlsId($self->getArg('naExternalDatabaseName'),$self->getArg('naExternalDatabaseVersion'));

  my $file = $self->getArg('snpFile');

  my $num = 0;

  open (SNP, $file);

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

    my ($codingSequence, $isCoding, $transcript) = $self->_isCoding($naSeqId, $snpStart, $snpEnd);

    my $geneFeatureId;

    $snpFeature->setIsCoding($isCoding);

    if($transcript) {
      $geneFeatureId = $transcript->get('parent_id');
      $snpFeature->set('parent_id',$geneFeatureId);
    }

    my @seqVars = $snpFeature->getChildren('GUS::Model::DoTS::SeqVariation');


    foreach my $seqVar (@seqVars) {
      my $isSynonymous;

      my $base = $seqVar ->getAllele();

      my ($newCodingSequence) = $self->_getCodingSequence($transcript,$snpStart, $snpEnd,$base);
      $isSynonymous = $self->_isSynonymous($codingSequence, $newCodingSequence);

      my $phenotype = $isSynonymous == 1 ? 'synonymous' : 'non-synonymous';

      $seqVar->setPhenotype($phenotype);
#      $snpFeature->setIsSynonymous(0) if($isSynonymous == 0 && $snpFeature->getIsSynonymous() == 1);
    }

    $snpFeature->submit();

    $self->undefPointerCache();

    $lineNum++;

    if ($lineNum%10 == 0){
      $self->log("processed $lineNum lines from $file.\n");
    }
  }

  return $lineNum;
}

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

  my $ref = $self->getArg('reference');

  my $standard = ($end > $start) ? 'insertion' : 'substitution';



  my $snpFeature = GUS::Model::DoTS::SnpFeature->
    new({NAME => $name,
         SEQUENCE_ONTOLOGY_ID => $soId,
         EXTERNAL_DATABASE_RELEASE_ID => $extDbRlsId,
         SOURCE_ID => $sourceId,
         REFERENCE_STRAIN => $ref,
         ORGANISM => $organism,
         POSITION_IN_CDS => '',
	});

  $snpFeature->retrieveFromDB();

  my $naSeq = $self->getNaSeq($line);

  $naSeq->setChild($snpFeature);

  my $naLoc = $self->getNaLoc($line);

  $snpFeature->addChild($naLoc);


  while ($data[1] =~ m/(\w+):([\w\-]+)/g) {
    my $strain = $1;
    my $base = $2;

    if(lc($ref) eq lc($strain)) {
      $snpFeature->setReferenceCharacter($base);
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

sub getSoId {
  my ($self, $termName) = @_;

  my $so = GUS::Model::SRes::SequenceOntology->new({'term_name'=>$termName});

  if (!$so->retrieveFromDB()) {
    $self->error("No row has been added for term_name = SNP in the sres.sequenceontology table\n");
  }

  my $soId = $so->getId();

  return $soId;

}

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

sub _isCoding {
  my ($self, $naSeqId, $snpStart, $snpEnd) = @_;

  my $isCoding = 0;
  my ($codingSequence, $newCodingSequence, $transcript);

  my $sql = "SELECT tf.na_feature_id
             FROM dots.TRANSCRIPT tf, dots.NaLocation nl,dots.ExternalNaSequence ens
             WHERE tf.na_feature_id = nl.na_feature_id
              AND tf.na_sequence_id = ens.na_sequence_id 
              and nl.start_min <= $snpStart
              and nl.end_max >= $snpEnd
              and tf.na_sequence_id = $naSeqId";

  if(my ($transcriptFeatureId) = $self->sqlAsArray( Sql => $sql )) {

    $transcript = GUS::Model::DoTS::Transcript->new({ na_feature_id => $transcriptFeatureId });

    unless ($transcript->retrieveFromDB()) {
      $self->error("No Transcript row was fetched with na_feature_id = $transcriptFeatureId");
    }

    ($codingSequence,$isCoding) = $self->_getCodingSequence($transcript,$snpStart, $snpEnd);
  }
  return($codingSequence, $isCoding, $transcript);
}




sub _getCodingSequence {
  my ($self, $transcript, $snpStart, $snpEnd, $base) = @_;

  my $isCoding = 0;

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

    if($codingStart <= $snpStart && $codingEnd >= $snpEnd && !$exonIsReversed ) {
      $isCoding = 1;
    }

    if($codingStart >= $snpStart && $codingEnd <= $snpEnd && $exonIsReversed ) {
      $isCoding = 1;
    }

    if($base) {
      $chunk = $self->_swapBase($chunk, $exonStart, $exonEnd, $snpStart, $snpEnd, $base);
    }

    my $trim5 = $exonIsReversed ? $exonEnd - $codingStart : $codingStart - $exonStart;
    substr($chunk, 0, $trim5, "") if $trim5 > 0;
    my $trim3 = $exonIsReversed ? $codingEnd - $exonStart : $exonEnd - $codingEnd;
    substr($chunk, -$trim3, $trim3, "") if $trim3 > 0;

    $transcriptSequence .= $chunk;
  }
  return($transcriptSequence, $isCoding);
}

sub _swapBase {
  my ($self, $seq, $exonStart, $exonEnd, $snpStart, $snpEnd, $base) = @_;

  $snpStart = $snpStart - $exonStart;
  $snpEnd = $snpEnd - $exonStart;
  $exonEnd = $exonEnd - $exonStart;

  my ($fivePrimeFlank, $threePrimeFlank, $newSeq);

  #insertions: snpStart will be less than snpEnd and the base will not be a -
  #otherwise treat substitutions and deletions identically

  if($snpStart < $snpEnd && $base !~ /-/) {
    $fivePrimeFlank = substr($seq, 0,  ($snpStart + 1));
    $threePrimeFlank = substr($seq, ($snpStart + 1));
    $newSeq =  $fivePrimeFlank. $base .$threePrimeFlank;

    unless($newSeq =~ /^($fivePrimeFlank)[actgACTG]+($threePrimeFlank)$/) {
      $self->error("Error in creating new Seq: \nnew=$newSeq\nold=$seq");
    }
  }
  else {
    $fivePrimeFlank = substr($seq, 0, $snpStart);
    $threePrimeFlank = substr($seq, ($snpEnd  + 1));

    $newSeq =  $fivePrimeFlank. $base .$threePrimeFlank;
    $newSeq =~ s/\-//g;

    unless($newSeq =~ /^($fivePrimeFlank)[actgACTG]?/) {
      $self->error("Error in creating new Seq: \nnew=$newSeq\nold=$seq");
    }
  }
  return($newSeq);
}


sub _isSynonymous {
  my ($self, $codingSequence, $newCodingSequence) = @_;

  my $cds = Bio::Seq->new( -seq => $codingSequence );
  my $newCds = Bio::Seq->new( -seq => $newCodingSequence );

  my $translatedCds = $cds->translate();
  my $translatedNewCds = $newCds->translate();

  if($translatedCds->seq() eq $translatedNewCds->seq()) {
    return(1);
  }
  return(0);
}


sub undoTables {
  my ($self) = @_;

  return ('DoTS.NALocation',
	  'DoTS.SeqVariation',
          'DoTS.SnpFeature',
	 );
}

1;
