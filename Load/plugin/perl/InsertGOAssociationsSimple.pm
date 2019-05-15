package ApiCommonData::Load::Plugin::InsertGOAssociationsSimple;
#vvvvvvvvvvvvvvvvvvvvvvvvv GUS4_STATUS vvvvvvvvvvvvvvvvvvvvvvvvv
  # GUS4_STATUS | SRes.OntologyTerm              | auto   | absent
  # GUS4_STATUS | SRes.SequenceOntology          | auto   | absent
  # GUS4_STATUS | Study.OntologyEntry            | auto   | absent
  # GUS4_STATUS | SRes.GOTerm                    | auto   | fixed
  # GUS4_STATUS | Dots.RNAFeatureExon            | auto   | absent
  # GUS4_STATUS | RAD.SageTag                    | auto   | absent
  # GUS4_STATUS | RAD.Analysis                   | auto   | absent
  # GUS4_STATUS | ApiDB.Profile                  | auto   | absent
  # GUS4_STATUS | Study.Study                    | auto   | absent
  # GUS4_STATUS | Dots.Isolate                   | auto   | absent
  # GUS4_STATUS | DeprecatedTables               | auto   | absent
  # GUS4_STATUS | Pathway                        | auto   | absent
  # GUS4_STATUS | DoTS.SequenceVariation         | auto   | absent
  # GUS4_STATUS | RNASeq Junctions               | auto   | absent
  # GUS4_STATUS | Simple Rename                  | auto   | absent
  # GUS4_STATUS | ApiDB Tuning Gene              | auto   | absent
  # GUS4_STATUS | Rethink                        | auto   | absent
  # GUS4_STATUS | dots.gene                      | manual | fixed
#^^^^^^^^^^^^^^^^^^^^^^^^^ End GUS4_STATUS ^^^^^^^^^^^^^^^^^^^^

@ISA = qw( GUS::PluginMgr::Plugin);

use CBIL::Bio::GeneAssocParser::Parser;
use GUS::PluginMgr::Plugin;
use GUS::Model::DoTS::GOAssociationInstance;
use GUS::Model::DoTS::GOAssociationInstanceLOE;
use GUS::Model::DoTS::GOAssociation;
use GUS::Model::DoTS::GOAssocInstEvidCode;
use GUS::Supported::Util;

use GUS::Supported::Utility::GOAnnotater;

use FileHandle;
use Carp;
use lib "$ENV{GUS_HOME}/lib/perl";
use strict;
use Data::Dumper;
my $purposeBrief = <<PURPOSEBRIEF;
Insert GO associations from a standard GO Associations file.
PURPOSEBRIEF

my $purpose = <<PLUGIN_PURPOSE;
Insert GO associations from a standard GO Associations file using a simple approach.  The approach only records the immediate associations, not the implied transitive closure (the parents).  (Applications that need the the transitive closure for querying speed are assumed to rely on storing the closure for the entire GO graph in GORelationship).  For each association in the input file, the plugin adds a GOAssociationInstance.  If the sequence has no prior GOAssociation for the GOTerm, one is created.
PLUGIN_PURPOSE

    
my $tablesAffected = 
	[['DoTS.GOAssociation', 'Writes the pertinent information of sequence/GO Term mapping here'],
	 ['DoTS.GOAssociationInstance', 'Writes information supporting the Association here'],
	 ['DoTS.GOAssocInstEvidCode', 'Writes an entry here linking the Instance with a GO Evidence Code supporting the instance, as provided in the input file']];
    
my $tablesDependedOn = 
	[['SRes.OntologyTerm', 'Retrieves information about a GOTerm and GO Evidence Codes from this table'],
	 ['SRes.OntologyRelationship', 'Retrieves information about GO Hierarchy relationships among GO Terms from this table'],
	 ['SRes.ExternalDatabaseRelease', 'Information about the latest release of the Gene Ontology and the organism to be loaded must be provided here'],
	 ['DoTS.ExternalAASequence', 'Sequences with which to make Associations must be provided here'],
	 ['Core.TableInfo', 'An entry for DoTS.ExternalAASequence must be provided here']];

my $howToRestart = <<PLUGIN_RESTART;
Use the Undo plugin, and re-run.
PLUGIN_RESTART

my $failureCases = <<PLUGIN_FAILURE_CASES;
None that we have found so far.
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

         stringArg({name => 'externalDatabaseSpec',
	    descr => 'External database release to tag the new data with (in "name|version" format)',
	    constraintFunc => undef,
	    reqd => 1,
	    isList => 0
	    }),
 
	 fileArg ({name => 'inputFile',
		   descr => 'The associations in gene_ontology.organism format',
		   constraintFunc => undef,
		   reqd => 1,
		   isList => 0,
		   mustExist => 1,
		   format => 'see ftp://ftp.geneontology.org/pub/go/gene-associations'
	          }),

	 fileArg ({name => 'skipBadGOTerms',
		   descr => 'whether to skip unfound/bad GO Terms; provided filename used to store list of bad terms.',
		   constraintFunc => undef,
		   reqd => 0,
		   isList => 0,
		   mustExist => 0,
		   format => '',
	          }),

         stringArg({name => 'goExtDbRlsName',
	    descr => 'Targeted GO Term database name',
	    constraintFunc => undef,
	    reqd => 1,
	    isList => 0
	    }),

         stringArg({name => 'goEvidenceCodeExtDbRlsName',
	    descr => 'Targeted GO evidence code database name',
	    constraintFunc => undef,
	    reqd => 1,
	    isList => 0
	    }),
 
	 stringArg({name => 'seqIdSql',
	            descr => 'Sql to select (source_id, row_id) for the sequences to make the associations with, mapping the source_id found in the file to the sequence in the database.',
                    constraintFunc => undef,
	            reqd => 1,
                    isList => 0
                   }),

   tableNameArg({name  => 'targetTable',
                 descr => 'Table to make the associations to (used for table_id column in GOAssociation table).  Schema::table format, eg, DoTS::AaSequence)',
                 reqd  => 1,
                 constraintFunc=> undef,
                 isList=>0,
           }),

	 stringArg ({name  => 'lineOfEvidence',
	              descr => 'The name of the line of evidence for the associations created from the input file.  Eg, "Curators" or "InterproScan"',
                      constraintFunc => undef,
	              reqd  => 1,
                      isList => 0,
                     }), 

         enumArg({name => 'inputIdColumn',
		  descr => 'The column in the input file in which to find the sequence source_id (see the GO documentation for the meaning of these fields)',
		  constraintFunc => undef,
		  reqd => 1,
		  isList => 0,
		  enum => 'id, symbol, name'
		 }),

 	 booleanArg ({name => 'tolerateMissingSeqs',
	              descr => 'Set this to tolerate (and log) source ids in the input that do not find a sequence in the database.  If not set, will fail on that condition',
	              reqd => 0,
                      default =>0
                     }),
 
	 integerArg ({name  => 'logFrequency',
	              descr => 'Frequency of entries in the file with which to write a line out to the log',
                      constraintFunc => undef,
	              reqd  => 0,
                      isList => 0,
                      default => 1000
                     }), 

	 integerArg({name => 'testNumber',
	             descr => 'if only testing, process only this number of sequences',
                     constraintFunc => undef,
	             reqd => 0,
                     isList => 0,
                    }) 
    ];


sub new {
    my ($class) = @_;
    my $self = {};
    bless($self,$class);

    $self->initialize({requiredDbVersion => 4.0,
		       cvsRevision => '$Revision$', # cvs fills this in!
		       name => ref($self),
		       argsDeclaration => $argsDeclaration,
		       documentation => $documentation
		      });

    return $self;
}


#######################################################################
# Main Routine
#######################################################################

sub run {
    my ($self) = @_;

    my $fileName =$self->getArg('inputFile');
    my $logFrequency = $self->getArg('logFrequency');
    my $count = 0;
    $self->{skipCount} = 0;
    $self->{distinctSkipCount} = 0;
    $self->{newAssocCount} = 0;
    $self->{instanceCount} = 0;

    my $goExtDbRlsName = $self->getArg('goExtDbRlsName');

    my $goExtDbRlsVer = GUS::Supported::Util::getExtDbRlsVerFromExtDbRlsName($self, $goExtDbRlsName);

    my $goExternalDatabaseSpec=$goExtDbRlsName."|".$goExtDbRlsVer;

    my $goDbRlsId = 
      $self->getExtDbRlsId($goExternalDatabaseSpec);

    my $goEvidenceCodeExtDbRlsName = $self->getArg('goEvidenceCodeExtDbRlsName');

    my $goEvidenceCodeExtDbRlsVer = GUS::Supported::Util::getExtDbRlsVerFromExtDbRlsName($self, $goEvidenceCodeExtDbRlsName);

    my $goEvidenceCodeExternalDatabaseSpec = $goEvidenceCodeExtDbRlsName."|".$goEvidenceCodeExtDbRlsVer;

    my $goEvidenceCodeDbRlsId = 
      $self->getExtDbRlsId($goEvidenceCodeExternalDatabaseSpec);

    $self->{targetTableId}
      = $self->className2TableId($self->getArg('targetTable'));

    open(FILE, $fileName);
    while(<FILE>){
	chomp;
	next if (/^!/);
	last if ($self->getArg('testNumber') && ($count+1) > $self->getArg('testNumber'));

	$count++;
	my $inputAssoc = CBIL::Bio::GeneAssocParser::Assoc->new($_);

	my $sourceId = $self->getSourceId($inputAssoc);
#		 print "source id is $sourceId\n";

	my $dbreference = $self->getDBReference($inputAssoc);
	my $with = $self->getWith($inputAssoc);
	my $dataSource = $self->getDataSource($inputAssoc);
	my $rowId = $self->getTargetRowId($sourceId);

#	print "ref is $dbreference and evcodepara is $with\n\n";
	next if $self->targetNotFound($rowId, $sourceId, $inputAssoc);

	my $assocId = $self->findAssociationId($rowId,$inputAssoc,$goDbRlsId);

	$self->addAssociationInstance($assocId, $inputAssoc, $goEvidenceCodeDbRlsId, $dbreference, $with, $dataSource);

	$self->log("processing $sourceId; processed $count lines")
	    if ($logFrequency && ($count % $logFrequency == 0));
	$self->undefPointerCache();
      }

    my $totalAssocCount = scalar(keys(%{$self->{foundAssocs}}));
    my $msg = "Processed $count input associations.  Found $totalAssocCount distinct Associations, of which $self->{newAssocCount} were new (not in db already).  Created $self->{instanceCount} instances.  $self->{skipCount} associations were ignored ($self->{distinctSkipCount} distinct) because their sequence could not be found in the database";

    return $msg;
}

sub undoPreprocess {
  my ($self, $dbh, $rowAlgInvocationList) = @_;

  GUS::Supported::Utility::GOAnnotater::undoPreprocess($dbh, $rowAlgInvocationList);  
}

sub undoTables {
  my ($self) = @_;

  return ('DoTS.GOAssocInstEvidCode',
	  'DoTS.GOAssociationInstance',
	  'DoTS.GOAssociation',
	 );
}

sub getSourceId {
  my ($self, $inputAssoc) = @_;

  my $idCol = $self->getArg('inputIdColumn');
  return $inputAssoc->getDBObjectId() if $idCol eq 'id';
  return $inputAssoc->getDBObjectSymbol() if $idCol eq 'symbol';
  return $inputAssoc->getDBObjectName() if $idCol eq 'name';
}

sub getDBReference{
    my ($self, $inputAssoc) = @_;
    return $inputAssoc->getDBReference();
}

sub getWith{
    my ($self, $inputAssoc) = @_;
    return $inputAssoc->getWith();
}

sub getTargetRowId {
  my ($self, $sourceId) = @_;

  if (!$self->{seqIdMap}) {
    my $stmt = $self->prepareAndExecute($self->getArg('seqIdSql'));
    while (my @row = $stmt->fetchrow_array()) {
      $self->userError("--seqIdSql returns wrong number of columns") 
	if scalar(@row) != 2;

      my ($sourceId, $rowId) = @row;

      $self->userError("--seqIdSql could not find row_id for source_id '$sourceId'") if (!$rowId);

      $self->{seqIdMap}->{$sourceId} = $rowId;
    }
  }
  return $self->{seqIdMap}->{$sourceId};
}

sub targetNotFound {
  my ($self, $targetRowId, $sourceId, $inputAssoc) = @_;

  return 0 if $targetRowId;

  my $goId = $inputAssoc->getGOId();
  my $isNot = $inputAssoc->getIsNot() eq 'NOT'? 'y' : 'n';
  if ($self->getArg('tolerateMissingSeqs')) {
    $self->log("  skipping '$sourceId $goId' ($sourceId not found)");
    $self->{skipCount}++;
    $self->{distinctSkipCount}++ 
      unless $self->{distinctSkips}->{$sourceId}->{$goId}->{$isNot};
    $self->{distinctSkips}->{$sourceId}->{$goId}->{$isNot} = 1;
  } else {
    $self->userError("Can't find sequence for source id '$sourceId'");
  }
  return 1;
}


sub findAssociationId {
  my ($self, $rowId, $inputAssoc, $goDbRlsId) = @_;

  my $goId = $inputAssoc->getGOId();

  my $goTermId = $self->getGoTermId($goId, $goDbRlsId);

  return unless $goTermId;

  $self->getPriorAssociations() if (!$self->{assocIds});

  my $isNot = $inputAssoc->getIsNot() eq 'NOT'? 1 : 0;

  my $tableId = $self->{targetTableId};

  if (!exists($self->{assocIds}->{$rowId}->{$goTermId}->{$isNot})) {
    my $assoc = GUS::Model::DoTS::GOAssociation->new();
    $assoc->setTableId($tableId);
    $assoc->setRowId($rowId);
    $assoc->setGoTermId($goTermId);
    $assoc->setIsNot($isNot);
    $assoc->setIsDeprecated(0);
    $assoc->setDefining(1);
    $assoc->submit() if (!$assoc->retrieveFromDB());

    $self->{assocIds}->{$rowId}->{$goTermId}->{$isNot}
      = $assoc->getId();
    $self->{newAssocCount}++;
  }

  my $id = $self->{assocIds}->{$rowId}->{$goTermId}->{$isNot};

  $self->{foundAssocs}->{$id} = 1;

  return $id;
}

sub getGoTermId {
  my ($self, $goId, $goDbRlsId) = @_;


  if (!$self->{goTermIds}) {

 my $sql = <<EOSQL;

 SELECT g.ontology_term_id, s.source_id
  FROM   SRes.OntologyTerm g,
         SRes.OntologySynonym s
  WHERE  g.ontology_term_id = s.ontology_term_id
    AND  s.source_id IS NOT NULL
AND s.source_id like 'GO%'
EOSQL

    my $stmt = $self->prepareAndExecute($sql);
    while (my ($go_term_id, $go_id) = $stmt->fetchrow_array()) {
  $go_id =~ s/_/\:/g;
      $self->{goTermIds}->{$go_id} = $go_term_id;

    }

    # also collect SRes.OntologySynonym's: #JP edit: swapped sql so it looks for synonyms first and then the ontology term. 
     $sql = "SELECT ontology_term_id, source_id FROM SRes.OntologyTerm WHERE source_id like 'GO%'";


    $stmt = $self->prepareAndExecute($sql);
    while (my ($go_term_id, $go_id) = $stmt->fetchrow_array()) {
  $go_id =~ s/_/\:/g;

      $self->{goTermIds}->{$go_id} = $go_term_id;

    }

  }
  #print Dumper $self->{goTermIds};

my $goTermId = $self->{goTermIds}->{$goId};
  print "gotermId is $goTermId\n\n\n";
  unless ($goTermId) {
      print "gotermId doesnt exists\n\n";
    if (my $file = $self->getArg('skipBadGOTerms')) {
      $self->log("Skipping bad GO term: $goId\n");
      open(FILE2, ">>$file") or die $!;
      print FILE2 "$goId\n";
      close(FILE2);
   
    } else {
      $self->userError("Can't find GoTerm in database for GO Id: $goId");
    }
  }

  return $goTermId;

}

sub getPriorAssociations {
  my ($self) = @_;

  my $sql = "
SELECT row_id, go_term_id, is_not, go_association_id from DoTS.GOAssociation WHERE table_id = $self->{targetTableId}
";
  my $stmt = $self->prepareAndExecute($sql);
  while (my @row = $stmt->fetchrow_array()) {
    my ($rowId, $goTermId, $isNot, $goAssocId) = @row;
    $self->{assocIds}->{$rowId}->{$goTermId}->{$isNot} =$goAssocId;
  }
}

sub addAssociationInstance {
  my ($self, $assocId, $inputAssoc, $goEvidenceCodeDbRlsId, $DBRef, $with, $source) = @_;

  my $extDbRlsId = $self->getExtDbRlsId($self->getArg('externalDatabaseSpec'));

  return unless $assocId;

  my $instance = GUS::Model::DoTS::GOAssociationInstance->new();
  $instance->setGoAssociationId($assocId);
  $instance->setIsPrimary(1);
  $instance->setGoAssocInstLoeId($self->getLoeId($source));
  $instance->setIsDeprecated(0);
  $instance->setExternalDatabaseReleaseId($extDbRlsId);

  my $evidenceId = $self->getEvidenceId($inputAssoc->getEvidence(),$goEvidenceCodeDbRlsId);
# think i need to edit this bit . 


  my $link = GUS::Model::DoTS::GOAssocInstEvidCode->new();
  $link->setGoEvidenceCodeId($evidenceId);
  $link->setReference($DBRef);
  $link->setEvidenceCodeParameter($with);
  $instance->addChild($link);
  $instance->submit();
  $self->{instanceCount}++;
  print $link->toString();
}

sub getLoeId {
  my ($self, $source) = @_;

  if (!$self->{loeId}) {

    my $loe = GUS::Model::DoTS::GOAssociationInstanceLOE->new();
    if ($source) {
      $loe->setName($source);
    } else {
      $loe->setName($self->getArg('lineOfEvidence'));
    }
    if (!$loe->retrieveFromDB()) {
      $loe->submit();
    }
    $self->{loeId} = $loe->getId();
  }

  return $self->{loeId};
}

sub getEvidenceId {
  my ($self, $evidenceCode, $goEvidenceCodeDbRlsId) = @_;

  if (!$self->{evidenceIds}) {
    my $sql = "select ontology_term_id, source_id from SRes.OntologyTerm  WHERE external_database_release_id = $goEvidenceCodeDbRlsId ";
    my $stmt = $self->prepareAndExecute($sql);
    while (my ($id, $name) = $stmt->fetchrow_array()) { 
      $self->{evidenceIds}->{$name} = $id;
    }
  }
  my $evId = $self->{evidenceIds}->{$evidenceCode};
  $evId || $self->userError("Evidence code '$evidenceCode' not found in db.");
  return $evId;
}

1;

