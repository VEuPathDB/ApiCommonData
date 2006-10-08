package ApiCommonData::Load::Plugin::InsertInterproscanResults;
@ISA = qw(GUS::PluginMgr::Plugin);

use strict;

use DBI;
use XML::Twig;
use XML::Simple;
use ApiCommonData::Load::Utility::GOAnnotater;
use GUS::PluginMgr::Plugin;
use GUS::Model::SRes::ExternalDatabase;
use GUS::Model::SRes::ExternalDatabaseRelease;
use GUS::Model::DoTS::DomainFeature;
use GUS::Model::DoTS::TranslatedAASequence;
use GUS::Model::DoTS::AALocation;

sub getArgsDeclaration {
  my $argsDeclaration  =
    [

     fileArg({name => 'resultFileDir',
	      descr => 'Directory where multiple XML files of interpro results reside',
	      constraintFunc=> undef,
	      reqd  => 1,
	      isList => 0,
	      mustExist => 1,
	      format=>'Text'
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
		descr => 'The version of GO to use for GO associations',
		constraintFunc=> undef,
		reqd  => 1,
		isList => 0
	       }),

     enumArg({name => 'aaSeqTable',
	      descr => 'Where to find AA sequences used in Interproscan',
	      constraintFunc=> undef,
	      reqd  => 1,
	      isList => 0,
	      enum => "ExternalAASequence, TranslatedAASequence",
	     }),
    ];

  return $argsDeclaration;
}


sub getDocumentation {

  my $description = <<NOTES;
Load the results output by InterproScan.  This application will load the hits for the specific database matches (e.g. Pfam, Prints, ProDom, Smart) as well as the GO classifications encountered.  The applications takes as input interpro XML.  Hits on databases are loaded into DoTS.DomainFeature.  GO Terms are loaded into DoTS.GOAssociation.  InsertInterproDomainDbs plugin must be run firt to load the domains into SRes.DbRef. 
NOTES

  my $purpose = <<PURPOSE;
Create DomainFeatures for various domain databases such as Pfam and Smart in GUS, and GOAssociations
PURPOSE

  my $purposeBrief = <<PURPOSEBRIEF;
Load the contents of an Interproscan Match XML into GUS.
PURPOSEBRIEF

  my $syntax = <<SYNTAX;
Standard Plugin Syntax.
SYNTAX

  my $notes = <<NOTES;
This plugin assumes that the AA sequences being analyzed are in TranslatedAASequence or ExternalAASequence, and, further, that the sourceIds in that table are unique. (To change this, add plugin args to get the ExtDb namd and release for the seqs, and add that to the query that gets the sequences).
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
SRes.GOTerm
SRes.GOEvidenceCode
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

  $self->initialize({requiredDbVersion => 3.5,
                     cvsRevision => '$Revision$',
                     name => ref($self),
                     argsDeclaration   => $args,
                     documentation     => $documentation
                    });
  return $self;
}


sub run {
  my ($self, @params) = @_;

  my $resultDir = $self->getArgs('resultFileDir');

  opendir (RESULTSDIR, $resultDir) or die "Could not open dir '$resultDir'\n";
  my @resultFiles = grep { /\.xml$/ } readdir RESULTSDIR;
  closedir RESULTSDIR;

  $self->loadConfig(\@resultFiles);

  my @goDbRlsIds = ($self->getArg('goVersions'));
  my $self->{GOAnnotater} =
    ApiCommonData::Load::Utility::GOAnnotater->new($self, \@goDbRlsIds);

  $self->{extDbRlsId} = $self->getExtDbRlsId($self->getArg('extDbName'),
					     $self->getArg('extDbRlsVer'));

  print "Processing ".scalar(@resultFiles)." Interproscan XML result files\n";

  foreach my $file (@resultFiles) {
    my $twig = XML::Twig->
      new( twig_roots => { protein => processTwig($self) } );
    $twig->parsefile($resultDir . "/" . $file);
    $twig->purge;
  }

  my $logCnt = $self->{'protCount'};
  $self->log("Total Seqs Processed: $self->{aaCount}\n");
  $self->log("Total Interpro Hits: $self->{interproCount} \n");
  $self->log("Total GO Terms: $self->{GOCount} \n");
  $self->log("Total Matches: $self->{matchCount} \n");
}

sub processTwig {
  my $self = shift;

  return sub {
    my $twig = shift;

    $self->processProteinResults($twig);
  }
}

sub processProteinResults {
  my ($self, $twig) = @_;

  my $tableName = $self->getArg('queryTable');
  my $queryTable = "GUS::Model::DoTS::$tableName";

  my $root = $twig->root();

  while (my $protein = $root->next_elt()) {
    my $aaId = $self->sourceId2aaSeqId($protein->att('id'));

    my $gusAASeq = $queryTable->new({ 'aa_sequence_id' => $aaId });
    $gusAASeq->retrieveFromDB() || die "no such AA sequence";

    while (my $element = $protein->next_elt()) {
      my $parentDomain;
      my $id = $element->att('id');
      if ($element->tag() eq 'interpro') {
	unless ($id eq 'noIPR') {
	  $parentDomain =
	    $self->buildDomainFeature($id, $aaId, $self->{INTERPRO}, undef);
	  $self->{'interproCount'}++;
	}
      }
      if ($element->tag() eq 'classification') {
	$self->buildGOAssociation($aaId, $id) && $self->{'GOCount'}++;
      }
      if ($element->tag() eq 'match') {
	my $dbname = $element->att('dbname');
	$self->{'matchCount'}++;
	my $childDomain =
	  $self->buildDomainFeature($id, $aaId, $self->{$dbname}, $parentDomain);
	while (my $locationElement = $element->next_elt()) {
	  if ($locationElement->tag() eq 'location') {
	    $self->addLocation($locationElement, $childDomain);
	  }
	}
      }
    }
    $protein->purge();
    $self->{'protCount'}++;
    $self->undefPointerCache();
  }
}

sub buildDomainFeature {
  my ($self, $domainSourceId, $aaId, $db, $parentId) = @_;

  my $domainFeat = GUS::Model::DoTS::DomainFeature->
    new({ source_id => $domainSourceId,
	  external_database_release_id => $self->{extDbRlsId},
	  aa_sequence_id => $aaId,
	  parent_id => $parentId
	});

  $domainFeat->submit();

  my $dbRefId = $self->{$db}->{dbRefIds}->{$domainSourceId};
  my $dbRefAaFeat = GUS::Model::DoTS::DbRefAaFeature->
    new({ dbref_id => $dbRefId,
	  aa_feature_id => $domainFeat->getId()
	});
  $dbRefAaFeat->submit();

  return $domainFeat;
}

sub buildLocation {
  my ($self, $locationElement, $domainFeature) = @_;

  my $start = $locationElement->att('start');
  my $end = $locationElement->att('end');

  my $gusLoc = GUS::Model::DoTS::AALocation->
    new({ start_min => $start,
	  start_max => $start,
	  end_min => $end,
	  end_max => $end,
	  aa_feature_id => $domainFeature->getId()
	});
}

sub buildGOAssocation {
  my ($self, $aaId, $classId) = @_;

  if ($classId !~ /^GO:\d+/) {
    $self->error ("Expecting GO classification, but got \'$classId\'");
  }

  my $goTermId = $self->{GOAnnotater}->getGoTermId($classId);

  if (! $goTermId) {
    $self->log ("$aaId: No go_term_id found for GO Id \'$classId\'\n");
    return 0;
  }

  my $evidence = $self->{GOAnnotater}->getEvidenceCode('IEA');

  my $loe = $self->{GOAnnotater}->getLoeId('Interpro');

  my $goAssociation = {
		       'tableId' => $self->{'RefTableId'},
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
  my ($self, $resultFiles) = @_;

  my $cFile = $self->getArg('confFile');

  my $conf = $self->parseSimple($cFile);

  my $dbs = $conf->{'db'};	#list of Db names and versions

  foreach my $dbName (keys %$dbs) {
    $self->{$dbName}->{dbRefIds} =
      $self->getDbRefIds($dbName, $dbs->{$dbName}->{ver});
  }

  my %dbsInResult;
  foreach my $resultFile (@$resultFiles) {
    $self->findDbsInResult($resultFile, \%dbsInResult);
  }

  my @uncoolDbs;
  foreach my $dbInResult (keys %dbsInResult) {
    push(@uncoolDbs, $dbInResult) unless ($self->{$dbInResult});
  }
  if (scalar(@uncoolDbs) != 0) {
    self->error("Result contains matches to databases that are not loaded into GUS: " . join(", ", @uncoolDbs));
  }
}

sub parseSimple{
  my ($self,$file) = @_;

  my $simple = XML::Simple->new();
  my $tree = $simple->XMLin($file, keyattr=>['name'], forcearray=>1);

  return $tree;
}

# return a hash of domain sourceId to DbRef ID
sub getDbRefIds {
  my ($self, $dbName, $version) = @_;

  my %sourceId2dbRefId;
  my $sql = "
SELECT dbr.source_id, dbr.dbref_id
FROM SRes.DbRef dbr, SRes.ExternalDatabase ed, SRes.ExternalDatabasRelease edr
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
  my ($resultFile, $dbsInResult) = @_;

  open(FILE, $resultFile) || die "couldn't open result file '$resultFile'\n";
  while (FILE) {
   $dbsInResult->{$1} = 1 if /dbname=\"(\w+)\"/;
 }
}

# this could (should) be improved to take the ext db info of the aa's.
# as is, it assumes the source_ids are unique in the table, and that the
# table isn't huge.
sub sourceId2aaSeqId {
  my ($self, $sourceId) = @_;

  my $aaSeqTable = $self->getArg('aaSeqTable');

  unless ($self->{sourceId2aaSeqId}) {

    $self->{sourceId2aaSeqId} = {};

    my $sql = "
SELECT source_id, aa_sequence_id
FROM Dots.$aaSeqTable
";
    my $stmt = $self->prepareAndExecute($sql);
    while ( my($sourceId, $aa_sequence_id) = $stmt->fetchrow_array()) {
      $self->{sourceId2aaSeqId}->{$sourceId} = $aa_sequence_id;
    }
  }

  return $self->{sourcdId2aaSeqId}->{$sourceId};
}

sub undoTables {
  my ($self) = @_;

  return (
	  'DoTS.DomainFeature',
	  'DoTS.AALocation',
	  'Core.Algorithm',
	  ApiCommonData::Load::Utility::GOAnnotater->undoTables()
	 );
}

1;

