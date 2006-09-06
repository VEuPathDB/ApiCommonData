package ApiCommonData::Load::Plugin::InsertSnps;
@ISA = qw(GUS::PluginMgr::Plugin);

use strict;

use GUS::PluginMgr::Plugin;
use GUS::Model::SRes::SequenceOntology;
use GUS::Model::DoTS::SeqVariation;
use GUS::Model::DoTS::NALocation;
use GUS::Model::DoTS::SnpFeature;


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
   enumArg({name => 'seqVarType',
	    descr => 'The type of sequence variation to be loaded.',
	    constraintFunc => undef,
	    reqd => 1,
	    isList => 0,
	    enum => "SNP, GeneticMarker",
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

    my $seqVarRows = $self->getSeqVars(\@line);

    foreach my $seqVar (@$seqVarRows) {

      my $naSeq = $self->getNaSeq(\@line);

      $seqVar->setParent($naSeq);

      my $naLoc = $self->getNaLoc(\@line);

      $seqVar->addChild($naLoc);

    }

    $seqVarRows->[0]->submit();

    $self->undefPointerCache();

    $lineNum++;

    if ($lineNum%10 == 0){
      $self->log("processed $lineNum lines from $file.\n");
    }
  }

  return $lineNum;

}

sub getSeqVars {
  my ($self,$line) = @_;

  my $extDbRlsId = $self->{'snpExtDbRlsId'};

  my $soId = $self->{'soId'};

  my @data = split (/;/, $line->[8]);

  my $sourceId = $data[0];

  my $organism = $self->getArg('organism');

  my $start = $line->[3];

  my $end = $line->[4];

  my $ref = $self->getArg('reference');

  my $standard = ($end == $start + 1) ? 'insertion' : 'substitution';

  my @featureRows;

  my $varType = $self->getArg('seqVarType');
  if ($varType eq 'SNP'){

    my $snpFeature = GUS::Model::DoTS::SnpFeature->
      new({NA_SEQUENCE_ID => '',	
           NAME => $varType,
           SEQUENCE_ONTOLOGY_ID => $soId,
           PARENT_ID => '',	
           EXTERNAL_DATABASE_RELEASE_ID => $extDbRlsId,
           SOURCE_ID => $sourceId,
           REFERENCE_STRAIN => $ref,
           ORGANISM => $organism,
           IS_CODING => '',
           POSITION_IN_CDS => '',
           });

    $snpFeature->retrieveFromDB();
    push (@featureRows, $seqvar);

    while ($data[1] =~ m/(\w+):([\w\-]+)/g) {
      my $strain = $1;
      my $base = $2;

      if(lc($ref) eq lc($strain)) {
        $snpFeature->setReferenceCharacter($base);
      }
      else {
        $standard = 'deletion' if ($standard eq 'substitution' && $base =~ /-/);

        my $seqvar =  GUS::Model::DoTS::SeqVariation->
          new({'source_id' => $sourceId,
               'external_database_release_id' => $extDbRlsId,
               'name' => 'SNP',
               'standard_name' => $standard,
               'sequence_ontology_id' => $soId,
               'strain' => $strain,
               'allele' => $base,
               'organism' => $organism
              });

        $seqvar->retrieveFromDB();
        $seqvar->setParent($snpFeature);

        push (@featureRows, $seqvar);
      }
    }
  }

  if($varType eq 'GeneticMarker') {
    my $seqvar =  GUS::Model::DoTS::SeqVariation->
      new({'source_id' => $sourceId,
           'external_database_release_id' => $extDbRlsId,
           'name' => 'GeneticMarker',
           'sequence_ontology_id' => $soId,
           'organism' => $organism
          });

    $seqvar->retrieveFromDB();

    push (@featureRows, $seqvar);

  }

  return \@featureRows;

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
    $locType = $end == $start + 1 ? 'insertion_site' : 'modified_base_site';
  }
  else{
    $locType = 'genetic_marker_site';
  }
  my $naLoc = GUS::Model::DoTS::NALocation->new({'start_min'=>$start,'start_max'=>$start,'end_min'=>$end,'end_max'=>$end,'location_type'=>$locType});

  return $naLoc;

}

sub undoTables {
  my ($self) = @_;

  return ('DoTS.NALocation',
	  'DoTS.SeqVariation',
	 );
}

1;
