package ApiCommonData::Load::Plugin::LoadEstsFromFastaFile;

@ISA = qw(GUS::PluginMgr::Plugin);
use strict;
use GUS::PluginMgr::Plugin;
use File::Basename;
use GUS::Model::DoTS::ExternalNASequence;
use GUS::Model::DoTS::EST;
use GUS::Model::DoTS::Library;
use GUS::Model::SRes::Contact;
use GUS::Model::SRes::Taxon;
use GUS::Model::SRes::SequenceOntology;
use Bio::PrimarySeq;
use Bio::Tools::SeqStats;

my $argsDeclaration =[];
my $purposeBrief = 'Insert EST sequences from a FASTA file.';

my $purpose = <<PLUGIN_PURPOSE;
Insert or update sequences from a FASTA.  A set of regular expressions provided on the command line extract from the definition lines of the input sequences various information to stuff into the database.
PLUGIN_PURPOSE

my $tablesAffected =
  [ ['DoTS::EST','One row per EST'],['DoTS::ExternalNASequence', 'one row per EST'],['SRES::Contact','one row per library'],['SRES::Library','one row per library']
  ];

my $tablesDependedOn =
  [['SRES::Taxon','taxon_id required for library and externalnasequence tables'],['SRes::SequenceOntology',  'SequenceOntology term for EST']
  ];

  my $howToRestart = "Get the total number of ESTs processed from log file, second column, that number plus one for startAt argument"; 

  my $failureCases = <<PLUGIN_FAILURE_CASES;
PLUGIN_FAILURE_CASES

my $notes = <<PLUGIN_NOTES;

PLUGIN_NOTES


  my $documentation = { purpose=>$purpose,
                        purposeBrief=>$purposeBrief,
                        tablesAffected=>$tablesAffected,
                        tablesDependedOn=>$tablesDependedOn,
                        howToRestart=>$howToRestart,
                        failureCases=>$failureCases,
                        notes=>$notes
                      };

my $argsDeclaration =
[
 stringArg({ name            => 'sourceIdRegex',
             descr           => 'regex for identifier from defline, for xest.accession and externalnasequence.source_id',
             reqd            => 1,
             constraintFunc  => undef,
             isList          => 0 }),

stringArg({ name            => 'checkSQL',
             descr           => 'sql statement used to query for na_sequence_id of an EST that is already in the database',
             reqd            => 0,
             constraintFunc  => undef,
             isList          => 0 }),

 stringArg({ name            => 'qualityStartRegex',
             descr           => 'regex to find start of quality sequence, otherwise set to 1',
             reqd            => 0,
             constraintFunc  => undef,
             isList          => 0 }),

 stringArg({ name            => 'possiblyReversedRegex',
             descr           => 'regex for whether sequence is reversed',
             reqd            => 0,
             constraintFunc   => undef,
             isList          => 0 }),

 stringArg({ name            => 'poorQualityRegex',
             descr           => 'regex for poor quality trace from defline, otherwise set to 0',
             reqd            => 0,
             constraintFunc  => undef,
             isList          => 0 }),

 booleanArg({name            => 'possiblyReversed',
             descr     => 'if likely reversed, field will be set to 1 in EST table for all sequences in file, alternative to regex',
             reqd            => 0,
             constraintFunc   => undef,
             isList         => 0 }),

 integerArg({name            => 'startAt',
             descr     => 'number of entry to begin loading, for restart',
             reqd            => 0,
             constraintFunc   => undef,
             isList         => 0 }),

 stringArg({ name            => 'putativeFullLengthRegex',
             descr           => 'regex for whether sequence is supposed to be full length',
             reqd            => 0,
             constraintFunc   => undef,
             isList          => 0 }),

 booleanArg({name            => 'putativeFullLength',
             descr     => 'indicates all sequences are putatively full length, alternative to regex',
             reqd            => 0,
             constraintFunc   => undef,
             isList          => 0 }),

 fileArg({   name            => 'fastaFile',
	     descr           => 'The name of the input fasta file',
	     reqd            => 1,
	     constraintFunc  => undef,
             mustExist       => 1,
             format          =>"",
             isList          => 0 }),

 stringArg({ name            => 'externalDatabaseName',
	     descr           => 'The name of the ExternalDatabase from which the input sequences have come',
	     reqd            => 1,
	     constraintFunc  => undef,
	     isList          => 0 }),

 stringArg({ name            => 'externalDatabaseVersion',
	     descr           => 'The version of the ExternalDatabaseRelease from whith the input sequences have come',
	     reqd            => 1,
	     constraintFunc  => undef,
	     isList          => 0 }),

 stringArg({  name           => 'SOTermName',
	      descr          => 'The Sequence Ontology term for the sequence type',
	      reqd           => 1,
	      constraintFunc => undef,
	      isList         => 0 }),

 integerArg({  name           => 'ncbiTaxId',
	       descr          => 'The taxon id from NCBI for these sequences.',
	       reqd           => 1,
	       constraintFunc => undef,
	       isList         => 0 }),

 stringArg({   name           => 'regexSecondaryId',
	       descr          => 'The regular expression to pick the secondary id of the sequence from the defline',
	       reqd           => 0,
	       constraintFunc => undef,
	       isList         => 0 }),

 stringArg({   name           => 'regexDesc',
	       descr          => 'The regular expression to pick the description of the sequence from the defline',
	       reqd           => 0,
	       constraintFunc => undef,
	       isList         => 0 }),

 stringArg({   name           => 'regexSeqVersion',
	       descr          => 'The regular expression to pick the sequence version e.g. >\S+\.(\d+) for >NM_47654.1',
	       reqd           => 0,
	       constraintFunc => undef,
	       isList         => 0 }),

 stringArg({   name           => 'contactName',
	       descr          => 'Name of contact, used to create row in contact table',
	       reqd           => 1,
	       constraintFunc => undef,
	       isList         => 0 }),

stringArg({   name           => 'contactAddress1',
	       descr          => 'First line of address for contact, used to create row in contact table',
	       reqd           => 1,
	       constraintFunc => undef,
	       isList         => 0 }),

stringArg({   name           => 'contactAddress2',
	       descr          => 'Second line of address for contact, used to create row in contact table',
	       reqd           => 1,
	       constraintFunc => undef,
	       isList         => 0 }),

stringArg({   name           => 'contactEmail',
	       descr          => 'Email for contact, used to create row in contact table',
	       reqd           => 0,
	       constraintFunc => undef,
	       isList         => 0 }),

stringArg({   name           => 'contactPhone',
	       descr          => 'Phone for contact, used to create row in contact table',
	       reqd           => 0,
	       constraintFunc => undef,
	       isList         => 0 }),

stringArg({   name           => 'contactFax',
	       descr          => 'Fax for contact, used to create row in contact table',
	       reqd           => 0,
	       constraintFunc => undef,
	       isList         => 0 }),

 stringArg({   name           => 'libraryStrain',
	       descr          => 'organism strain from which library mRNA was derived',
	       reqd           => 0,
	       constraintFunc => undef,
	       isList         => 0 }),

 stringArg({   name           => 'libraryVector',
	       descr          => 'vector used for the creation of the library clones',
	       reqd           => 0,
	       constraintFunc => undef,
	       isList         => 0 }),

 stringArg({   name           => 'libraryStage',
	       descr          => 'vector used for the creation of the library clones',
	       reqd           => 0,
	       constraintFunc => undef,
	       isList         => 0 }),

 stringArg({   name           => 'libraryDesc',
	       descr          => 'Description of the sequence from the defline for comment_string field of library table',
	       reqd           => 0,
	       constraintFunc => undef,
	       isList         => 0 }),

 stringArg({   name           => 'libraryName',
	       descr          => 'name of library for dbest_name field of library table',
	       reqd           => 1,
	       constraintFunc => undef,
	       isList         => 0 }),

 booleanArg({  name           => 'isImage',
	       descr          => 'true if sequences are from IMAGE consortium, otherwise will be set to 0',
	       reqd           => 0,
	       constraintFunc   => undef,
	       default        => 0 }),
];


sub new() {
  my ($class) = @_;
  my $self = {};
  bless($self,$class);

  $self->initialize({requiredDbVersion => 3.5,
		     cvsRevision => '$Revision$', # cvs fills this in!
		     name => ref($self),
		     argsDeclaration   => $argsDeclaration,
		     documentation     => $documentation
		    });
  return $self;
}


$| = 1;

sub run {
  my $self  = shift;

  $self->{totalCount} = 0;
  $self->{skippedCount} = 0;

  $self->{external_database_release_id} =
    $self->getExtDbRlsId($self->getArg('externalDatabaseName'),
			 $self->getArg('externalDatabaseVersion'));

  $self->log("loading sequences with external database release id $self->{external_database_release_id}");

  if ($self->getArg('SOTermName')) {
    $self->fetchSequenceOntologyId();
  }

  if ($self->getArg('ncbiTaxId')) {
    $self->fetchTaxonId();
  }

  $self->makeLibraryRow();

  $self->makeContactRow();

  $self->processFile();

  my $finalCount = $self->{totalCount} + $self->{skippedCount};

  my $res = "Run finished: $finalCount ESTs entered for library_id " . $self->{libraryId};
  return $res;


}

sub processFile{
    my ($self) = @_;

    my $file = $self->getArg('fastaFile');

    $self->logVerbose("loading sequences from $file\n");
    if ($file =~ /gz$/) {
	open(F, "gunzip -c $file |") || die "Can't open $file for reading";
    } else {
	open(F,"$file") || die "Can't open $file for reading";
    }

    my $source_id;
    my $description;
    my $secondary_id;
    my $seq;
    my $seq_version;
    my $possiblyReversed;
    my $putativeFullLength;
    my $poorQuality;
    my $seqLength;
    my $qualityStart;

    my $sql = $self->getArg('checkSQL') ? $self->getArg('checkSQL') : "select na_sequence_id from dots.externalnasequence where source_id = ? and external_database_release_id = $self->{external_database_release_id}";

    my $checkStmt = $self->getAlgInvocation()->getQueryHandle()->prepare($sql);


    while (<F>) {
	if (/^\>/) {                ##have a defline....need to process!

	    $self->undefPointerCache();

	    if ($self->getArg('startAt')
		&& $self->{skippedCount} < $self->getArg('startAt')) {
	      $self->{skippedCount}++;
	      $seq = "";
	      next;
	    }

	    if ($seq) {
	      $self->process($source_id,$secondary_id,$seq_version,$seq,$possiblyReversed,$putativeFullLength,$poorQuality,$seqLength,$qualityStart, $description);
      	    }

	    ##now get the ids etc for this defline...

	    my $sourceIdRegex = $self->getArg('sourceIdRegex');

	    if (/$sourceIdRegex/ && $1) {
		$source_id = $1;
	    } else {
	      my $forgotParens = ($sourceIdRegex !~ /\(/)? "(Forgot parens?)" : "";
	      $self->userError("Unable to parse source_id from $_ using regex '$sourceIdRegex' $forgotParens");
	    }

	    my $id = $self->checkIfInDb($checkStmt,$source_id);

	    if ($id) {
	      $source_id = "";
	      $self->log ("$source_id already in database with external_database_release_id $self->{external_database_release_id}");
	      next;
	    }

	    $secondary_id = ""; $seq_version = 1; $possiblyReversed = 0; $putativeFullLength = 0; $poorQuality = 0; $qualityStart = 1; $description = "";##in case can't parse out of this defline...

	    my $regexSecondaryId = $self->getArg('regexSecondaryId') if $self->getArg('regexSecondaryId');
	    if ($regexSecondaryId && /$regexSecondaryId/) {
	      $secondary_id = $1;
	    }


	    my $regexDescrip = $self->getArg('regexDesc') if $self->getArg('regexDesc');
	    if ($regexDescrip && /$regexDescrip/) {
	      $description = $1;
	    }


	    my $regexSeqVersion = $self->getArg('regexSeqVersion') if $self->getArg('regexSeqVersion');
	    if ($regexSeqVersion && /$regexSeqVersion/) {
		$seq_version = $1;
	    }

	    my $regexQualityStart = $self->getArg('qualityStartRegex') if $self->getArg('qualityStartRegex');
	    if ($regexQualityStart && /$regexQualityStart/) {
		$qualityStart = $1;
	    }

	    my $possiblyReversedRegex = $self->getArg('possiblyReversedRegex') if $self->getArg('possiblyReversedRegex');
	    if ($possiblyReversedRegex && /$possiblyReversedRegex/) {
	      $possiblyReversed = 1;
	    }
	    elsif ($self->getArg('possiblyReversed')) {
	      $possiblyReversed = 1;
	    }
	    else {
	      $possiblyReversed = 0;
	    }


	    my $putativeFullLengthRegex = $self->getArg('putativeFullLengthRegex') if $self->getArg('putativeFullLengthRegex');
	    if ($putativeFullLengthRegex && /$putativeFullLengthRegex/) {
	      $putativeFullLength = 1;
	    }
	    elsif ($self->getArg('putativeFullLength')) {
	      $putativeFullLength = 1;
	    }
	    else {
	      $putativeFullLength = 0;
	    }

	    my $poorQualityRegex = $self->getArg('poorQualityRegex') if $self->getArg('poorQualityRegex');
	    if ($poorQualityRegex && /$poorQualityRegex/) {
	      $poorQuality = 1;
	    }


	    ##reset the sequence..
	    $seq = "";
	}
	else {
	  $seq .= $_;
	  $seq =~ s/\s//g;
	  $seqLength = length($seq);
	}

      }

    $self->process($source_id,$secondary_id,$seq_version,$seq,$possiblyReversed,$putativeFullLength,$poorQuality,$seqLength,$qualityStart, $description) if ($source_id && $seq);
}

##SUBS

sub makeLibraryRow {
  my($self) = @_;

  my $name = $self->getArg('libraryName');

  my $taxonId = $self->{taxonId};

  my $isImage = $self->getArg('isImage') ? 1 : 0 ;

  my $library = GUS::Model::DoTS::Library->new({'dbest_name'=>$name,'taxon_id'=>$taxonId,'is_image'=>$isImage});

  unless ($library->retrieveFromDB()) {
    if ($self->getArg('libraryStrain')) {
      my $strain = $self->getArg('libraryStrain') ;
      $library->setStrain($strain);
    }
    if ($self->getArg('libraryVector')) {
      my $vector = $self->getArg('libraryVector');
      $library->setVector($vector);
    }
    if ($self->getArg('libraryStage')) {
      my $stage = $self->getArg('libraryStage');
      $library->setStage($stage);
    }
    if ($self->getArg('libraryDesc')) {
      my $description = $self->getArg('libraryDesc');
      $library->setCommentString($description);
    }
    $library->submit();
  }

  $self->{libraryId} = $library->getId();

  $library->undefPointerCache();
}

sub makeContactRow {
  my ($self) = @_;

  my $name = $self->getArg('contactName');

  my $address1 = $self->getArg('contactAddress1');

  my $address2 = $self->getArg('contactAddress2');

  my $contact = GUS::Model::SRes::Contact->new({'name'=>$name,'address1'=>$address1, 'address2'=>$address2 });

  unless($contact->retrieveFromDB()) {
    if ($self->getArg('contactEmail')) {
      my $email = $self->getArg('contactEmail');
      $contact->setEmail($email);
    }
    if ($self->getArg('contactPhone')) {
      my $phone = $self->getArg('contactPhone');
      $contact->setPhone($phone);
    }
    if ($self->getArg('contactFax')) {
      my $fax = $self->getArg('contactFax');
      $contact->setFax($fax);
    }
    $contact->submit();
  }

  $self->{contactId} = $contact->getId();

  $contact->undefPointerCache();
}

sub checkIfInDb {
  my ($self,$checkStmt,$source_id) = @_;

  $checkStmt->execute($source_id);
  if (my($id) = $checkStmt->fetchrow_array()) {
    $checkStmt->finish();
    return $id;
  }
  return 0;
}

sub process {
  my($self,$source_id,$secondary_id,$seq_version,$seq,$possiblyReversed,$putativeFullLength,$poorQuality,$seqLength,$qualityStart, $description) = @_;

  my $nas = $self->createNewExternalSequence($source_id,$seq,$description,$seq_version,$secondary_id);

  my $est = $self->createNewEST($source_id,$possiblyReversed,$putativeFullLength,$poorQuality,$seqLength,$qualityStart);

  $nas->addChild($est);

  $nas->submit();

  $nas->undefPointerCache();

  $self->{totalCount}++;

  my $total = $self->{totalCount} + $self->{skippedCount};

  $self->log("processed sourceId: $source_id  and total processed: $total");
}

sub createNewExternalSequence {
  my($self, $source_id,$seq,$description,$seq_version,$secondary_id) = @_;

  my $aas = GUS::Model::DoTS::ExternalNASequence->
    new({'external_database_release_id' => $self->{external_database_release_id},
	 'source_id' => $source_id,
	 'taxon_id' => $self->{taxonId},
	 'sequence_version' => $seq_version,
	 'sequence_ontology_id' => $self->{sequenceOntologyId} });

  if ($secondary_id && $aas->isValidAttribute('secondary_identifier')) {
    $aas->setSecondaryIdentifier($secondary_id);
  }

  if ($description) { 
    $description =~ s/\"//g; $description =~ s/\'//g;
    $aas->set('description',substr($description,0,255));
  }

  $aas->setSequence($seq);

  $self->getMonomerCount($aas,$seq);

  return $aas;
}

sub createNewEST {
  my ($self,$source_id,$possiblyReversed,$putativeFullLength,$poorQuality,$seqLength,$qualityStart) = @_;

  my $est = GUS::Model::DoTS::EST->new({'library_id' => $self->{libraryId},
					'contact_id' => $self->{contactId},
					'accession' => $source_id,
					'possibly_reversed' => $possiblyReversed,
					'putative_full_length_read' => $putativeFullLength,
					'trace_poor_quality' => $poorQuality,
					'quality_start' => $qualityStart,
					'seq_length' => $seqLength
				       });

  return $est;
}

sub getMonomerCount{
  my ($self, $aas, $seq)=@_;
  my $monomersHash;
  my $countA = 0;
  my $countT = 0;
  my $countC = 0;
  my $countG = 0;
  my $countOther = 0;

  $seq =~ s/-//g;

  my $seqobj = Bio::PrimarySeq->new(-seq=>$seq,
				    -alphabet=>'dna');

  my $seqStats  =  Bio::Tools::SeqStats->new(-seq=>$seqobj);

  $monomersHash = $seqStats->count_monomers();
  foreach my $base (keys %$monomersHash) {
    if ($base eq 'A'){
      $countA = $$monomersHash{$base};
    }
    elsif ($base eq 'T'){
      $countT = $$monomersHash{$base};
    }
    elsif ($base eq 'C'){
      $countC = $$monomersHash{$base};
    }
    elsif ($base eq 'G'){
      $countG = $$monomersHash{$base};
    }
    else{
      $countOther = $$monomersHash{$base};
    }
  }

  $aas->setACount($countA);
  $aas->setTCount($countT);
  $aas->setCCount($countC);
  $aas->setGCount($countG);
  $aas->setOtherCount($countOther);

  return;
}

sub fetchSequenceOntologyId {
  my ($self) = @_;

  my $name = $self->getArg('SOTermName');

  my $SOTerm = GUS::Model::SRes::SequenceOntology->new({'term_name' => $name });

  $SOTerm->retrieveFromDB;

  $self->{sequenceOntologyId} = $SOTerm->getId();

  print STDERR ("SO ID:   ********** $self->{sequenceOntologyId} \n");

  $self->{sequenceOntologyId}
    || $self->userError("Can't find SO term '$name' in database");

}

sub fetchTaxonId {
  my ($self) = @_;

  my $ncbiTaxId = $self->getArg('ncbiTaxId');

  my $taxon = GUS::Model::SRes::Taxon->new({ncbi_tax_id=>$ncbiTaxId});

  $taxon->retrieveFromDB 
    || $self->userError ("The NCBI tax ID '$ncbiTaxId' provided on the command line is not found in the database");

  $self->{taxonId} = $taxon->getTaxonId();
}

sub undoTables {
  qw(
    DoTS.EST
    DoTS.ExternalNASequence
    DoTS.Library
    SRes.Contact
    );
}


1;
