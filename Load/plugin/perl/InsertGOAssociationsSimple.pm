package ApiCommonData::Load::Plugin::InsertGOAssociationsSimple;

@ISA = qw( GUS::PluginMgr::Plugin);

use CBIL::Bio::GeneAssocParser::Parser;
use GUS::PluginMgr::Plugin;
use GUS::Model::DoTS::GOAssociationInstance;
use GUS::Model::DoTS::GOAssociationInstanceLOE;
use GUS::Model::DoTS::GOAssociation;
use GUS::Model::DoTS::GOAssocInstEvidCode;

use FileHandle;
use Carp;
use lib "$ENV{GUS_HOME}/lib/perl";
use strict;

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
	[['SRes.GOTerm', 'Retrieves information about a GOTerm from this table'],
	 ['SRes.GORelationship', 'Retrieves information about GO Hierarchy relationships among GO Terms from this table'],
	 ['SRes.ExternalDatabaseRelease', 'Information about the latest release of the Gene Ontology and the organism to be loaded must be provided here'],
	 ['SRes.GOEvidenceCode', 'The different GO Evidence Codes as defined by the GO Consortium must be provided in this table'],
	 ['DoTS.ExternalAASequence', 'Sequences with which to make Associations must be provided here'],
	 ['Core.TableInfo', 'An entry for DoTS.ExternalAASequence must be provided here']];

my $howToRestart = <<PLUGIN_RESTART;
Use the Undo plugin, and re-run.
PLUGIN_RESTART

my $failureCases = <<PLUGIN_FAILURE_CASES;
None that we've found so far.
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

         stringArg({name => 'goExternalDatabaseSpec',
	    descr => 'Targeted GO Term database release (in "name|version" fomat)',
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

    $self->initialize({requiredDbVersion => 3.5,
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

    my $goDbRlsId = 
      $self->getExtDbRlsId($self->getArg('goExternalDatabaseSpec'));

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

	my $rowId = $self->getTargetRowId($sourceId);

	next if $self->targetNotFound($rowId, $sourceId, $inputAssoc);

	my $assocId = $self->findAssociationId($rowId,$inputAssoc,$goDbRlsId);

	$self->addAssociationInstance($assocId, $inputAssoc);

	$self->log("processing $sourceId; processed $count lines")
	    if ($logFrequency && ($count % $logFrequency == 0));
	$self->undefPointerCache();
      }

    my $totalAssocCount = scalar(keys(%{$self->{foundAssocs}}));
    my $msg = "Processed $count input associations.  Found $totalAssocCount distinct Associations, of which $self->{newAssocCount} were new (not in db already).  Created $self->{instanceCount} instances.  $self->{skipCount} associations were ignored ($self->{distinctSkipCount} distinct) because their sequence could not be found in the database";

    return $msg;
}

sub undoTables {
  my ($self) = @_;

  return ('DoTS.GOAssocInstEvidCode',
	  'DoTS.GOAssociationInstance',
	  'DoTS.GOAssociationInstanceLOE',
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
    $assoc->submit();

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
    my $sql = "SELECT go_term_id, go_id FROM SRes.GOTerm WHERE external_database_release_id = $goDbRlsId";

    my $stmt = $self->prepareAndExecute($sql);
    while (my ($go_term_id, $go_id) = $stmt->fetchrow_array()) {
      $self->{goTermIds}->{$go_id} = $go_term_id;
    }

    # also collect SRes.GOSynonym's:
    $sql = <<EOSQL;

  SELECT g.go_term_id, s.source_id
  FROM   SRes.GOTerm g,
         SRes.GOSynonym s
  WHERE  g.go_term_id = s.go_term_id
    AND  s.source_id IS NOT NULL
    AND  g.external_database_release_id = $goDbRlsId
EOSQL

    $stmt = $self->prepareAndExecute($sql);
    while (my ($go_term_id, $go_id) - $stmt->fetchrow_array()) {
      $self->{goTermids}->{$go_id} = $go_term_id;
    }

  }

  my $goTermId = $self->{goTermIds}->{$goId};

  unless ($goTermId) {
    if (my $file = $self->getArg('skipBadGOTerms')) {
      $self->log("Skipping bad GO term: $goId\n");
      open(FILE, ">>$file") or die $!;
      print FILE "$goId\n";
      close(FILE);
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
  my ($self, $assocId, $inputAssoc) = @_;

  my $extDbRlsId = $self->getExtDbRlsId($self->getArg('externalDatabaseSpec'));

  return unless $assocId;

  my $instance = GUS::Model::DoTS::GOAssociationInstance->new();
  $instance->setGoAssociationId($assocId);
  $instance->setIsPrimary(1);
  $instance->setGoAssocInstLoeId($self->getLoeId());
  $instance->setIsDeprecated(0);
  $instance->setExternalDatabaseReleaseId($extDbRlsId);

  my $evidenceId = $self->getEvidenceId($inputAssoc->getEvidence());

  my $link = GUS::Model::DoTS::GOAssocInstEvidCode->new();
  $link->setGoEvidenceCodeId($evidenceId);
  $instance->addChild($link);
  $instance->submit();
  $self->{instanceCount}++;
}

sub getLoeId {
  my ($self) = @_;

  if (!$self->{loeId}) {

    my $loe = GUS::Model::DoTS::GOAssociationInstanceLOE->new();
    $loe->setName($self->getArg('lineOfEvidence'));
    if (!$loe->retrieveFromDB()) {
      $loe->submit();
    }
    $self->{loeId} = $loe->getId();
  }

  return $self->{loeId};
}

sub getEvidenceId {
  my ($self, $evidenceCode) = @_;

  if (!$self->{evidenceIds}) {
    my $sql = "select go_evidence_code_id, name from sres.goevidencecode";
    my $stmt = $self->prepareAndExecute($sql);
    while (my ($id, $name) = $stmt->fetchrow_array()) { 
      $self->{evidenceIds}->{$name} = $id;
    }
  }
  my $evId = $self->{evidenceIds}->{$evidenceCode};
  $evId || $self->userError("Evidence code '$evidenceCode' not found in db.");
  return $evId;
}

sub getSequenceId{
    my ($self, $sourceId) = @_;
    my $dbIdCol = $self->{orgInfo}->{dbIdCol};
    my $dbList = $self->getArg('orgExternalDbReleaseList');
    #my $dbList = '( ' . join (',', @{$self->getArg('orgExternalDbReleaseList') }) . ') ';

    my $sql = "select eas.aa_sequence_id
               from dots.externalAASequence eas
               where $dbIdCol = '$sourceId'
	       and eas.external_database_release_id in ($dbList)";

    my $sth = $self->prepareAndExecute($sql);
    my ($seqGusId) = $sth->fetchrow_array();

    return $seqGusId;
}

1;

