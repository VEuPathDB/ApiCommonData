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
use GUS::Model::DoTS::ExternalAASequence;
use GUS::Model::DoTS::AALocation;
#use GUS::Model::DoTS::DbRefAAFeature;

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

Also, the plugin doesn't handle huge interproscan result XML files.  It assumes that the result is broken into a number of files, each not-to-big
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

  my $resultDir = $self->getArg('resultFileDir');

  opendir (RESULTSDIR, $resultDir) or die "Could not open dir '$resultDir'\n";
  my @resultFiles = grep { /\.xml$/ } readdir RESULTSDIR;
  closedir RESULTSDIR;

  $self->loadConfig(\@resultFiles, $resultDir);

  my @goDbRlsIds = ($self->getArg('goVersion'));
  $self->{GOAnnotater} =
    ApiCommonData::Load::Utility::GOAnnotater->new($self, \@goDbRlsIds);

  $self->{extDbRlsId} = $self->getExtDbRlsId($self->getArg('extDbName'),
					     $self->getArg('extDbRlsVer'));

  $self->log("Processing ".scalar(@resultFiles)." Interproscan XML result files");

  foreach my $file (@resultFiles) {
    $self->log("Processing $file");
    
    my $twig = XML::Twig->new();
    $twig->parsefile($resultDir . "/" . $file);
    my @proteins = $twig->root()->children('protein');
    foreach my $protein (@proteins) {
      $self->processProteinResults($protein);
    }
  }

  my $totalIprCount = $self->{interproCount} + $self->{noIPR}->{interproCount};
  my $totalGOCount = $self->{GOCount} + $self->{noIPR}->{GOCount} +
    $self->{unfoundGOCount};
  my $totalMatchCount = $self->{matchCount} + $self->{noIPR}->{matchCount};
  my $totalLocationCount = $self->{locationCount} + $self->{noIPR}->{locationCount};
  $self->log("Proteins: $self->{protCount}");
  $self->log("Interpro Hits loaded: $self->{interproCount}");
  $self->log("Interpro Hits ignored (noIPR): $self->{noIPR}->{interproCount}");
  $self->log("Interpro Hits total: $totalIprCount");
  $self->log("GO Associations loaded: $self->{GOCount}");
  $self->log("GO Associations ignored (noIPR): $self->{noIPR}->{GOCount}");
  $self->log("GO Associations unfound: $self->{unfoundGOCount}");
  $self->log("GO Associations total: $totalGOCount");
  $self->log("Matches loaded: $self->{matchCount}");
  $self->log("Matches ignored (noIPR): $self->{noIPR}->{matchCount}");
  $self->log("Matches total: $totalMatchCount");
  $self->log("Locations loaded: $self->{locationCount}");
  $self->log("Locations ignored (noIPR): $self->{noIPR}->{locationCount}");
  $self->log("Locations total: $totalLocationCount");
}

sub processProteinResults {
  my ($self, $protein) = @_;

  my $tableName = $self->getArg('aaSeqTable');
  my $queryTable = "GUS::Model::DoTS::$tableName";

  my $aaId = $self->sourceId2aaSeqId($protein->att('id'));
  my @interproKids = $protein->children('interpro');
  print STDERR "$aaId\n";

  my $gusAASeq = $queryTable->new({ 'aa_sequence_id' => $aaId });
  $gusAASeq->retrieveFromDB()
    || die "Can't find AA sequence with aa_sequence_id '$aaId'";

  foreach my $interpro (@interproKids) {
    my $parentDomain;
    my $isNoIPR = ($interpro->att('id') eq 'noIPR');
    if ($isNoIPR) {
      $self->{noIPR}->{interproCount}++;
    } else {
      $parentDomain = 
	$self->buildDomainFeature($interpro->att('id'), $aaId,
				$self->{INTERPRO}, undef);
      $self->{'interproCount'}++;
    }

    my @classificationKids = $interpro->children('classification');
    foreach my $classification (@classificationKids) {
      if ($isNoIPR) {
	$self->{noIPR}->{GOCount}++;
      } else {
	$self->buildGOAssociation($aaId, $classification->id());
      }
    }

    my @matchKids = $interpro->children('match');
    foreach my $match (@matchKids) {
      my $childDomain;
      if ($isNoIPR) {
	$self->{noIPR}->{matchCount}++;
      } else {
	my $dbname = $match->att('dbname');
	$self->{'matchCount'}++;
	$childDomain =
	  $self->buildDomainFeature($match->id(), $aaId, $self->{$dbname},
				    $parentDomain->getId());
      }
      my @locationKids = $match->children('location');
      foreach my $location (@locationKids) {
	if ($isNoIPR) {
	  $self->{noIPR}->{locationCount}++;
	} else {
	  $self->buildLocation($location, $childDomain);
	  $self->{locationCount}++;
	}
      }
    }
  }
  $self->undefPointerCache();
  $self->{'protCount'}++;
}

sub buildDomainFeature {
  my ($self, $domainSourceId, $aaId, $db, $parentId) = @_;

  my $domainFeat = GUS::Model::DoTS::DomainFeature->
    new({ source_id => $domainSourceId,
	  external_database_release_id => $self->{extDbRlsId},
	  aa_sequence_id => $aaId,
          is_predicted => 1,
	  parent_id => $parentId
	});

  $domainFeat->submit();

  my $dbRefId = $self->{$db}->{dbRefIds}->{$domainSourceId};

#  my $dbRefAaFeat = GUS::Model::DoTS::DbRefAaFeature->
#    new({ dbref_id => $dbRefId,
#	  aa_feature_id => $domainFeat->getId()
#	});
#  $dbRefAaFeat->submit();

  return $domainFeat;
}

sub buildLocation {
  my ($self, $locationElement, $domainFeature) = @_;

  my $start = $locationElement->att('start');
  my $end = $locationElement->att('end');

  my $loc = GUS::Model::DoTS::AALocation->
    new({ start_min => $start,
	  start_max => $start,
	  end_min => $end,
	  end_max => $end,
	  aa_feature_id => $domainFeature->getId()
	});
  $loc->submit();
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
  my ($self, $resultFiles, $resultDir) = @_;

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
  foreach my $resultFile (@$resultFiles) {
    $self->findDbsInResult("$resultDir/$resultFile", \%dbsInResult);
  }

  my @uncoolDbs;
  $self->log("Checking that all matched DBs are loaded in GUS");
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

  $self->error("Can't find AA seq w/ source_id '$sourceId' in $aaSeqTable") 
    unless $self->{sourceId2aaSeqId}->{$sourceId};

  return $self->{sourceId2aaSeqId}->{$sourceId};
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

