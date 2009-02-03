#######################################################################
##                 InsertDBxRefs.pm
##
## Creates new entries in the tables SRes.DbRef and DoTS.DbRefNAFeature
## Sres.externaldatabase and Sres.externaldatabaserelease to represent
## mappings to external resources that are found in a tab delimited file
## 
## This is a dedicated plugin for InsertNrdbXrefs, several things are hard 
## coded.
#######################################################################

package ApiCommonData::Load::Plugin::InsertNrdbXrefs;
@ISA = qw( GUS::PluginMgr::Plugin);

use strict 'vars';

use GUS::PluginMgr::Plugin;
use lib "$ENV{GUS_HOME}/lib/perl";
use FileHandle;
use Carp;
use ApiCommonData::Load::Util;
use GUS::Model::SRes::DbRef;
use GUS::Model::SRes::ExternalDatabase;
use GUS::Model::SRes::ExternalDatabaseRelease;
use Data::Dumper;

my $purposeBrief = <<PURPOSEBRIEF;
Creates new entries in tables SRes.DbRef and DoTS.DbRefNAFeature,Sres.externaldatabase and Sres.externaldatabaserelease to represent new DBxRef associations with NAFeature.This is a dedicated plugin for InsertNrdbXrefs, several things are hard coded.
PURPOSEBRIEF

my $purpose = <<PLUGIN_PURPOSE;
Takes in a tab delimited file and creates new entries in tables SRes.DbRef, DoTS.DbRefNAFeature to represent new DbRef/NAFeature class associations.
PLUGIN_PURPOSE

my $tablesAffected =
	['SRes.DbRef', 'The entries representing the new links to the external datasets will go here.'],['DoTS.DbRefNAFeature', 'The entries representing the new DbRef/NAFeature class mappings are created here.'],['Sres.externaldatabase'],['Sres.externaldatabaserelease'];

my $tablesDependedOn = [['DoTS.NAFeature', 'The genes to be linked to external datasets are found here.'],['DoTS.NAGene','If the gene id is not found in DoTS.NAFeature, this table will be checked in case the gene id is an alias.'],['DoTS.AAFeature','The aa features to be linked to external databasets are found here.'],['DoTS.AASequence','The aa sequences to be linked to external database will be found here.'],['Dots.ExternalNASequence','The NA sequence to be linked to externaldatabases may be found here'],['DoTS.VirtualSequence','This table is checked if the NA sequence is not found in DoTS.ExternalNASequence.']];

my $howToRestart = <<PLUGIN_RESTART;
There is currently no restart method.
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
   fileArg({name => 'DbRefMappingFile',
	  descr => 'pathname for the list files containing the DbRef mapping data',
	  constraintFunc => undef,
	  reqd => 1,
	  isList => 0,
	  mustExist => 1,
	  format => 'Four column tab delimited file: feature source_id, dbref secondary_identifier, dbref primary_identifier, dbAbbrevList'
        }),

   stringArg ({name => 'columnSpec',
	       descr => 'Comma delimited list specifying the correspondence of the file columns to the columns in sres.dbref starting with the second column of the file.Ex secondary_identifier,primary_identifier for input line = Tb10.100.0120	70831951	EAN77455.1	gb',
	       reqd => 1,
               constraintFunc => undef,
               isList=> 1
              }),
  ];


sub new {
    my ($class) = @_;
    my $self = {};
    bless($self,$class);


    $self->initialize({requiredDbVersion => 3.5,
		       cvsRevision => '$Revision: 15989 $', # cvs fills this in!
		       name => ref($self),
		       argsDeclaration => $argsDeclaration,
		       documentation => $documentation
		      });

    return $self;
}

sub run {
  my ($self) = @_;

  my $mappingFile = $self->getArg('DbRefMappingFile');

  my $tables = getTableParams();

  my $extDbRlsList = $self->createExtDbAndExtDbRls($mappingFile);
  
#  print Dumper (\%$extDbRlsList);

  my $msg = $self->getMapping($mappingFile, $tables, $extDbRlsList);

  return $msg;
}

sub createExtDbAndExtDbRls{
  my ($self, $mappingFile) = @_;

  open (XREFMAP, "$mappingFile") ||
                    die "Can't open the file $mappingFile.  Reason: $!\n";

  my (%dbAbbrevList,%dbRlsList);
  while (<XREFMAP>){ #first scan of mapping file to cread extDbAndextDbRls for each dbAbbrev

    $self->undefPointerCache(); #if at bottom, not always hit

    next if /^(\s)*$/;
    chomp;

    my @vals = split(/\t/, $_);

    $dbAbbrevList{$vals[3]} = 1;

 }
 
  foreach my $db (keys(%dbAbbrevList)){

      my $dbType =$db =~/gb|emb|dbj/ ? "gb" : $db;
      my $dbName = "NRDB_${dbType}_dbXRefBySeqIdentity";
      my $dbVer = "1.0"; # Don't care

      my $extDbId=$self->InsertExternalDatabase($dbName);

      my $extDbRlsId=$self->InsertExternalDatabaseRls($dbName,$dbVer,$extDbId);

      if ($extDbRlsId){
	  $dbRlsList{$db}=$extDbRlsId;
      }else{
	  die "Couldn't retrieve external database!\n";
      }

  }

  return \%dbRlsList;
}

sub InsertExternalDatabaseRls{

    my ($self,$dbName,$dbVer,$extDbId) = @_;

    my $extDbRlsId = $self->releaseAlreadyExists($extDbId,$dbVer);

    if ($extDbRlsId){
	Print STDERR "Not creating a new release Id for $dbName as there is already one for $dbName version $dbVer\n";
    }

    else{
        $extDbRlsId = $self->makeNewReleaseId($extDbId,$dbVer);
	print STDERR "Created new release id for $dbName with version $dbVer and release id $extDbRlsId\n";
    }
    return $extDbRlsId;
}


sub releaseAlreadyExists{
    my ($self, $extDbId,$dbVer) = @_;

    my $sql = "select external_database_release_id 
               from SRes.ExternalDatabaseRelease
               where external_database_id = $extDbId
               and version = '$dbVer'";

    my $sth = $self->prepareAndExecute($sql);
    my ($relId) = $sth->fetchrow_array();

    return $relId; #if exists, entry has already been made for this version

}


sub makeNewReleaseId{
    my ($self, $extDbId,$dbVer) = @_;

    my $newRelease = GUS::Model::SRes::ExternalDatabaseRelease->new({
	external_database_id => $extDbId,
	version => $dbVer,
	download_url => '',
	id_type => '',
	id_url => '',
	secondary_id_type => '',
	secondary_id_url => '',
	description => 'Insert NrdbXrefs',
	file_name => '',
	file_md5 => '',
	
    });

    $newRelease->submit();
    my $newReleasePk = $newRelease->getId();

    return $newReleasePk;

}

sub InsertExternalDatabase{

    my ($self,$dbName) = @_;
    my $extDbId;

    my $sql = "select external_database_id from sres.externaldatabase where lower(name) like '" . lc($dbName) ."'";
    my $sth = $self->prepareAndExecute($sql);
    $extDbId = $sth->fetchrow_array();

    if ($extDbId){
	print STEDRR "Not creating a new entry for $dbName as one already exists in the database (id $extDbId)\n";
    }

    else {
	my $newDatabase = GUS::Model::SRes::ExternalDatabase->new({
	    name => $dbName,
	   });
	$newDatabase->submit();
	$extDbId = $newDatabase->getId();
	print STEDRR "created new entry for database $dbName with primary key $extDbId\n";
    }
    return $extDbId;
}

sub getMapping {
  my ($self, $mappingFile, $tables, $extDbRlsList) = @_;

  my $lineCt = 0;

  my $cols = $self->getArg('columnSpec');


  open (XREFMAP, "$mappingFile") ||
                    die "Can't open the file $mappingFile.  Reason: $!\n"; #second scan of mapping file to process dbrefs

  while (<XREFMAP>) {
    $self->undefPointerCache(); #if at bottom, not always hit

    next if /^(\s)*$/;
    chomp;

    my @vals = split(/\t/, $_);

    my $sourceId = $vals[0];

    $sourceId =~ s/\s//g;

    my $dbAbbrev = $vals[3];

    my  %dbRef;

    $dbRef{'external_database_release_id'} = $extDbRlsList->{$dbAbbrev};

    for (my $i=0;$i<@{$cols};$i++) {
      next if (! (defined $vals[$i+1]));
      $dbRef{$cols->[$i]} = $vals[$i+1];
    }

    if($lineCt%100 == 0){
      $self->log("Processed $lineCt entries.\n");
    }

    my $tableName = "DbRefNAFeature";
    my $idColumn = $$tables{$tableName}->{idColumn};

    my $methodName = $$tables{$tableName}->{getId};
    my $method = "ApiCommonData::Load::Util::$methodName";

    my $featId = &$method($self, $sourceId);

    unless($featId){
      $self->log("Skipping: source_id '$sourceId' not found in database.");
      next;
    }


    $self->makeDbXRef($featId, \%dbRef, $idColumn, $tableName);

    $lineCt++;
  print Dumper (\%dbRef);
  }

  close (XREFMAP);

  my $msg = "Finished processing DbXRef Mapping file, number of lines: $lineCt \n";

  return $msg;
}

sub makeDbXRef {
  my ($self, $featId, $dbRef, $column, $tableName) = @_;

  my $newDbRef = GUS::Model::SRes::DbRef->new($dbRef);

  $newDbRef->submit() unless $newDbRef->retrieveFromDB();

  my $dbRefId = $newDbRef->getId();

  my $tableName = "GUS::Model::DoTS::${tableName}";
  eval "require $tableName";

  my $dbXref = $tableName->new({
				$column => $featId,
				db_ref_id => $dbRefId,
			       });

  $dbXref->submit() unless $dbXref->retrieveFromDB();

}

sub getTableParams{
  my ($self) = @_;
  my %tables;

  $tables{'DbRefNAFeature'} = ({getId => "getGeneFeatureId",
			      idColumn => "na_feature_id"});

  $tables{'DbRefAAFeature'} = ({getId => "getTranslatedAAFeatureIdFromGeneSourceId",
				idColumn => "aa_feature_id"});

  $tables{'DbRefNASequence'} = ({getId => "getNASequenceId",
				 idColumn => "na_sequence_id"});

  $tables{'AASequenceDbRef'} = ({getId => "getAASequenceId",
				 idColumn => "aa_sequence_id"});

  return \%tables;
}


sub undoTables {
  my ($self) = @_;

  return ('DoTS.DbRefNAFeature',
	  'DoTS.DbRefAAFeature',
	  'DoTS.DbRefNASequence',
	  'DoTS.AASequenceDbRef',
          'SRes.DbRef',
	  'SRes.ExternalDatabase',
	  'SRes.ExternalDatabaseRelease',
	 );
}

1;
