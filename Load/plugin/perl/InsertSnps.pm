package ApiCommonData::Load::Plugin::InsertSnps;
@ISA = qw(GUS::PluginMgr::Plugin);



use strict;

use GUS::PluginMgr::Plugin;

use GUS::Model::SRes::SequenceOntology;
use GUS::Model::SRes::ExternalDatabase;
use GUS::Model::SRes::ExternalDatabaseRelease;

use GUS::Model::DoTS::SeqVariation;
use GUS::Model::DoTS::NALocation;
use GUS::Model::DoTS::SnpFeature;
use GUS::Model::DoTS::Transcript;

use Error qw (:try);

use Bio::Seq;
use Bio::Tools::GFF;
use CBIL::Bio::SequenceUtils;

use Benchmark;

use Data::Dumper;


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
		descr => 'sres.externaldatabase.name for the reference genome sequences',
		constraintFunc => undef,
		reqd => 1,
		isList => 0
	       }),
     stringArg({name => 'naExternalDatabaseVersion',
		descr => 'sres.externaldatabaserelease.version for the reference genome sequences',
		constraintFunc => undef,
		reqd => 1,
		isList => 0
	       }),
     stringArg({name => 'transcriptExternalDatabaseName',
		descr => 'sres.externaldatabase.name for the annotated transcript sequences',
		constraintFunc => undef,
		reqd => 1,
		isList => 0
	       }),
     stringArg({name => 'transcriptExternalDatabaseVersion',
		descr => 'sres.externaldatabaserelease.version for the annotated transcript sequences',
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
     stringArg({name => 'gffFormat',
		descr => 'Which gff format is the gff file in',
		constraintFunc=> undef,
		reqd  => 0,
                default => '2',
		isList => 0,
	       }),
     booleanArg({name => 'NGS_SNP',
		descr => 'these snps are being generated as NGS snps and will reuse the snp at this location',
		constraintFunc=> undef,
		reqd  => 0,
                default => 0,
		isList => 0,
	       }),
     booleanArg({name => 'NgsUpdateSnpFeature',
		descr => 'if NGS_SNP then will only update the SNP feature based on the SeqVariations if this is set to true',
		constraintFunc=> undef,
		reqd  => 0,
                default => 0,
		isList => 0,
	       }),

    ];
  return $argsDeclaration;
}

# ----------------------------------------------------------------------
# Documentation
# ----------------------------------------------------------------------

sub getDocumentation {
  my $purposeBrief = "Inserts SNP data into DoTS.SeqVariation and DoTS.SnpFeature and the location into DoTS.NALocation";

  my $purpose = "Inserts SNP information from a gff formatted file into into DoTS.SeqVariation and DoTS.SnpFeature and the location into DoTS.NALocation.";

  my $tablesAffected = [['DoTS::SeqVariation', 'One or more rows inserted per SNP, row number equal to strain number'],['DoTS::NALocation', 'A single row inserted per SNP']];

  my $tablesDependedOn = [['SRes::SequenceOntology',  'SequenceOntology term equal to SNP required']];

  my $howToRestart = "Use restart option and last processed row number from STDOUT file.";

  my $failureCases = "";

  my $notes = "The gff file contains snp data on either + or - strand ALWAYS in the 5 prime to 3 prime orientation.  The reference_NA in SnpFeature and the allele in seqvariation will be reverse complimented if the gff file strand is reverse.  The plugin will die if no strand is provided in the gff file.  The coding sequence and amino acid sequence is generated and stored in whatever orientation the gene is.  THE RESULT IS:  For SnpFeature, the reference_NA is always for the + strand and the refernece_AA is dependent on the orientation of the coding gene (the amino acid is only reported for coding genes).  The same goes for allele and product in the seqvariation table.";

  my $documentation = {purpose=>$purpose, purposeBrief=>$purposeBrief, tablesAffected=>$tablesAffected, tablesDependedOn=>$tablesDependedOn, howToRestart=>$howToRestart, failureCases=>$failureCases,notes=>$notes};

  return $documentation;
}

# ----------------------------------------------------------------------
# create and initalize new plugin instance.
# ----------------------------------------------------------------------

sub new {
  my ($class) = @_;
  my $self = {na_sequences => []
             };
  bless($self,$class);

  my $documentation = &getDocumentation();
  my $argumentDeclaration = &getArgumentsDeclaration();


  $self->initialize({requiredDbVersion => 3.6,
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

  ##set so doesn't update the algorithminvocation of updated objects
  $self->getDb()->setDoNotUpdateAlgoInvoId(1);

  ##we aren't using the version tables anymore given the workflow so set so doesn't version .. .more efficient
  $self->getDb()->setGlobalNoVersion(1);

  my $termName = $self->getArg('ontologyTerm');
  $self->{'soId'} = $self->getSoId($termName);

  die "The term $termName was not found in the Sequence Ontology.\n" unless $self->{'soId'};

  if($self->getArg('NGS_SNP')) {
    $self->{'ngsSnpExtDbRlsId'} = $self->getNgsSnpExtDbRlsId();
  }

  $self->{'snpExtDbRlsId'} = $self->getExtDbRlsId($self->getArg('snpExternalDatabaseName'),$self->getArg('snpExternalDatabaseVersion'));
  $self->{'naExtDbRlsId'} = $self->getExtDbRlsId($self->getArg('naExternalDatabaseName'),$self->getArg('naExternalDatabaseVersion'));
  $self->{'transcriptExtDbRlsId'} = $self->getExtDbRlsId($self->getArg('transcriptExternalDatabaseName'),$self->getArg('transcriptExternalDatabaseVersion'));

  $self->{'sequencePieces'} = $self->queryForSequencePieces();

  my $file = $self->getArg('snpFile');

  my $gffIO = Bio::Tools::GFF->new(-file => $file,
                                   -gff_version => $self->getArg('gffFormat'),
                                  );

  my $naSeqToLocationsHashRef =  $self->getAllTranscriptLocations ();

  my ($linesProcessed) = $self->processSnpFile($gffIO, $naSeqToLocationsHashRef);

  return "$linesProcessed lines of SNP file $file processed\n";
}

# ----------------------------------------------------------------------

sub queryForSequencePieces {
  my ($self) = @_;

  my $dbh = $self->getQueryHandle();

  my $sql = "select sp.virtual_na_sequence_id
                  , p.na_sequence_id
                  , sp.strand_orientation
                  , p.length
                  , sp.distance_from_left as start_min
                  , sp.distance_from_left + p.length as end_max
           from dots.sequencepiece sp
                , dots.nasequence p 
           where  sp.piece_na_sequence_id = p.na_sequence_id";


  my $sh = $dbh->prepare($sql);
  $sh->execute();
  my @sequencePieces;

  while(my $hash = $sh->fetchrow_hashref()) {
    push @sequencePieces, $hash;
  }

  $sh->finish();

  return \@sequencePieces;
}


# ----------------------------------------------------------------------

sub getNgsSnpExtDbRlsId {
  my ($self) = @_;

  my $reference = $self->getArg('reference');

  my $sql = "select abbrev  from apidb.organism where strain_abbrev = ?";

  my $sh = $self->getQueryHandle()->prepare($sql);
  $sh->execute($reference);

  my ($orgAbbrev, $count);
  while(my ($abbrev) = $sh->fetchrow_array()) {
    $orgAbbrev = $abbrev;
    $count++;
  }

  $sh->finish();
  unless($count == 1) {
    $self->error("Error getting the organism abbreviation for strain $reference");
  }

  my $NGS_SNP_DB_NAME = "InsertSnps.pm NGS SNPs INTERNAL";
  my $NGS_SNP_DB_VERSION = "Ref:  $orgAbbrev";

  my $extDb = GUS::Model::SRes::ExternalDatabase->new({name => $NGS_SNP_DB_NAME});
  my $extDbRls = GUS::Model::SRes::ExternalDatabaseRelease->new({version => $NGS_SNP_DB_VERSION});

  my $foundExtDb = $extDb->retrieveFromDB();
  if($extDb->getNumberOfDatabaseRows() > 1) {
    $self->error("Found multiple rows in the database for SRes.ExternalDatabase name:  $NGS_SNP_DB_NAME");
  }

  $extDbRls->setParent($extDb);

  my $foundExtDbRls = $extDbRls->retrieveFromDB();
  if($extDbRls->getNumberOfDatabaseRows() > 1) {
    $self->error("Found multiple rows in the database for SRes.ExternalDatabase name:  $NGS_SNP_DB_NAME");
  }

  if(!$foundExtDb || !$foundExtDbRls) {
    $self->error("Error getting the NGS ExternalDatabaes name $NGS_SNP_DB_NAME with version $NGS_SNP_DB_VERSION");
  }

  return $extDbRls->getId();
}


sub primaryLocationFromVirtualLocation {
  my ($self, $virtualSequenceId, $virtualLocation, $sequencePieces) = @_;

  my $sequencePiece = $self->findSequencePiece($virtualSequenceId, $virtualLocation, $sequencePieces);

  return($virtualSequenceId, $virtualLocation) unless($sequencePiece);

  my $pieceId = $sequencePiece->{NA_SEQUENCE_ID};

  my $pieceLoc;
  if($sequencePiece->{STRAND_ORIENTATION} eq '-') {
    $pieceLoc = $sequencePiece->{LENGTH} - ($virtualLocation - $sequencePiece->{START_MIN}) + 1;
  }
  else {
    $pieceLoc = $virtualLocation - $sequencePiece->{START_MIN};
  }

  $self->primaryLocationFromVirtualLocation($pieceId, $pieceLoc);
}


sub findSequencePiece {
  my ($self, $virtualSequenceId, $location, $sequencePieces) = @_;

  foreach my $piece (@$sequencePieces) {
    return $piece if($piece->{VIRTUAL_NA_SEQUENCE_ID} == $virtualSequenceId &&
                     $piece->{START_MIN} <= $location &&
                     $piece->{END_MAX} >= $location);
  }
  return undef;
}



sub processSnpFile{
  my ($self, $gffIO, $naSeqToLocationsHashRef) = @_;

  my $lineNum = $self->getArg('restart') ? $self->getArg('restart') : 0;
  my $num = 0;

  my $transcripts = {};

  while (my $feature = $gffIO->next_feature()) {
    $num++;

    next if ($self->getArg('restart') && $num <= $lineNum);

    my $snpFeature = $self->createSnpFeature($feature);

    my $snpStart = $feature->location()->start();
    my $snpEnd = $feature->location()->end();
    
    my $naSeqId = $snpFeature->getNaSequenceId();

    my ($primaryNaSequenceId, $primarySnpStart) = $self->primaryLocationFromVirtualLocation($$naSeqId, $snpStart);
    my ($skipNaSequenceId, $primarySnpEnd) = $self->primaryLocationFromVirtualLocation($$naSeqId, $snpStart);

    # use mapped startEnd and nasequenceId
    my $transcript = $self->getTranscript($primaryNaSequenceId, $primarySnpStart, $primarySnpEnd, $naSeqToLocationsHashRef);
    my $transcriptId;
    
    # use mapped startEnd
    my ($codingSequence, $mockCodingSequence) = $self->getCodingAndMockSequencesForTranscript($transcript, $primarySnpStart, $primarySnpEnd, $transcripts);
    
    my $isCoding = $codingSequence ne $mockCodingSequence;
    
    my ($codingSnpStart, $codingSnpEnd) = $self->getCodingSubstitutionPositions($codingSequence, $mockCodingSequence);
    
    if($transcript) {
      $transcriptId = $transcript->getId();
    
      my $geneFeatureId = $transcript->get('parent_id');
      $snpFeature->set('parent_id', $geneFeatureId);
    }
    $self->_updateSequenceVars($snpFeature, $codingSequence, $codingSnpStart, $codingSnpEnd, $isCoding, $transcriptId);
    ##have snpFeature with all seqvars here .. only want to update if new snpfeature || !NGS_SNP || NgsUpdateSnpFeature
    if(!$snpFeature->getModificationDate() || !$self->getArg('NGS_SNP') || $self->getArg('NgsUpdateSnpFeature')){

      if($isCoding) {
        $snpFeature->setIsCoding(1);
        $snpFeature->setPositionInCds($codingSnpStart);
        
        my $startPositionInProtein = $self->calculateAminoAcidPosition($codingSnpStart);
        my $endPositionInProtein = $self->calculateAminoAcidPosition($codingSnpEnd);

        ## THE POSTION IN PROTEIN IS WHERE THE SNP STARTS...
        $snpFeature->setPositionInProtein($startPositionInProtein);

        my $refAaSequence = $self->_getAminoAcidSequenceOfSnp($codingSequence, $startPositionInProtein, $endPositionInProtein);
        $snpFeature->setReferenceAa($refAaSequence);
      } else {
        $snpFeature->setIsCoding(0);
      }

      $self->_makeSnpFeatureDescriptionFromSeqVars($snpFeature, $isCoding);

      $self->_addMajorMinorInfo($snpFeature);
    }

    $snpFeature->submit() || die "couldn't submit snpFeature for '$snpFeature'";

    $self->undefPointerCache();

    $lineNum++;

    $self->log("processed $lineNum lines from gff file.") if($lineNum % 500 == 0);
  }
  return $lineNum;
}

# ----------------------------------------------------------------------

sub _addMajorMinorInfo {
  my ($self, $snpFeature) = @_;

  my @seqVars = $snpFeature->getChildren('GUS::Model::DoTS::SeqVariation');
  my $sourceId = $snpFeature->getSourceId();

  my $referenceAllele = $snpFeature->getReferenceNa();
  my $referenceProduct = $snpFeature->getReferenceAa();

  my (%alleles, %products);

  foreach my $seqVar (@seqVars) {
    my $allele = $seqVar->getAllele();
    my $product = $seqVar->getProduct();

    $alleles{$allele}++;
    $products{$allele} = $product if($product);
  }

  my %counts;
  foreach(keys %alleles) {
    my $count = $alleles{$_};
    $counts{$count} = 1;
  }

  my (@sortedAlleleKeys, $nullAllele);
  foreach my $allele (sort {$alleles{$b} <=> $alleles{$a}} keys %alleles){
    if($allele eq "") {
      $nullAllele = 1;
    }
    else {
      push(@sortedAlleleKeys, $allele) ;
    }
  }

  my $numbers = scalar(keys %counts);

  if(scalar(@sortedAlleleKeys) == 1 && !$nullAllele) {
    $self->log("WARNING","No Variation for source_id [$sourceId]");
  }

  my $majorAllele = @sortedAlleleKeys[0];
  my $minorAllele = @sortedAlleleKeys[1];

  if($numbers == 1) {
    if($minorAllele eq $referenceAllele) {
      $minorAllele = $majorAllele;
      $majorAllele = $referenceAllele;
    }
    else {   
      $majorAllele = $referenceAllele;
    }
  }
  if($numbers == 2) {
    $minorAllele = $referenceAllele
      unless($majorAllele eq $referenceAllele || $minorAllele eq $referenceAllele);
  } 

  my $majorAlleleCount = $alleles{$majorAllele};
  my $minorAlleleCount = $alleles{$minorAllele};

  my $majorProduct = $products{$majorAllele};
  my $minorProduct = $products{$minorAllele};

  $snpFeature->setMajorAllele($majorAllele);
  $snpFeature->setMajorAlleleCount($majorAlleleCount);
  $snpFeature->setMajorProduct($majorProduct);
  $snpFeature->setMinorAllele($minorAllele);
  $snpFeature->setMinorAlleleCount($minorAlleleCount);
  $snpFeature->setMinorProduct($minorProduct);

  return($snpFeature);
}


# ----------------------------------------------------------------------

sub _makeSnpFeatureDescriptionFromSeqVars {
  my ($self, $snpFeature, $isCoding) = @_;

  my @seqVars = $snpFeature->getChildren('GUS::Model::DoTS::SeqVariation');

  my (@strains, @strainsRevComp);

  foreach my $seqVar (@seqVars) {
    my $strain = $seqVar->getStrain();
    my $allele = $seqVar->getAllele();
    my $product = $seqVar->getProduct();

    $strain =~ s/\s//g;
    $allele =~ s/\s//g;
    $product =~ s/\s//g;

    my $revCompAllele = CBIL::Bio::SequenceUtils::reverseComplementSequence($allele);

    if($isCoding) {
      push(@strains, "\"$strain\:$allele\:$product\"");
      push(@strainsRevComp, "\"$strain\:$revCompAllele\:$product\"");

    } 
    else {
      push(@strains, "\"$strain\:$allele\"");
      push(@strainsRevComp, "\"$strain\:$revCompAllele\"");
    }
  }

  my $strains = join(' ', @strains);
  my $strainsRevComp = join(' ', @strainsRevComp);

  $snpFeature->setStrains($strains);
  $snpFeature->setStrainsRevcomp($strainsRevComp);

  return($snpFeature);
}


# ----------------------------------------------------------------------

sub _updateSequenceVars {
  my  ($self, $snpFeature, $cds, $start, $end, $isCoding, $transcriptId) = @_;

  my @seqVars = $snpFeature->getChildren('GUS::Model::DoTS::SeqVariation');

  my $referenceAllele = $snpFeature->getReferenceNa();

  foreach my $seqVar (@seqVars) {
    my ($phenotype);

    my $variationAllele = $seqVar->getAllele();
    my $matchesReference = $variationAllele eq $referenceAllele ? 1 : 0;
    $seqVar->setMatchesReference($matchesReference);


    next unless($variationAllele);

    my $isSynonymous;
    if($isCoding) {

      #If the transcript is on the reverse strand we must reverse compliment!!
      if($self->{reverse_coding_transcripts}->{$transcriptId}) {
        $variationAllele = CBIL::Bio::SequenceUtils::reverseComplementSequence($variationAllele);
      }

      my $newCodingSequence = $self->_swapBaseInSequence($cds, 1, 1, $start, $end, $variationAllele, '');
      $isSynonymous = $self->_isSynonymous($cds, $newCodingSequence);

      $snpFeature->setHasNonsynonymousAllele(1) if($isSynonymous == 0);

      my $startPositionInProtein = $self->calculateAminoAcidPosition($start);
      my $endPositionInProtein = $self->calculateAminoAcidPosition($end);

      my $snpAaSequence = $self->_getAminoAcidSequenceOfSnp($newCodingSequence, $startPositionInProtein, $endPositionInProtein);
      $seqVar->setProduct($snpAaSequence);

    }
    my $phenotype = $self->calculatePhenotype($matchesReference, $isCoding, $isSynonymous);
    $seqVar->setPhenotype($phenotype);
  }
}

# ----------------------------------------------------------------------

sub calculatePhenotype {
  my ($self, $matchesReference, $isCoding, $isSynonymous) = @_;

  my $phenotype;

  if($matchesReference) {
    $phenotype = 'wild_type';
  }
  elsif($isCoding && $isSynonymous) {
    $phenotype = 'synonymous';
  }
  elsif($isCoding && !$isSynonymous) {
    $phenotype = 'non-synonymous';
  }
  else {
    $phenotype = 'non_coding';
  }

  return($phenotype);
}


# ----------------------------------------------------------------------

sub createSnpFeature {
  my ($self,$feature) = @_;

  my $name = $feature->primary_tag();
  my $sfName = $name =~ /(insertion|deletion)/ ? 'indel' : $name;

  my $ngsExtDbRlsId = $self->{'ngsSnpExtDbRlsId'};
  my $extDbRlsId = $self->{'snpExtDbRlsId'};
  my $soId = $self->getSoId($name);
  my $sfSoId = $self->getSoId($sfName);


  my ($sourceId) = $feature->get_tag_values('ID');
  my $organism = $self->getArg('organism');

  my $start = $feature->location()->start();
  my $end = $feature->location()->end();
  my $lengthOfSnp = $end - $start + 1;
  # Start and Stop are absolute genomic coordinates !!
  $self->userError("Snp end is less than snp start in file: $!") if($end < $start);

  my $strand = $feature->location()->strand();

  my $ref = $self->getArg('reference');

  my $snpFeature = GUS::Model::DoTS::SnpFeature->
    new({name => $sfName,
         sequence_ontology_id => $sfSoId,
         source_id => $sourceId,
         reference_strain => $ref,
         organism => $organism,
	});


  if($self->getArg('NGS_SNP')) {
    $snpFeature->setExternalDatabaseReleaseId($ngsExtDbRlsId); 
  } 
  else {
    $snpFeature->setExternalDatabaseReleaseId($extDbRlsId); 
  }



  my $naSeq = $self->getNaSeq($feature->seq_id());
  $snpFeature->setParent($naSeq);
  $snpFeature->setNaSequenceId($naSeq->getNaSequenceId()); ##don't remember if retrieveFromDB sets this before retrieving so do explicitly here.

  ##note that if NGS_SNP then want to retrievefromdb and also retrieve all existing seqvars from db
  ## so can generate complete picture of snp.
  my $fromDB = 0;
  $fromDB = $snpFeature->retrieveFromDB(undef,1) if $self->getArg('NGS_SNP') || $self->getArg('restart');
  $snpFeature->retrieveChildrenFromDB('GUS::Model::DoTS::SeqVariation') if $self->getArg('NGS_SNP') && $self->getArg('NgsUpdateSnpFeature');

  my $naLoc;
  if(! $fromDB){
    $naLoc = $self->getNaLoc($start, $end);
    $snpFeature->addChild($naLoc);
  }else{
    $naLoc = $snpFeature->getChild("GUS::Model::DoTS::NALocation",1);
  }

  foreach ($feature->get_tag_values('Allele')) {
    my ($strain, $base, $coverage, $percent, $quality, $pvalue, $seqVarExtRelId) = split(':', $_);

    # Reverse Compliment if it is on the Reverse Strand
    if($strand == -1) {
      $base = CBIL::Bio::SequenceUtils::reverseComplementSequence($base);
    }

    if($strand == 0) {
      $self->userError("Unknown strand for sourceId $sourceId");
    }

    if(lc($ref) eq lc($strain)) {
      $snpFeature->setReferenceNa($base);
      $self->_isSnpPositionOk($naSeq, $base, $naLoc, $sourceId);
    }

    my $seqVarSoTerm = $self->getSeqVarSoTerm($start, $end, $base);
    $soId = $self->getSoId($seqVarSoTerm) unless $self->getArg('NGS_SNP');

    my $seqVar =  GUS::Model::DoTS::SeqVariation->
      new({'source_id' => $sourceId,
           'external_database_release_id' => $seqVarExtRelId ? $seqVarExtRelId : $extDbRlsId,
           'name' => $name,
           'sequence_ontology_id' => $soId,
           'strain' => $strain,
           'allele' => $base,
           'organism' => $organism
          });

    $seqVar->retrieveFromDB() if $self->getArg('restart');

    ## deal with atts for NGS SNPs .. 
    $seqVar->setCoverage($coverage) if $coverage;
    if($percent){
	$percent =~ s/\%//g;
	$seqVar->setAllelePercent($percent);
    }
    $seqVar->setPvalue($pvalue) if ($pvalue || $pvalue == 0);
    $seqVar->setQuality($quality) if $quality;

    $seqVar->setParent($snpFeature);
    $seqVar->setParent($naSeq);
  }
## don't know why we need all these locations for seqvariations ... they are always the same as the parent snpfeature
#    my $svLoc = $self->getNaLoc($start, $end);
#    $seqVar->addChild($svLoc);

  ## need to add a seqvar for the reference genome if that hasn't been added already.
  my $haveRef = 0;
  my $referenceBase = $naSeq->getSubstrFromClob('sequence', $start, $lengthOfSnp);
  $snpFeature->setReferenceNa($referenceBase) unless ($snpFeature->getReferenceNa() && $snpFeature->getReferenceNa() eq $referenceBase);

  foreach my $c ($snpFeature->getChildren('GUS::Model::DoTS::SeqVariation')){
    unless($self->getArg('NGS_SNP')){
      $haveRef = 1 if (lc($c->getStrain()) eq lc($ref) && $c->getAllele() eq $referenceBase);
    }
  }

  if(($self->getArg('NGS_SNP') && !$fromDB) || $haveRef == 0){  ##create a reference seqvar here ...
    my $seqVar =  GUS::Model::DoTS::SeqVariation->
      new({'source_id' => $sourceId,
           'external_database_release_id' => $self->getArg('NGS_SNP') ? $naSeq->getExternalDatabaseReleaseId()  : $extDbRlsId,
           'name' => $name,
           'sequence_ontology_id' => $soId,
           'strain' => $ref,
           'allele' => $referenceBase,
           'organism' => $organism
          });
    $seqVar->setParent($snpFeature);
    $seqVar->setParent($naSeq);
    $snpFeature->setReferenceNa($referenceBase) unless ($snpFeature->getReferenceNa() && $snpFeature->getReferenceNa() eq $referenceBase);
  }

  return $snpFeature;
}

# ----------------------------------------------------------------------

sub getSoId {
  my ($self, $termName) = @_;

  if($self->{soIdList}->{$termName}){
    return $self->{soIdList}->{$termName};
  }

  my $so = GUS::Model::SRes::SequenceOntology->new({'term_name'=>$termName});

  if (!$so->retrieveFromDB()) {
    $self->error("No row has been added for term_name = $termName in the sres.sequenceontology table\n");
  }

  $self->{soIdList}->{$termName} = $so->getId();

  return $so->getId();

}

# ----------------------------------------------------------------------

sub getNaSeq {
  my ($self, $sourceId) = @_;

  my $extDbRlsId = $self->{'naExtDbRlsId'};

  my ($seqTable) = $self->getArg("seqTable");
  $seqTable = "GUS::Model::$seqTable";
  eval "require $seqTable";

  my $naSeq;
  unless($naSeq = $self->findFromNaSequences($sourceId, $extDbRlsId)) {
    $naSeq = $seqTable->new({'source_id'=>$sourceId,'external_database_release_id'=>$extDbRlsId});
    $naSeq->retrieveFromDB() || $self->error(" $sourceId does not exist in the database with database release = $extDbRlsId\n");

    $self->addToNaSequences($naSeq);
  }

  return $naSeq;
}

# ----------------------------------------------------------------------

sub getNaLoc {
  my ($self, $start, $end, $subseq) = @_;

  my $refLength = $end - $start + 1;
  my $varLength = length($subseq);

  my $locType;
  if ($self->getArg('ontologyTerm') eq 'SNP'){
    $locType = $refLength < $varLength ? 'insertion_site' : 'modified_base_site';
  }
  else {
    $locType = $refLength < $varLength ? 'insertion_site' : 'genetic_marker_site';
  }
  my $naLoc = GUS::Model::DoTS::NALocation->new({'start_min'=>$start,'start_max'=>$start,'end_min'=>$end,'end_max'=>$end,'location_type'=>$locType});

  return $naLoc;
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

  my @rnaFeatureExons = $transcript->getChildren("DoTS::RNAFeatureExon",1);

  my @exons = map { $_->getParent("DoTS::ExonFeature",1) } @rnaFeatureExons;

  #my @exons = $transcript->getChildren("DoTS::ExonFeature", 1);
  my $transcriptId = $transcript->getId();

  unless (@exons) {
    $self->error ("Transcript with na_feature_id = $transcriptId had no exons\n");
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

    # For a Snp to be considered coding...it must be totally included in the coding sequence
    my $isForwardCoding = $codingStart <= $snpStart && $codingEnd >= $snpEnd && !$exonIsReversed;
    my $isReverseCoding = $snpStart >= $codingEnd && $snpEnd <= $codingStart && $exonIsReversed;

    if($isReverseCoding) {
      $self->{reverse_coding_transcripts}->{$transcriptId} = 1;
    }

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
    push(@results, ($i + 1)) if($cdsArray[$i] ne $mockCdsArray[$i] && $mockCdsArray[$i] eq '*');
  }
  my $snpStart = $results[0];
  my $snpEnd = $results[scalar(@results) - 1];

  return($snpStart, $snpEnd);
}

# ----------------------------------------------------------------------

sub _swapBaseInSequence {
  my ($self, $seq, $exonStart, $exonEnd, $snpStart, $snpEnd, $base, $isReversed) = @_;

  my $normSnpStart = $isReversed ? $exonEnd - $snpEnd : $snpStart - $exonStart;
  my $normSnpEnd = $isReversed ? $exonEnd - $snpStart  : $snpEnd - $exonStart;

  my ($fivePrimeFlank, $threePrimeFlank);

  # An insertion is when the snpStart is one base less than the snpEnd
  # deletion have a base of '-' and are treated identically to substitutions

  $fivePrimeFlank = substr($seq, 0, $normSnpStart);
  $threePrimeFlank = substr($seq, ($normSnpEnd  + 1));

  my $newSeq =  $fivePrimeFlank. $base .$threePrimeFlank;
  $newSeq =~ s/\-//g;

  unless($newSeq =~ /$fivePrimeFlank/ || $newSeq =~ /$threePrimeFlank/) {
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
  my ($self, $naSeq, $base, $naLoc, $sourceId) = @_;

  my $snpStart = $naLoc->getStartMin();
  my $snpEnd = $naLoc->getEndMax();

  my $lengthOfSnp = $snpEnd - $snpStart + 1;

  my $referenceBase = $naSeq->getSubstrFromClob('sequence', $snpStart, $lengthOfSnp);

  if($referenceBase ne $base) {
    $self->log("WARNING: The snp base: $base doesn't match expected base $referenceBase for sourceId $sourceId .. is organism diploid?");
  }
  return(1);
}

# ----------------------------------------------------------------------

sub _getAminoAcidSequenceOfSnp {
  my ($self, $codingSequence, $start, $end) = @_;

  my $normStart = $start - 1;
  my $normEnd = $end - 1;

  my $cds = Bio::Seq->new( -seq => $codingSequence );
  my $translated = $cds->translate();

  my $lengthOfSnp = $normEnd - $normStart + 1;

  return(substr($translated->seq(), $normStart, $lengthOfSnp));
}

# ----------------------------------------------------------------------

sub getAllTranscriptLocations {
  my ($self) = @_;

  my %data;

  my $transcriptExtDbRls = $self->{'transcriptExtDbRlsId'};
  my $naExtDbRls = $self->{'naExtDbRlsId'};

#  my $seqTable = $self->getArg('seqTable');
#  $seqTable =~ s/::/./;

#  my $regex;
#  if($seqTable =~ /External/) {
#    $regex = "MAL\\d+";
#  }
#  elsif($seqTable =~ /Virtual/) {
#    $regex = "^([I,X,V])|(TG).+";
#  }
#  unless($seqTable =~ /DoTS\.ExternalN/ || $seqTable =~ /^DoTS\.Virtual/) {
#    $self->userError("Only ExternalNaSequence or VirtualSequence are supported for retrieving Transcripts");
#  }

#  my $sql = "SELECT tf.na_sequence_id, tf.na_feature_id, nl.start_min, nl.end_max
#             FROM dots.TRANSCRIPT tf, dots.NaLocation nl, $seqTable ens
#             WHERE tf.na_feature_id = nl.na_feature_id
#              AND tf.na_sequence_id = ens.na_sequence_id
#              AND regexp_like(ens.source_id, '$regex')
#            ORDER BY tf.na_sequence_id, nl.start_min, nl.end_max";

  # TODO:  Take out the seqontology_id...
#  my $sql = "SELECT tf.na_sequence_id, tf.na_feature_id, nl.start_min, nl.end_max
#             FROM dots.TRANSCRIPT tf, dots.NaLocation nl, $seqTable ens
#             WHERE tf.sequence_ontology_id = 121
#              AND tf.na_feature_id = nl.na_feature_id
#              AND tf.na_sequence_id = ens.na_sequence_id
#              AND ens.external_database_release_id = ?
#              and tf.external_database_release_id = ?
#              and tf.name != 'ORF'
#            ORDER BY nl.start_min, nl.end_max";

  my $sql = "SELECT gf.na_sequence_id, tf.na_feature_id, nl.start_min, nl.end_max
             FROM dots.TRANSCRIPT tf, dots.NaLocation nl, DoTS.SplicedNASequence ens, Dots.GeneFeature gf
             WHERE gf.na_feature_id = nl.na_feature_id
             and gf.na_feature_id = tf.parent_id
              AND tf.na_sequence_id = ens.na_sequence_id
              AND ens.external_database_release_id = $naExtDbRls
              and tf.external_database_release_id = $transcriptExtDbRls
            ORDER BY nl.start_min, nl.end_max";

  my $sh = $self->getQueryHandle()->prepare($sql);
  $sh->execute();

  while(my ($naSeqId, $naFeatureId, $start, $end) = $sh->fetchrow_array()) {
    my $location = { na_feature_id => $naFeatureId,
                     end => $end,
                     start => $start,
                   };
    push(@{$data{$naSeqId}}, $location);
  }

  return(\%data);
}

# ----------------------------------------------------------------------

sub getTranscript {
  my ($self, $naSeqId, $snpStart, $snpEnd, $transcriptToLocMap) = @_;
  return(undef) unless(ref ($transcriptToLocMap->{$naSeqId}) eq 'ARRAY');
  my @transcripts = @{$transcriptToLocMap->{$naSeqId}};
  my $startCursor = 0;
  my $endCursor = scalar(@transcripts) - 1;
  my $midpoint;

  return(undef) if($snpStart < $transcripts[$startCursor]->{start} || $snpEnd > $transcripts[$endCursor]->{end});

  while ($startCursor <= $endCursor) {
    $midpoint = int(($endCursor + $startCursor) / 2);

    my $location = $transcripts[$midpoint];

    if ($snpStart > $location->{start}) {
      $startCursor = $midpoint + 1;
    } 
    elsif ($snpStart < $location->{start}) {
      $endCursor = $midpoint - 1;
    }
    else {  }

    if($snpStart >= $location->{start} && $snpEnd <= $location->{end}) {

      my $transcriptFeatureId = $location->{na_feature_id};
      my $transcript = GUS::Model::DoTS::Transcript->new({ na_feature_id => $transcriptFeatureId });

      unless ($transcript->retrieveFromDB()) {
        $self->error("No Transcript row was fetched with na_feature_id = $transcriptFeatureId");
      }
      return($transcript);
    }
  }
  return(undef);
}

# ----------------------------------------------------------------------

sub getCodingAndMockSequencesForTranscript {
  my ($self, $transcript, $snpStart, $snpEnd, $transcripts) = @_;

  my ($codingSequence, $mockCodingSequence);
  return($codingSequence, $mockCodingSequence) unless($transcript);

  my $transcriptId = $transcript->getId();

  if($transcripts->{$transcriptId}) {
    $codingSequence = $transcripts->{$transcriptId}->{coding_sequence};
  }
  else {
    $codingSequence = $self->_getCodingSequence($transcript, $snpStart, $snpEnd, '');
    $transcripts->{$transcriptId}->{coding_sequence} = $codingSequence;
  }

  my $mockSequence = $self->createMockSequence($snpStart, $snpEnd);
  $mockCodingSequence = $self->_getCodingSequence($transcript, $snpStart, $snpEnd, $mockSequence);

  return($codingSequence, $mockCodingSequence);
}

# ----------------------------------------------------------------------

sub findFromNaSequences {
  my ($self, $querySourceId, $queryExternalDbRlsId) = @_;

  my $naSequences = $self->{na_sequences};

  foreach my $naSeq (@$naSequences) {
    my $extDbRlsId = $naSeq->getExternalDatabaseReleaseId();
    my $sourceId = $naSeq->getSourceId();

    if($queryExternalDbRlsId == $extDbRlsId && $querySourceId eq $sourceId) {
      return($naSeq);
    }
  }
  return(undef);
}

# ----------------------------------------------------------------------

sub addToNaSequences { 
  my ($self, $naSeq) = @_;

  push(@{$self->{na_sequences}}, $naSeq);
}

# ----------------------------------------------------------------------

sub calculateAminoAcidPosition {
  my ($self, $codingPosition) = @_;

  my $aaPos = ($codingPosition % 3 == 0) ? int($codingPosition / 3) : int($codingPosition / 3) + 1;

  return($aaPos);
}

# ----------------------------------------------------------------------

sub getSeqVarSoTerm {
  my ($self, $start, $end, $base) = @_;

  my $length = length($base);
  my $refLength = $end - $start + 1;

  if($end < $start) {
    $self->userError("The Reference Position End must be Greater than the start:  start=$start, end=$end");
  }

  if($length > $refLength) {
    return('insertion');
  }

  if($length == $refLength && $base !~ /-/) {
    return('substitution');
  }

  return('deletion');
}

# ----------------------------------------------------------------------

sub createMockSequence {
  my ($self, $snpStart, $snpEnd) = @_;

  my $length = $snpEnd - $snpStart + 1;
  my $mockString;

  foreach(1..$length) {
    $mockString = $mockString."*";
  }
  return($mockString);
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
