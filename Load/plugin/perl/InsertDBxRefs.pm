######################################################################
#vvvvvvvvvvvvvvvvvvvvvvvvv GUS4_STATUS vvvvvvvvvvvvvvvvvvvvvvvvv
  # GUS4_STATUS | SRes.OntologyTerm              | auto   | absent
  # GUS4_STATUS | SRes.SequenceOntology          | auto   | absent
  # GUS4_STATUS | Study.OntologyEntry            | auto   | absent
  # GUS4_STATUS | SRes.GOTerm                    | auto   | absent
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
  # GUS4_STATUS | dots.gene                      | manual | absent
#^^^^^^^^^^^^^^^^^^^^^^^^^ End GUS4_STATUS ^^^^^^^^^^^^^^^^^^^^
######################################################################
##                 InsertDBxRefs.pm
##
## Creates new entries in the tables SRes.DbRef and DoTS.DbRefNAFeature
## ,DoTS.DbRefAAFeature,DoTS.DbRefNASequence, or DoTS.AASequenceDbRef  to represent
## mappings to external resources that are found in a tab delimited
## file with the first column being source_id of the DoTS.NAFeature, DoTS.AAFeature,
## DoTS.NASequence, or DoTS.AASequence tables, followed by values taht will be mapoped 
##to columns in the SRES.DbRef table
## 
##
#######################################################################

package ApiCommonData::Load::Plugin::InsertDBxRefs;
@ISA = qw( GUS::PluginMgr::Plugin);


use strict 'vars';

use GUS::PluginMgr::Plugin;
use lib "$ENV{GUS_HOME}/lib/perl";
use FileHandle;
use Carp;
use GUS::Supported::Util;
use GUS::Model::SRes::DbRef;
use GUS::Model::SRes::ExternalDatabaseRelease;
use GUS::Model::DoTS::GeneFeature;
use GUS::Model::DoTS::Transcript;
use GUS::Model::DoTS::DbRefNAFeature;
use GUS::Model::DoTS::DbRefAAFeature;
use GUS::Model::DoTS::DbRefNASequence;
use GUS::Model::DoTS::AASequenceDbRef;
use GUS::Model::SRes::ExternalDatabase;

my $purposeBrief = <<PURPOSEBRIEF;
Creates new entries in tables SRes.DbRef and DoTS.DbRefNAFeature, DoTS.DbRefAAFeature, DoTS.DbRefNASequence, or DoTS.AASequenceDbRef to represent new DBxRef associations with NAFeature, AAFeature, NASequence, or AASequence.
PURPOSEBRIEF

my $purpose = <<PLUGIN_PURPOSE;
Takes in a tab delimited file and creates new entries in tables SRes.DbRef, DoTS.DbRefNAFeature, DoTS.DbRefAAFeature, DoTS.DbRefNASequence, or DoTs.AASequenceDbRef to represent new DbRef/NAFeature/AAFeature/NASequence/AASequence class associations.
PLUGIN_PURPOSE

my $tablesAffected =
	[['SRes.DbRef', 'The entries representing the new links to the external datasets will go here.'],['DoTS.DbRefNAFeature', 'The entries representing the new DbRef/NAFeature class mappings are created here.'],['DoTS.DbRefAAFeature','The entries representing the new DbRef/AAFeature class mappings are created here.'],['DoTS.DbRefNASequence','The entries representing the new DbRef/NASequence class mappings are created here.'],['DoTS.AASequenceDbRef','The entries representing the new DbRef/AASequence class mappings are created here.']];

my $tablesDependedOn = [['DoTS.NAFeature', 'The genes to be linked to external datasets are found here.'],['DoTS.NAGene','If the gene id is not found in DoTS.NAFeature, this table will be checked in case the gene id is an alias.'],['DoTS.AAFeature','The aa features to be linked to external databasets are found here.'],['DoTS.AASequence','The aa sequences to be linked to external database will be found here.'],['Dots.ExternalNASequence','The NA sequence to be linked to externaldatabases may be found here'],['DoTS.VirtualSequence','This table is checked if the NA sequence is not found in DoTS.ExternalNASequence.']];

my $howToRestart = <<PLUGIN_RESTART;
There is currently no restart method.
PLUGIN_RESTART

my $failureCases = <<PLUGIN_FAILURE_CASES;
1. If the AA feature you are trying to map to is not in the TranslatedAAFeature table, this plugin will fail to find the feature id and will not load the DBxRef.
2. If the NA sequence you are trying to map to is not in the ExternalNASequence table or the VirtualSequence table, this plugin will fail to find the sequence id and will not load the DBxRef.
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
	  descr => 'pathname for the file containing the DbRef mapping data',
	  constraintFunc => undef,
	  reqd => 1,
	  isList => 0,
	  mustExist => 1,
	  format => 'Three or four column tab delimited file: feature source_id, dbref primary_identifier, dbref lowercase_secondary_identifier (opt.), dbref remark'
        }),
   stringArg({name => 'extDbName',
	      descr => 'the external database name with which to load the DBRefs.',
	      reqd => 1,
	      constraintFunc => undef,
	      isList => 0,
	     }),
   stringArg({name => 'extDbReleaseNumber',
	      descr => 'the version of the external database with which to load the DBRefs',
	      reqd => 1,
	      constraintFunc => undef,
	      isList => 0,
	     }),
   stringArg({name => 'geneExternalDatabaseSpec',
	      descr => 'External Database release `name1|version1,name2|version2` for the gene models to which will be attaching these DBRefs.',
	      reqd => 0,
	      constraintFunc => undef,
	      isList => 0,
	     }),
   stringArg ({name => 'columnSpec',
	       descr => 'Comma delimited list specifying the correspondence of the file columns to the columns in sres.dbref starting with the second column of the file.Ex secondary_identifier,primary_identifier,remark for input line = PB402242        68056705        XP_670763.1     hypothetical protein',
	       reqd => 1,
               constraintFunc => undef,
               isList=> 1
              }),


   stringArg({name => 'idURL',
	      descr => 'the URL for external dabase links',
	      reqd => 0,
	      constraintFunc => undef,
	      isList => 0,
	     }),

   stringArg({name => 'idType',
	      descr => 'the identifier type for external database links',
	      reqd => 0,
	      constraintFunc => undef,
	      isList => 0,
	     }),

   stringArg({name => 'organismAbbrev',
	      descr => 'if supplied, check if the alias used for gene source_id or alias in other organisms',
	      reqd => 0,
	      constraintFunc => undef,
	      isList => 0,
	     }),

   enumArg({name => 'tableName',
	    descr => 'The name of the mapping table that links the sres.dbref to the sequence or feature table. The default table for this plugin is "DoTS.DbRefNAFeature".  Note: If loading AAFeatures, then the provided source_ids must be AA source_ids not gene source_ids',
	    constraintFunc=> undef,
	    reqd  => 1,
	    isList => 0,
	    enum => "DbRefNAFeature,DbRefNASequence,DbRefAAFeature,AASequenceDbRef",
	   }),
   enumArg({name => 'viewName',
	    descr => 'The subclass_view of the table ',
	    constraintFunc=> undef,
	    reqd  => 1,
	    isList => 0,
	    enum => "GeneFeature,Transcript,TranslatedAAFeature,ExternalAASequence,TranslatedAASequence,ExternalNASequence,VirtualSequence",
	   }),

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

sub run {
  my ($self) = @_;

  my $mappingFile = $self->getArg('DbRefMappingFile');

  my $viewName = $self->getArg('viewName');

  my $tables = $self->getTableParams($viewName);

  my $msg = $self->getMapping($mappingFile, $tables);

  return $msg;

}

sub getMapping {
  my ($self, $mappingFile, $tables) = @_;

  my $lineCt = 0;

  my $dbRls = $self->getExtDbRlsId($self->getArg('extDbName'),
                                     $self->getArg('extDbReleaseNumber'))
      || die "Couldn't retrieve external database!\n";

  my $geneExtDbRlsId;
  $geneExtDbRlsId = join ',', map{$self->getExtDbRlsId($_)} split (/,/,$self->getArg('geneExternalDatabaseSpec')) if $self->getArg('geneExternalDatabaseSpec');

  my $cols = $self->getArg('columnSpec');

  if ($self->getArg('idURL')){
      my $url=$self->getArg('idURL');

      $self->updateIdURL($dbRls,$url);
  }

  if ($self->getArg('idType')){
      my $idType=$self->getArg('idType');

      $self->updateIdType($dbRls,$idType);
  }

  my $viewName = $self->getArg('viewName'); 


  open (XREFMAP, "$mappingFile") ||
                    die "Can't open the file $mappingFile.  Reason: $!\n";

  while (<XREFMAP>) {
    $self->undefPointerCache(); #if at bottom, not always hit

    next if /^(\s)*$/;
    chomp;

    my @vals = split(/\t/, $_);

    my $sourceId = $vals[0];

    $sourceId =~ s/\s//g;

    my  %dbRef;

    $dbRef{'external_database_release_id'} = $dbRls;

    ## skip the mapping if the alias is a source_id of DoTS::GeneFeature view
    if ($self->getArg('extDbName') =~ /aliases/i) {
      $vals[1] =~ s/^\s+//;
      $vals[1] =~ s/\s+$//;
      my $checkGeneFeature = GUS::Model::DoTS::GeneFeature->new({source_id => $vals[1]});
      if ($checkGeneFeature->retrieveFromDB() ) {
	$self->log("Skipping: $vals[1] to $sourceId mapping since it is a source_id in geneFeature view.\n");
	next;
      }
    }

    for (my $i=0;$i<@{$cols};$i++) {
      next if (! (defined $vals[$i+1]));
      $vals[$i+1] =~ s/^\s+//;
      $vals[$i+1] =~ s/\s+$//;
      $dbRef{$cols->[$i]} = $vals[$i+1];
=begin comment
      ## check if duplicated aliases
      if ($self->getArg('organismAbbrev') && $cols->[$i] eq 'primary_identifier' && $self->getArg('extDbName') =~ /aliases/i && $self->getArg('tableName') =~ /NAFeature/i ) {

	## check the source_id in the dots.genefeature view
	my $geneFeatureTableCheck = GUS::Model::DoTS::GeneFeature->new({source_id => $vals[$i+1]});
	if ( $geneFeatureTableCheck->retrieveFromDB()) {
	  my $dupGeneExtRls = $geneFeatureTableCheck->getExternalDatabaseReleaseId;
	  my $dupExtRlsTable = GUS::Model::SRes::ExternalDatabaseRelease->new({external_database_release_id=>$dupGeneExtRls});
	  my $dupExtDbId = $dupExtRlsTable->getExternalDatabaseId if ($dupExtRlsTable->retrieveFromDB() );
	  my $dupExtDbTable = GUS::Model::SRes::ExternalDatabase->new({external_database_id=>$dupExtDbId});
	  my $dupName = $dupExtDbTable->getName if ($dupExtDbTable->retrieveFromDB());
	  my $dupOrganism = $dupName;
	  $dupOrganism =~ s/(\S+?)\_.*/$1/;

	  $self->log("WARNING .... check the aliases mapping file...\nThe alias $vals[$i+1] for $sourceId is a genefeature source_id belongs to $dupOrganism\n");
	}

	## check the primary_identifier in the sres.dbref table
	my $dbrefTableCheck = GUS::Model::SRes::DbRef->new({primary_identifier => $vals[$i+1]});
        if ( $dbrefTableCheck->retrieveFromDB()){
	  my $DupDbRefId = $dbrefTableCheck->getDbRefId;
	  my $DupDbRefIdCheck = GUS::Model::SRes::ExternalDatabaseRelease->new({external_database_release_id => $dbrefTableCheck->getExternalDatabaseReleaseId });
	  my $DupIdType = $DupDbRefIdCheck->getIdType if ($DupDbRefIdCheck->retrieveFromDB());
	  if ($DupIdType eq 'previous id' || $DupIdType eq 'alternate id') {
	    my $dupDbrefNaFeatTable = GUS::Model::DoTS::DbRefNAFeature->new({db_ref_id=>$DupDbRefId});
	    my $dupNaFeatureId = $dupDbrefNaFeatTable->getNaFeatureId if($dupDbrefNaFeatTable->retrieveFromDB());
	    my $dupGeneFeatTable = GUS::Model::DoTS::GeneFeature->new({na_feature_id=>$dupNaFeatureId});
	    my $dupGene = $dupGeneFeatTable->getSourceId if ($dupGeneFeatTable->retrieveFromDB() );
	    my $dupExtDbRlsId = $dupGeneFeatTable->getExternalDatabaseReleaseId if ($dupGeneFeatTable->retrieveFromDB());
	    my $dupExtDbRlsTable = GUS::Model::SRes::ExternalDatabaseRelease->new({external_database_release_id=>$dupExtDbRlsId});
	    my $dupExtDbId = $dupExtDbRlsTable->getExternalDatabaseId if ($dupExtDbRlsTable->retrieveFromDB());
	    my $dupExtDbTable = GUS::Model::SRes::ExternalDatabase->new({external_database_id=>$dupExtDbId});
	    my $dupName = $dupExtDbTable->getName if ($dupExtDbTable->retrieveFromDB() );
	    my $dupOrganism = $dupName;
	    $dupOrganism =~ s/(\S+?)\_.*/$1/;
	    if ($dupOrganism ne $self->getArg('organismAbbrev') ) {
	      $self->log("WARNING .... check the aliases mapping file...\nThe alias $vals[$i+1] for $sourceId already exits in the sres.dbref with db_ref_id $DupDbRefId for the gene $dupGene belongs to $dupOrganism\n");
	    }
	  }
	}
      }
=end comment
=cut
    }

    if($lineCt%100 == 0){
      $self->log("Processed $lineCt entries.\n");
    }

    my $tableName = $self->getArg('tableName');
    my $idColumn = $$tables{$tableName}->{idColumn};

    my $methodName = $$tables{$tableName}->{getId};
    my $method = "GUS::Supported::Util::$methodName";
    my $featId;

    ###comment out this part because it caused failures when "viewName" is "Transcript"
    #if ($self->getArg('organismAbbrev')){

    #	$featId = &$method($self, $sourceId, $geneExtDbRlsId, $self->getArg('organismAbbrev'));
    #}

    if($viewName eq 'Transcript'){
      $featId = &$method($self, $sourceId, $viewName);
    }
    elsif($viewName eq 'GeneFeature'){

      $featId = &$method($self, $sourceId, $geneExtDbRlsId);
    }
    else{
      $featId = &$method($self, $sourceId);
    }
unless ($featId) {
      $self->log("Skipping: source_id '$sourceId' not found in database.");
      next;
};
unless (ref $featId eq 'ARRAY'){
$featId = [$featId];
}
    if(scalar @{$featId} < 1){
      $self->log("Skipping: source_id '$sourceId' not found in database.");
      next;
    }


    $self->makeDbXRef($featId, \%dbRef, $idColumn, $tableName);

    $lineCt++;
  }

  close (XREFMAP);

  my $msg = "Finished processing DbXRef Mapping file, number of lines: $lineCt \n";

  return $msg;
}

sub makeDbXRef {
  my ($self, $featIdList, $dbRef, $column, $tableName) = @_;

  my $newDbRef = GUS::Model::SRes::DbRef->new($dbRef);

  $newDbRef->submit() unless $newDbRef->retrieveFromDB();

  my $dbRefId = $newDbRef->getId();

  my $tableName = "GUS::Model::DoTS::${tableName}";
  eval "require $tableName";
  foreach my $featId (@$featIdList) {
      my $dbXref = $tableName->new({
                   $column => $featId,
                   db_ref_id => $dbRefId,
                   });
  $dbXref->submit() unless $dbXref->retrieveFromDB();
 }
}

sub getTableParams{
  my ($self, $viewName) = @_;
  my %tables;

  if ($viewName eq "GeneFeature"){
    $tables{'DbRefNAFeature'} = ({getId => "getGeneFeatureId",
                                  idColumn => "na_feature_id"});
    $tables{'DbRefAAFeature'} = ({getId => "getTranslatedAAFeatureIdListFromGeneSourceId",
				                  idColumn => "aa_feature_id"});
  }
  if ($viewName eq "Transcript"){
    $tables{'DbRefNAFeature'} = ({getId => "getNaFeatureIdsFromSourceId",
                                  idColumn => "na_feature_id"});
  }

  if ($viewName eq "TranslatedAAFeature"){  
    $tables{'DbRefAAFeature'} = ({getId => "getAAFeatureId",
                idColumn => "aa_feature_id"});
  }

  $tables{'DbRefNASequence'} = ({getId => "getNASequenceId",
                 idColumn => "na_sequence_id"});

  $tables{'AASequenceDbRef'} = ({getId => "getAASequenceId",
                 idColumn => "aa_sequence_id"});

  return \%tables;
}

sub updateIdURL{
  my ($self,$dbRls,$url) = @_;

  my $DbRlsObj = GUS::Model::SRes::ExternalDatabaseRelease-> new({external_database_release_id => $dbRls});

  $DbRlsObj -> retrieveFromDB();
 
  $DbRlsObj -> setIdUrl($url); 

  $DbRlsObj->submit();

}

sub updateIdType{
  my ($self,$dbRls,$idType) = @_;

  my $DbRlsObj = GUS::Model::SRes::ExternalDatabaseRelease-> new({external_database_release_id => $dbRls});

  $DbRlsObj -> retrieveFromDB();
 
  $DbRlsObj -> set("id_type",$idType); 

  $DbRlsObj->submit();

}
sub undoTables {
  my ($self) = @_;

  return ('DoTS.DbRefNAFeature',
	  'DoTS.DbRefAAFeature',
	  'DoTS.DbRefNASequence',
	  'DoTS.AASequenceDbRef',
          'SRes.DbRef',
	 );
}

1;
