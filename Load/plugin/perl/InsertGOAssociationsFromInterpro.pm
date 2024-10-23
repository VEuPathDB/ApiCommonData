package ApiCommonData::Load::Plugin::InsertGOAssociationsFromInterpro;
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
  # GUS4_STATUS | dots.gene                      | manual | reviewed
#^^^^^^^^^^^^^^^^^^^^^^^^^ End GUS4_STATUS ^^^^^^^^^^^^^^^^^^^^
@ISA = qw(GUS::PluginMgr::Plugin);

use strict;

use DBI;
use XML::Simple;
use GUS::Supported::Utility::GOAnnotater;
use GUS::PluginMgr::Plugin;
use GUS::Model::SRes::ExternalDatabase;
use GUS::Model::SRes::ExternalDatabaseRelease;
use GUS::Model::DoTS::DomainFeature;
use GUS::Model::DoTS::TranslatedAASequence;
use GUS::Model::DoTS::ExternalAASequence;
use GUS::Model::DoTS::AALocation;
use GUS::Model::DoTS::DbRefAAFeature;

sub getArgsDeclaration {
  my $argsDeclaration  =
    [

     fileArg ({name => 'interproResultsFile',
               descr => 'The outputFile From the interproscan nextflow workflow',
               constraintFunc => undef,
               reqd => 1,
               isList => 0,
               mustExist => 1,
               format => 'PF3D7_01040001-p1 51d7b793b7d20836c8d138ef558ccb9f 163 Pfam PF19035 CCN3 Nov like TSP1 domain 61 108 7.4E-10 T 21-10-2024 IPR043973 CCN, TSP1 domain GO:0007165'
              }),

     fileArg ({name => 'interpro2GOFile',
               descr => 'The file interpro2GO mappings retrieved from EBI',
               constraintFunc => undef,
               reqd => 1,
               isList => 0,
               mustExist => 1,
               format => 'InterPro:IPR000003 Retinoid X receptor/HNF4 > GO:DNA binding ; GO:0003677'
              }),

     fileArg({name => 'confFile',
	      descr => 'XML file containing configuration for this plugin',
	      constraintFunc=> undef,
	      reqd  => 1,
	      mustExist => 0,
	      isList => 0,
	      format=>'Text'
	     }),

     stringArg({name => 'extDbName',
		descr => 'External database for the data inserted',
		constraintFunc=> undef,
		reqd  => 0,
		isList => 0
	       }),

     stringArg({name => 'extDbRlsVer',
		descr => 'Version of external database for the data inserted',
		constraintFunc=> undef,
		reqd  => 0,
		isList => 0
	       }),

     stringArg({name => 'goVersion',
		descr => 'The name and version (caret delimited) of GO to use for GO associations, for example "Gene Ontology^3.125',
		constraintFunc=> undef,
		reqd  => 1,
		isList => 0
	       }),

     enumArg({name => 'aaSeqTable',
	      descr => 'Where to find AA sequences used in Interproscan',
	      constraintFunc=> undef,
	      reqd  => 1,
	      isList => 0,
	      enum => "ExternalAASequence, TranslatedAASequence, AASequence",
	     }),

     stringArg({name => 'srcIdColumn',
		descr => 'The column of the primary id for each protein used in the interproScan',
		constraintFunc=> undef,
		reqd  => 0,
		isList => 0,
                default => 'source_id',
	       }),

     stringArg({name => 'srcIdRegex',
		descr => 'The column of the primary id for each protein used in the interproScan',
		constraintFunc=> undef,
		reqd  => 0,
		isList => 0,
                default => '^(\S+)',
	       }),

     integerArg({name  => 'testnumber',
		 descr => 'Number of query sequences to process for testing',
		 reqd  => 0,
		 constraintFunc=> undef,
		 isList=> 0,
		}),
    ];

  return $argsDeclaration;
}

sub getDocumentation {

  my $description = <<NOTES;
Load the results output by InterproScan and any additional mappings from interpro2go from EBI. This application will load the hits for the specific database matches (e.g. Pfam, Prints, ProDom, Smart) as well as the GO classifications encountered.  The applications takes as input interpro XML.  Hits on databases are loaded into DoTS.DomainFeature.  GO Terms are loaded into DoTS.GOAssociation.  InsertInterproDomainDbs plugin must be run firt to load the domains into SRes.DbRef. 
NOTES

  my $purpose = <<PURPOSE;
Create DomainFeatures for various domain databases such as Pfam and Smart in GUS, and GOAssociations
PURPOSE

  my $purposeBrief = <<PURPOSEBRIEF;
Load the contents of an Interproscan Match XML and interpro2go from EBI into GUS.
PURPOSEBRIEF

  my $syntax = <<SYNTAX;
Standard Plugin Syntax.
SYNTAX

  my $notes = <<NOTES;
This plugin assumes that the AA sequences being analyzed are in TranslatedAASequence or ExternalAASequence, and, further, that the sourceIds in that table are unique. (To change this, add plugin args to get the ExtDb namd and release for the seqs, and add that to the query that gets the sequences).

Also, the plugin does not handle huge interproscan result XML files.  It assumes that the result is broken into a number of files, each not-to-big
NOTES

  my $tablesAffected = <<AFFECT;
DoTS.DomainFeature
DoTS.AALocation
DoTS.GOAssociation
DoTS.GOAssociationInstance
DoTS.GOAssociationInstanceLOE
DoTS.GOAssocInstEvidCode
AFFECT

  my $tablesDependedOn = <<TABD;
DoTS.AASequenceImp
SRes.ExternalDatabaseRelease
SRes.ExternalDatabaseEntry
Core.TableInfo
TABD

  my $howToRestart = <<RESTART;
No restart facilities at the present time.  All inserts are qualified with a RetrieveFromDb so you should be able to restart by rerunning and all previously loaded data will be skipped.
RESTART

  my $failureCases = <<FAIL;
Most significant failure cases should happen early in the configuration of the plugin if it cannot load the XML file or if it finds that the configuration of the external databases is incorrect.
FAIL

  my $documentation = {purpose=>$purpose, purposeBrief=>$purposeBrief,tablesAffected=>$tablesAffected,tablesDependedOn=>$tablesDependedOn,howToRestart=>$howToRestart,failureCases=>$failureCases,notes=>$notes};

  return ($documentation);
}

sub new {
  my $class = shift;
  my $self = {};
  bless($self, $class);

  my $documentation = &getDocumentation();

  my $args = &getArgsDeclaration();

  $self->initialize({requiredDbVersion => 4.0,
                     cvsRevision => '$Revision$',
                     name => ref($self),
                     argsDeclaration   => $args,
                     documentation     => $documentation
                    });
  return $self;
}

sub run {
  my ($self, @params) = @_;

  my $interproResultsFile = $self->getArg('interproResultsFile');
  my $interpro2GOFile =$self->getArg('interpro2GOFile');

  # This sections reads the interpro2GO file retrieved from EBI and maps the interproFamilyID to its assigned GO annotation
  my %interproFamilyToGo;
  open(my $interpro2GO, '<', $interpro2GOFile) || die "Could not open file $interpro2GOFile: $!";
  while (my $line = <$interpro2GO>) {
      chomp $line;
      next if ($line !~ /^InterPro:/);
      if ($line =~ /^InterPro:(IPR\d+).*\>\sGO:\d+\s;\s(GO:\d+)/) {
	  $interproFamilyToGo{$1} = $3;
      }
  }

  $self->loadConfig($interproResultsFile);

  my $goVersion = $self->getArg('goVersion');
  $self->{GOAnnotater} = GUS::Supported::Utility::GOAnnotater->new($self, ["GO_RSRC^$goVersion"], "GO_evidence_codes_RSRC^%");

  $self->{extDbRlsId} = $self->getExtDbRlsId($self->getArg('extDbName'), $self->getArg('extDbRlsVer'));

  $self->log("Processing Interproscan tsv result file $interproResultsFile");

  open (TABFILE, "$interproResultsFile") || die "File not found: $interproResultsFile\n";
  while (<TABFILE>) {
    chomp;
    my @myArray = split(/\t/, $_);
    # Retrieve GO associations from interpro2go
    my $interproFamilyGoAssociations = $interproFamilyToGo{$myArray[11]};
    $self->processProteinResults($interproFamilyGoAssociations,\@myArray);
    last if ($self->getArg('testnumber') && $self->{interproCount}+$self->{noIPR}->{interproCount} >= $self->getArg('testnumber'));
  }

  my $totalIprCount = $self->{interproCount} + $self->{noIPR}->{interproCount};
  my $totalGOCount = $self->{GOCount} + $self->{unfoundGOCount};
  my $totalMatchCount = $self->{matchCount} + $self->{noIPR}->{matchCount};
  my $totalLocationCount = $self->{locationCount} + $self->{noIPR}->{locationCount};
  $self->log("Proteins: $self->{protCount}");
  $self->log("Interpro Hits loaded: $self->{interproCount}");
  $self->log("Interpro Hits loaded (noIPR): $self->{noIPR}->{interproCount}");
  $self->log("Interpro Hits total: $totalIprCount");
  $self->log("GO Associations loaded: $self->{GOCount}");
  $self->log("GO Associations unfound: $self->{unfoundGOCount}");
  $self->log("GO Associations total: $totalGOCount");
  $self->log("Matches loaded: $self->{matchCount}");
  $self->log("Matches loaded (noIPR): $self->{noIPR}->{matchCount}");
  $self->log("Matches total: $totalMatchCount");
  $self->log("Locations loaded: $self->{locationCount}");
  $self->log("Locations loaded (noIPR): $self->{noIPR}->{locationCount}");
  $self->log("Locations total: $totalLocationCount");
  $self->log("testnumber = " . $self->getArg('testnumber'))
  if $self->getArg('testnumber');
  $self->testRowsLoaded;
  return "Done inserting Interpro scan results\n";
}

# ======================================================================================================================

sub processProteinResults {
  my ($self, $interproFamilyGoAssociations, $proteins) = @_;

  my $tableName = $self->getArg('aaSeqTable');
  my $regex = $self->getArg('srcIdRegex');
  my $queryTable = "GUS::Model::DoTS::$tableName";
  my $protein_id = $1 if($proteins->[0] =~ m/$regex/);
  if (!$protein_id) {
  	$self->log("Skipping: Interproscan Results file has a match with empty source ID");
	return;
  }
  my $aaId = $self->sourceId2aaSeqId($protein_id);

  return unless $aaId; #remove this - DP

  my $gusAASeq = $queryTable->new({ 'aa_sequence_id' => $aaId });
  $gusAASeq->retrieveFromDB()
    || die "Can't find AA sequence with aa_sequence_id '$aaId'";

    my $parentId;
    if (!$proteins->[11]) {
      $self->{noIPR}->{interproCount}++;
    } else {
      my $parentDomain = 
	$self->buildDomainFeature($proteins->[11], $aaId,
				"INTERPRO", undef);
      $parentId = $parentDomain->getId();
      $self->{'interproCount'}++;
    }

    # Load found mappings from interpro AND from interpro2GO file from EBI
    if ($proteins->[13] || $interproFamilyGoAssociations){
	my @classificationKids = split(/\|/,$proteins->[13]);
	my @classificationFromEbi = split(/\|/,$interproFamilyGoAssociations);
        my @allClassifications = (@classificationKids, @classificationFromEbi);
	my %seen;
	foreach my $classification (@allClassifications) {
            $self->log ("classification is $classification");
            next if ($seen{$classification} || $classification =~ /-/);
	    $self->buildGOAssociation($aaId, $classification);
            $seen{$classification} = "true";
	}
    }

    my $childDomain;
    if (!$proteins->[11]) {
	$self->{noIPR}->{matchCount}++;
      } else {
	$self->{'matchCount'}++;
      }
      my $dbname = uc $proteins->[3];

      $childDomain = $self->buildDomainFeature($proteins->[4], $aaId, $dbname,
				  $parentId, $proteins->[8]);
      if (!$proteins->[11]) {
	  $self->{noIPR}->{locationCount}++;
      } else {
	  $self->{locationCount}++;
      }

      $self->buildLocation($proteins->[6], $proteins->[7], $childDomain);



    last if ($self->getArg('testnumber') && $self->{interproCount}
	     + $self->{noIPR}->{interproCount} >= $self->getArg('testnumber'));
  
  $self->undefPointerCache();
  $self->{'protCount'}++;
}

sub buildDomainFeature {
  my ($self, $domainSourceId, $aaId, $dbName, $parentId, $evalue) = @_;
	
  my $domainFeat = GUS::Model::DoTS::DomainFeature->
    new({ source_id => $domainSourceId,
	  external_database_release_id => $self->{extDbRlsId},
	  aa_sequence_id => $aaId,
          is_predicted => 1,
	  parent_id => $parentId,
	  e_value => $evalue
	});

  $domainFeat->submit() unless $domainFeat->retrieveFromDB();
	
  my $dbRefId = $self->{$dbName}->{dbRefIds}->{$domainSourceId};

  my $dbRefAaFeat = GUS::Model::DoTS::DbRefAAFeature->
    new({ db_ref_id => $dbRefId,
	  aa_feature_id => $domainFeat->getId()
	});

  $dbRefAaFeat->submit() if ($dbRefId && !$dbRefAaFeat->retrieveFromDB());

  return $domainFeat;
}

sub buildLocation {
  my ($self, $start, $end, $domainFeature) = @_;

  my $loc = GUS::Model::DoTS::AALocation->
    new({ start_min => $start,
	  start_max => $start,
	  end_min => $end,
	  end_max => $end,
	  aa_feature_id => $domainFeature->getId()
	});
  $loc->submit() unless $loc->retrieveFromDB();
}

sub buildGOAssociation {
  my ($self, $aaId, $classId) = @_;

  if ($classId !~ /^GO:\d+/) {
    $self->error ("Expecting GO classification, but got \'$classId\'");
  }

  my $goTermId = $self->{GOAnnotater}->getGoTermId($classId);

  if (! $goTermId) {
    $self->log ("$aaId: No go_term_id found for GO Id \'$classId\'");
    $self->{unfoundGOCount}++;
    return;
  }
  $self->{'GOCount'}++;
  my $evidence = $self->{GOAnnotater}->getEvidenceCode('IEA');

  my $loe = $self->{GOAnnotater}->getLoeId('Interpro');

  if (!$self->{aaTableId}) {
    $self->{aaTableId} = 
      $self->className2TableId("DoTS::" . $self->getArg('aaSeqTable'));
  }


  my $goAssociation = {
		       'tableId' => $self->{'aaTableId'},
		       'rowId' => $aaId,
		       'goTermId' => $goTermId,
		       'isNot' => 0,
		       'isDefining' => 1,
		      };

  my $assoc = $self->{GOAnnotater}->getOrCreateGOAssociation($goAssociation);

  my $goInstance = {
		    'goAssociation' => $assoc,
		    'evidenceCode' => $evidence,
		    'lineOfEvidence' => $loe,
		    'isPrimary' => '1',
		   };

  my $goInstance = $self->{GOAnnotater}->getOrCreateGOInstance($goInstance);

  return 1;

}

sub loadConfig{
  my ($self, $resultFile) = @_;

  my $cFile = $self->getArg('confFile');

  my $conf = $self->parseSimple($cFile);

  my $dbs = $conf->{'db'};	#list of Db names and versions

  foreach my $dbName (keys %$dbs) {
    $self->log("Getting dbRefIds for $dbName");
    $self->{$dbName}->{dbRefIds} =
      $self->getDbRefIds($dbName, $dbs->{$dbName}->{ver});
  }

  my %dbsInResult;
  $self->log("Scanning result files to find DBs that we matched against");
  $self->findDbsInResult("$resultFile", \%dbsInResult); 

  my @uncoolDbs;
  $self->log("Checking that all matched DBs are loaded in GUS");
  foreach my $dbInResult (keys %dbsInResult) {
    push(@uncoolDbs, $dbInResult) unless ($self->{$dbInResult});
  }
  if (scalar(@uncoolDbs) != 0) {
    $self->error("Result contains matches to databases that are not loaded into GUS: " . join(", ", @uncoolDbs));
  }
}

sub parseSimple{
  my ($self,$file) = @_;


  # wrap in eval to dodge xml simple error handling issue
  # can lose the eval when GusApplication retires use of Error.pm
  # see redmine #5982
  my $tree;
  eval {
    my $simple = XML::Simple->new();
    $tree = $simple->XMLin($file, keyattr=>['name'], forcearray=>1);
  };
  if ( $@ ) {
    die "$@";
  }
  return $tree;

}

# return a hash of domain sourceId to DbRef ID
sub getDbRefIds {
  my ($self, $dbName, $version) = @_;

  my %sourceId2dbRefId;
  my $sql = "
SELECT dbr.primary_identifier, dbr.db_ref_id
FROM SRes.DbRef dbr, SRes.ExternalDatabase ed, SRes.ExternalDatabaseRelease edr
WHERE ed.name = '$dbName'
AND edr.version = '$version'
AND edr.external_database_id = ed.external_database_id
AND dbr.external_database_release_id = edr.external_database_release_id
";
  my $stmt = $self->prepareAndExecute($sql);
  while ( my($sourceId, $dbrefId) = $stmt->fetchrow_array()) {
    $sourceId2dbRefId{$sourceId} = $dbrefId;
  }
  return \%sourceId2dbRefId;
}

sub findDbsInResult {
  my ($self, $resultFile, $dbsInResult) = @_;

  open(FILE, $resultFile) || die "couldn't open result file '$resultFile'\n";
  while (<FILE>) {
   $dbsInResult->{$1} = 1 if /dbname=\"(\w+)\"/;
 }
}

# this could (should) be improved to take the ext db info of the aa's.
# as is, it assumes the source_ids are unique in the table, and that the
# table isn't huge.
sub sourceId2aaSeqId {
  my ($self, $sourceId) = @_;

  my $aaSeqTable = $self->getArg('aaSeqTable');

  my $srcIdColumn = $self->getArg('srcIdColumn');

  unless ($self->{sourceId2aaSeqId}) {

    $self->{sourceId2aaSeqId} = {};

    my $sql = "
SELECT $srcIdColumn, aa_sequence_id
FROM Dots.$aaSeqTable
";

    $self->{sourceId2aaSeqId}->{$sourceId} = 0;    #remove this - DP
    my $stmt = $self->prepareAndExecute($sql);
    while ( my($sourceId, $aa_sequence_id) = $stmt->fetchrow_array()) {
      $self->{sourceId2aaSeqId}->{$sourceId} = $aa_sequence_id;
    }
  }

  #$self->error("Can't find AA seq w/ source_id '$sourceId' in $aaSeqTable")  #restore this - DP
    $self->log ("Can't find AA seq w/ source_id '$sourceId' in $aaSeqTable") unless $self->{sourceId2aaSeqId}->{$sourceId}; 

  return $self->{sourceId2aaSeqId}->{$sourceId};
}


sub testRowsLoaded {
  my ($self) = @_;
  
  my $algInvId   = $self->getAlgInvocation()->getId();

  my $sql = "SELECT count(*) FROM DoTS.DomainFeature where row_alg_invocation_id in ($algInvId)";

  my $stmt = $self->prepareAndExecute($sql);

  my $loadedDomainFeature = $stmt->fetchrow_array();
 
  die "The plugin loaded no result rows!\n" unless ($loadedDomainFeature);
}




sub undoPreprocess {
  my ($self, $dbh, $rowAlgInvocationList) = @_;

  GUS::Supported::Utility::GOAnnotater::undoPreprocess($dbh, $rowAlgInvocationList);  
}

sub undoTables {
  my ($self) = @_;

  return (
	  'DoTS.AALocation',
	  'DoTS.DbRefAAFeature',
	  'DoTS.DomainFeature',
	  GUS::Supported::Utility::GOAnnotater->undoTables()
	 );
}

1;
