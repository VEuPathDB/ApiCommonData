package ApiCommonData::Load::Plugin::LoadFastaSequences;

@ISA = qw(GUS::PluginMgr::Plugin);
use strict;
use GUS::PluginMgr::Plugin;
use File::Basename;


  my $purposeBrief = 'Insert or update sequences from a FASTA file or as set of FASTA files.';

  my $purpose = <<PLUGIN_PURPOSE;
Insert or update sequences from a FASTA file or as set of FASTA files.  A set of regular expressions provided on the command line extract from the definition lines of the input sequences various information to stuff into the database.
PLUGIN_PURPOSE

  my $tablesAffected =
  [
    ];

  my $tablesDependedOn =
    [
    ];

  my $howToRestart = <<PLUGIN_RESTART;
PLUGIN_RESTART

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
 integerArg({  name           => 'testnumber',
	       descr          => 'For testing: stop after this number of iterations',
	       reqd           => 0,
	       constraintFunc => undef,
	       isList         => 0 }),

 fileArg({   name           => 'writeFile',
	       descr          => 'The name of a file to write the newly created sequences to (they have different deflines than the input)',
	       reqd           => 0,
	       constraintFunc => undef,
               mustExist => 0,
               format =>"",
               isList         => 0 }),

  stringArg({   name           => 'externalDatabaseName',
	       descr          => 'The name of the ExternalDatabase from which the input sequences have come',
	       reqd           => 1,
	       constraintFunc => undef,
	       isList         => 0 }),

stringArg({   name           => 'externalDatabaseVersion',
	       descr          => 'The version of the ExternalDatabaseRelease from whith the input sequences have come',
	       reqd           => 1,
	       constraintFunc => undef,
	       isList         => 0 }),

 integerArg({   name           => 'logFrequency',
	       descr          => 'The frequency of logging progress, ie, after how many sequences are processed',
	       reqd           => 0,
		default       => 10,
	       constraintFunc => undef,
	       isList         => 0 }),

  stringArg({   name           => 'sequenceTypeName',
	       descr          => 'The name from the SequenceType table for these sequences, e.g. tRNA',
	       reqd           => 0,
	       constraintFunc => undef,
	       isList         => 0 }),

 stringArg({   name           => 'nucleotideType',
	       descr          => 'The nucleotide type from the SequenceType table for these sequences, e.g. RNA',
	       reqd           => 0,
	       constraintFunc => undef,
	       isList         => 0 }),

  stringArg({  name           => 'SOTermName',
	       descr          => 'The Sequence Ontology term for the sequence type',
	       reqd           => 0,
	       constraintFunc => undef,
	       isList         => 0 }),

 integerArg({   name           => 'ncbiTaxId',
	       descr          => 'The taxon id from NCBI for these sequences.  Not applicable for AASequences. Do not use this flag if using the regexTaxonName flag.',
	       reqd           => 0,
	       constraintFunc => undef,
	       isList         => 0 }),

 fileArg({   name           => 'sequenceFile',
	       descr          => 'The name of the FASTA file containing the input sequences',
	       reqd           => 0,
               mustExist => 0,
               format =>"FASTA",
	       constraintFunc => undef,
	       isList         => 0 }),

  fileArg({   name           => 'seqFileDir',
	       descr          => 'If set, treat all files in this directory as FASTA files and load them all',
	       reqd           => 0,
               mustExist => 0,
               format =>"Directory of FASTA files",
	       constraintFunc => undef,
	       isList         => 0 }),

  fileArg({   name           => 'sourceIdsFile',
	       descr          => 'A file containing a source IDs that should be loaded from the FASTA file',
	       reqd           => 0,
               mustExist => 1,
               format =>"A newline delimited list of source IDs ",
	       constraintFunc => undef,
	       isList         => 0 }),

 booleanArg({   name           => 'noSequence',
	       descr          => 'If true, do not write the actual sequence to the database.',
	       reqd           => 0,
	       constraintFunc => undef,
	       isList         => 0 }),

 stringArg({   name           => 'regexSourceId',
	       descr          => 'The regular expression to pick the source_id of the sequence from the defline',
	       reqd           => 1,
	       constraintFunc => undef,
	       isList         => 0 }),

 stringArg({   name           => 'regexSecondaryId',
	       descr          => 'The regular expression to pick the secondary id of the sequence from the defline',
	       reqd           => 0,
	       constraintFunc => undef,
	       isList         => 0 }),

 stringArg({   name           => 'regexTaxonName',
	       descr          => 'The regular expression to pick the taxon name from the defline. Do not use this flag if using the ncbiTaxId flag.',
	       reqd           => 0,
	       constraintFunc => undef,
	       isList         => 0 }),

 stringArg({   name           => 'regexNcbiTaxId',
	       descr          => 'The regular expression to pick the Ncbi taxon id from the defline. Do not use this flag if using the ncbiTaxId flag.',
	       reqd           => 0,
	       constraintFunc => undef,
	       isList         => 0 }),

 stringArg({   name           => 'regexName',
	       descr          => 'The regular expression to pick the name of the sequence from the defline',
	       reqd           => 0,
	       constraintFunc => undef,
	       isList         => 0 }),

 stringArg({   name           => 'regexDesc',
	       descr          => 'The regular expression to pick the description of the sequence from the defline',
	       reqd           => 0,
	       constraintFunc => undef,
	       isList         => 0 }),

 stringArg({   name           => 'regexChromosome',
	       descr          => 'The regular expression to pick the chromosome from the defline',
	       reqd           => 0,
	       constraintFunc => undef,
	       isList         => 0 }),

 stringArg({   name           => 'regexMolWgt',
	       descr          => 'Theregular expression to pick the molecular weight of the sequence from the defline',
	       reqd           => 0,
	       constraintFunc => undef,
	       isList         => 0 }),

 stringArg({   name           => 'regexContainedSeqs',
	       descr          => 'The regular expression to pick the number of contained sequences from the defline',
	       reqd           => 0,
	       constraintFunc => undef,
	       isList         => 0 }),

 stringArg({   name           => 'regexSeqVersion',
	       descr          => 'The regular expression to pick the sequence version e.g. >\S+\.(\d+) for >NM_47654.1',
	       reqd           => 0,
	       constraintFunc => undef,
	       isList         => 0 }),

 tableNameArg({   name           => 'tableName',
	       descr          => 'Table name to insert sequences into, in schema::table format.  Chose from: DoTS::ExternalNASequence DoTS::VirtualSequence DoTS::ExternalAASequence DoTS::MotifAASequence',
	       reqd           => 1,
	       constraintFunc => undef,
	       isList         => 0 }),

 booleanArg({   name           => 'update',
	       descr          => 'If true, checks to see if row is updated',
	       reqd           => 0,
	       constraintFunc => undef,
	       isList         => 0 }),

  booleanArg({   name           => 'updateLongest',
	       descr          => 'If true, checks to see if sequence is longer than that currently loaded, if so, updates the entry.',
	       reqd           => 0,
	       constraintFunc => undef,
	       isList         => 0 }),

  booleanArg({   name           => 'noCheck',
	       descr          => 'If true, does NOT check to see if external_database_release_id,source_id is already in db...',
	       reqd           => 0,
	       constraintFunc => undef,
	       isList         => 0 }),
 integerArg({   name           => 'startAt',
	       descr          => 'Ignores entries in the FASTA file prior to this number',
	       reqd           => 0,
	       constraintFunc => undef,
	       isList         => 0 }),

  stringArg({   name           => 'project',
	       descr          => 'name of the project to link these sequences to, if any',
	       reqd           => 0,
	       constraintFunc => undef,
	       isList         => 0 }),

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

my $checkStmt;
my $prim_key;
$| = 1;

sub run {
  my $self  = shift;

  die "Do not use both 'ncbiTaxId' and 'regexTaxonName'. Use one or the other, use the --help flag for more information." if ($self->getArg('ncbiTaxId') && $self->getArg('regexTaxonName'));

  die "Do not use both 'ncbiTaxId' and 'regexNcbiTaxId'. Use one or the other, use the --help flag for more information." if ($self->getArg('ncbiTaxId') && $self->getArg('regexNcbiTaxId'));

  $self->{totalCount} = 0;
  $self->{skippedCount} = 0;

  $self->{external_database_release_id} =
    $self->getExtDbRlsId($self->getArg('externalDatabaseName'),
			 $self->getArg('externalDatabaseVersion'));

  $self->log("loading sequences with external database release id $self->{external_database_release_id}");

  $self->log("Testing on " . $self->getArg('testnumber')) if $self->getArg('testnumber');

  eval("require GUS::Model::".$self->getArg('tableName'));


  # get primary key for table_name
  my $tableId = $self->className2TableId($self->getArg('tableName'));

  $prim_key = $self->getAlgInvocation()->getTablePKFromTableId($tableId);

  if ($self->getArg('writeFile')) {
    open(WF,">>" . $self->getArg('writeFile'));
  }

  if ($self->getArg('tableName') eq 'DoTS::VirtualSequence') {
    $self->fetchSequenceTypeId("virtual");
  }
  elsif ($self->getArg('sequenceTypeName') && $self->getArg('nucleotideType')) {
    $self->fetchSequenceTypeId();
  }

  if ($self->getArg('SOTermName')) {
    $self->fetchSequenceOntologyId();
  }

  if ($self->getArg('ncbiTaxId')) {
    $self->fetchTaxonId();
  }

  if ($self->getArg('sourceIdsFile')) {
    $self->getGoodSourceIds();
  }

  my $oracleName = $self->className2oracleName($self->getArg('tableName'));
  $checkStmt = $self->getAlgInvocation()->getQueryHandle()->prepare("select $prim_key from $oracleName where source_id = ? and external_database_release_id = $self->{external_database_release_id}");

  my $seqFileDir = $self->getArg('seqFileDir');
  if ($seqFileDir){
    my $nextSeqFile;
    opendir (DIR, $seqFileDir) or die "can't open directory $seqFileDir";
    while ($nextSeqFile = readdir DIR){
      next if $nextSeqFile =~/^\./;
      my $fullSeqFile = $seqFileDir . "/" . $nextSeqFile;
      $self->{fileCount}++;
      $self->processOneFile($fullSeqFile, $oracleName, $checkStmt, $prim_key);
    }
  }
  else {

      ##open sequence file
      my $seqFile = $self->getArg('sequenceFile');
      $self->{fileCount}++;
      $self->processOneFile($seqFile, $oracleName, $checkStmt, $prim_key);
  }

  my $res = "Run finished: " . $self->getProgress();
  return $res;


}

sub processOneFile{
    my ($self, $seqFile, $oracleName, $checkStmt, $prim_key) = @_;

    $self->logVerbose("loading sequences from $seqFile\n");
    if ($seqFile =~ /gz$/) {
	open(F, "gunzip -c $seqFile |") || die "Can't open $seqFile for reading";
    } else {
	open(F,"$seqFile") || die "Can't open $seqFile for reading";
    }

    my $source_id;
    my $name;
    my $description;
    my $secondary_id;
    my $chromosome;
    my $mol_wgt;
    my $contained_seqs;
    my $seq;
    my $seq_version = 1;
    my $start = 1;
    my $taxonName;
    my $NcbiTaxonId;

    while (<F>) {
	if (/^\>/) {                ##have a defline....need to process!

	  s/\s+$//;  # trim trailing white space (including DOS newlines!)

	    ##following must be in loop to allow garbage collection...
	    $self->undefPointerCache();

	    last if($self->getArg('testnumber') && $self->{totalCount} == $self->getArg('testnumber') - 1);

	    if ($self->getArg('startAt')
		&& $self->{skippedCount} < $self->getArg('startAt')) {
	      $self->{skippedCount}++;
	      next;
	    }

	    if ($source_id) {
	      $self->process($source_id,$secondary_id,$name,
			       $description,$mol_wgt,$contained_seqs,
			       $chromosome,$seq,$seq_version);
      	    }

	    $self->log($self->getProgress())
	      if ($self->{totalCount} + $self->{skippedCount})
		% $self->getArg('logFrequency') == 0;

	    ##now get the ids etc for this defline...

	    my $regexSource = $self->getArg('regexSourceId');

	    if (/$regexSource/ && $1) {
		$source_id = $1;
	    } else {
	      my $forgotParens = ($regexSource !~ /\(/)? "(Forgot parens?)" : "";
	      $self->userError("Unable to parse source_id from $_ using regex '$regexSource' $forgotParens");
	    }

	    $secondary_id = ""; $name = ""; $description = ""; $mol_wgt = ""; $contained_seqs= ""; $chromosome=""; $seq_version = 1;##in case can't parse out of this defline...

	    my $regexSecondaryId = $self->getArg('regexSecondaryId') if $self->getArg('regexSecondaryId');
	    if ($regexSecondaryId && /$regexSecondaryId/) {
	      $secondary_id = $1;
	    }

	    my $regex_name = $self->getArg('regexName') if $self->getArg('regexName');
	    if ($regex_name && /$regex_name/) {
	      $name = $1;
	    }

	    my $regex_taxon_name = $self->getArg('regexTaxonName') if $self->getArg('regexTaxonName');
	    if ($regex_taxon_name && /$regex_taxon_name/) {
	      $taxonName = $1;
	      $self->fetchTaxonIdFromName($taxonName);
	    }

	    my $regex_ncbi_taxId = $self ->getArg('regexNcbiTaxId') if $self ->getArg('regexNcbiTaxId');
            
            if ($regex_ncbi_taxId && /$regex_ncbi_taxId/) {
	      $NcbiTaxonId = $1;
	      $self->fetchTaxonId($NcbiTaxonId);
	    }
	    my $regexChromosome = $self->getArg('regexChromosome') if $self->getArg('regexChromosome');
	    if ($regexChromosome && /$regexChromosome/) {
	      $chromosome = $1;
	    }

	    my $regexDescrip = $self->getArg('regexDesc') if $self->getArg('regexDesc');
	    if ($regexDescrip && /$regexDescrip/) {
	      $description = $1;
	    }

	    my $regexMolWgt = $self->getArg('regexMolWgt') if $self->getArg('regexMolWgt');
	    if ($regexMolWgt && /$regexMolWgt/) {
	      $mol_wgt = $1;
	    }

	    my $regexContainedSeqs = $self->getArg('regexContainedSeqs') if $self->getArg('regexContainedSeqs');
	    if ($regexContainedSeqs && /$regexContainedSeqs/) {
		$contained_seqs = $1;
	    }

	    my $regexSeqVersion = $self->getArg('regexSeqVersion') if $self->getArg('regexSeqVersion');
	    if ($regexSeqVersion && /$regexSeqVersion/) {
		$seq_version = $1;
	    }

	    ##reset the sequence..
	    $seq = "";
	} else {
	    $seq .= $_;
	}

    }

    $self->process($source_id,$secondary_id,$name,$description,$mol_wgt,$contained_seqs,$chromosome,$seq,$seq_version) if ($source_id);
}

##SUBS

sub process {
  my($self, $source_id,$secondary_id,$name,$description,$mol_wgt,$contained_seqs,$chromosome,$sequence,$seq_version) = @_;

  if ($self->{goodSourceIds} && !$self->{goodSourceIds}->{$source_id}) {
    $self->{skippedCount}++;
    return;
  }

  $self->{totalCount}++;

  my $id;
  $id = $self->checkIfHave($source_id) unless $self->getArg('noCheck');
  my $aas;
  if ($id && $self->getArg('update')) {
    my $className = "GUS::Model::" . $self->getArg('tableName');
    $aas = $className->new({$prim_key => $id});
    $aas->retrieveFromDB();
    $aas->setSecondaryIdentifier($secondary_id) unless !$secondary_id || $aas->getSecondaryIdentifier() eq $secondary_id;
    $aas->setDescription($description) unless !$description || $aas->getDescription() eq $description;
    $aas->setName($name) unless !$name || $aas->getName() eq $name;
    $aas->setChromosome($chromosome) unless !$chromosome || $aas->getChromosome() eq $chromosome;
    $aas->setMolecularWeight($mol_wgt) unless ((!$aas->isValidAttribute('molecular_weight')) || (!$mol_wgt || $aas->getMolecularWeight() eq $mol_wgt));  
    $aas->setNumberOfContainedSequences($contained_seqs) unless ((!$aas->isValidAttribute('number_of_contained_sequences')) || (!$contained_seqs || $aas->getNumberOfContainedSequences() eq $contained_seqs)); 
    #$aas->setSequenceVersion($seq_version) unless (!$aas->isValidAttribute('sequence_version') || ($aas->getSequenceVersion() = $seq_version));
    $aas->setSequence($sequence) if $sequence;
  } else {
    return if $id;		##already have and am not updating..
    $aas = $self->createNewExternalSequence($source_id,$secondary_id,$name,$description,$chromosome,$mol_wgt,$contained_seqs,$sequence,$seq_version);
  }

  $aas->submit() if $aas->hasChangedAttributes();
  $self->makeProjLink($aas) if $self->getArg('project');
  if ($self->getArg('writeFile')) {
    print WF ">",$aas->getId()," $source_id $secondary_id $name $description\n$sequence\n";
  }
}

sub getProgress {
  my ($self) = @_;

  my $skipped = $self->{skippedCount}? " Skipped $self->{skippedCount}" : "";

  return "Processed $self->{fileCount} file(s). Processed $self->{totalCount} sequence(s)$skipped.  Inserted " . $self->getTotalInserts() . " and Updated ".$self->getTotalUpdates();
}

sub createNewExternalSequence {
  my($self, $source_id,$secondary_id,$name,$description,$chromosome,$mol_wgt,$contained_seqs,$sequence,$seq_version,) = @_;

  my $className = "GUS::Model::" . $self->getArg('tableName');
  $className =~ /GUS::Model::\w+::(\w+)/ || die "can't parse className";
  my $tbl = $1;

  my $aas = $className->
    new({'external_database_release_id' => $self->{external_database_release_id},
	 'source_id' => $source_id,
	 'subclass_view' => $tbl });

  if ($secondary_id && $aas->isValidAttribute('secondary_identifier')) {
    $aas->set('secondary_identifier',$secondary_id);
  }

  if ($name && $aas->isValidAttribute('name')) {
    $aas->set('name',$name);
  }

  if ($self->{sequenceTypeId} && $aas->isValidAttribute('sequence_type_id')) {
    $aas->setSequenceTypeId($self->{sequenceTypeId});
  }

  if ($self->{sequenceOntologyId} && $aas->isValidAttribute('sequence_ontology_id')) {
    $aas->setSequenceOntologyId($self->{sequenceOntologyId});
  }

  if ($seq_version && $aas->isValidAttribute('sequence_version')) {
    $aas->setSequenceVersion($seq_version);
  }

  #if($self->getArg('taxon_id')){ $aas->setTaxonId($self->getArg('taxon_id'));}
  if ($self->{taxonId}) { 
    if ($aas->isValidAttribute('taxon_id')) {
      $aas->setTaxonId($self->{taxonId});
    } elsif ($self->getArg('tableName') eq 'DoTS::ExternalAASequence') {
      eval ("require GUS::Model::DoTS::AASequenceTaxon");
      my $aast =  GUS::Model::DoTS::AASequenceTaxon->
	new({taxon_id => $self->{taxonId}});
      $aas->addChild($aast);
    } else {
      die "Cannot set taxon_id for table_name " . $self->getArg('tableName') . "\n";
    }
  }
  if ($description) { 
    $description =~ s/\"//g; $description =~ s/\'//g;
    $aas->set('description',substr($description,0,255));
  }
  if ($name && $aas->isValidAttribute('name') ) {
    $name =~ s/\"//g; $name =~ s/\'//g;
    $aas->set('name',$name);
  }
  if ($chromosome && $aas->isValidAttribute('chromosome') ) {
    $aas->setChromosome($chromosome);
  }
  if ($mol_wgt && $aas->isValidAttribute('molecular_weight')) {
    $aas->setMolecularWeight($mol_wgt);
  }
  if ($contained_seqs && $aas->isValidAttribute('number_of_contained_sequences')) {
    $aas->setNumberOfContainedSequences($contained_seqs);
  }
  if ($sequence && !$self->getArg('noSequence')) {
    $aas->setSequence($sequence);
  }
  $self->logDebug($aas->toString());
  return $aas;
}


sub checkIfHave {
  my($self, $source_id) = @_;
  $checkStmt->execute($source_id);
  if (my($id) = $checkStmt->fetchrow_array()) {
    #die "Entry already inserted for '$source_id'\n" unless $self->getArg('update');
    $checkStmt->finish();
    return $id;
  }
  return 0;
}

sub getGoodSourceIds {
  my ($self) = @_;

  open(SRC_IDS_FILE, $self->getArg('sourceIdsFile'));
  while (<SRC_IDS_FILE>) {
    s/\s+//;
    $self->{goodSourceIds}->{$_} = 1;
  }
}

sub makeProjLink {
  my ($self, $T) = @_;  # table object;
  my %plink;

  # table
  $plink{table_id} = $T->getTableIdFromTableName($T->getClassName);
  $plink{id}       = $T->getId();

  eval ("require GUS::Model::DoTS::ProjectLink");
  my $projlink_gus = GUS::Model::DoTS::ProjectLink->new(\%plink);

  if ($projlink_gus->retrieveFromDB) {
    # case when projectLink is in dB
    die "ProjectLink already in DB with ID " . $projlink_gus->getId . "\n";
    return undef;
  } else {
    $projlink_gus->setProjectId($self->getProjId());

    $projlink_gus->submit();
    return 1;
  }
}

sub setProjId {
  my ($self) = @_;
  my %project = ( name => $self->getArg('project') );

  eval ("require GUS::Model::Core::ProjectInfo");
  my $project_gus = GUS::Model::Core::ProjectInfo->new(\%project);
  if ($project_gus->retrieveFromDB) {
    my $projId = $project_gus->getId;
    return $projId;
  } else {
    die "ERROR in returning ProjectID\n";
    return undef;
  }
}

sub getProjId {
  my ($self) = @_;

  return ($self->setProjId());
}

sub fetchSequenceTypeId {
  my ($self, $name) = @_;

  eval ("require GUS::Model::DoTS::SequenceType");

  my $seqTypeName = $self->getArg('sequenceTypeName');
  my $nuclType = $self->getArg('nucleotideType');

  if ($name) {
    $seqTypeName = $name;
    $nuclType = $name;
  }

  my $sequenceType =
    GUS::Model::DoTS::SequenceType->new({ name => $seqTypeName,
					  nucleotide_type => $nuclType
					});

  $sequenceType->retrieveFromDB;

  my $hierarchy = 1;
  $sequenceType->setHierarchy($hierarchy) unless $sequenceType->getHierarchy();

  $sequenceType->submit();

  $self->{sequenceTypeId} = $sequenceType->getSequenceTypeId();

}

sub fetchSequenceOntologyId {
  my ($self, $name) = @_;

  my $name = $self->getArg('SOTermName');

  eval ("require GUS::Model::SRes::SequenceOntology");

  my $SOTerm = GUS::Model::SRes::SequenceOntology->new({ term_name => $name });

  $SOTerm->retrieveFromDB;

  $self->{sequenceOntologyId} = $SOTerm->getSequenceOntologyId();

  $self->{sequenceOntologyId}
    || $self->userError("Can't find SO term '$name' in database");
}

sub fetchTaxonId {
  my ($self, $ncbiTaxId) = @_;

  eval ("require GUS::Model::SRes::Taxon");

  $ncbiTaxId = $self->getArg('ncbiTaxId') if $self->getArg('ncbiTaxId');

  my $taxon = GUS::Model::SRes::Taxon->new({ncbi_tax_id=>$ncbiTaxId});

  if ($taxon->retrieveFromDB){

      $self->{taxonId} = $taxon->getTaxonId();
  }else{

      $self->fetchTaxonIdFromName('unknown');
  }
}


sub fetchTaxonIdFromName {
  my ($self, $taxonName) = @_;

  eval ("require GUS::Model::SRes::TaxonName");

  my $taxon = GUS::Model::SRes::TaxonName->new({name=>$taxonName});

  $taxon->retrieveFromDB || die "The taxon name '$taxonName' provided in the file is not found in the database\n";

  $self->{taxonId} = $taxon->getTaxonId();
}



sub undoTables {
  my ($self) = @_;

  return ('DoTS.AASequenceImp',
	  'DoTS.NASequenceImp',
	 );
}



1;
