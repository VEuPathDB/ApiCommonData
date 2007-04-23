#######################################################################
##                 InsertDBxRefs.pm
##
## Creates new entries in the tables SRes.DbRef and DoTS.DbRefNAFeature
## or DoTS.DbRefAAFeature (a non-standard GUS table) to represent
## mappings to external resources that are found in a tab delimited
## file of the form gene_id, DbRef_pk, DbRef remark
## $Id$
##
#######################################################################

package ApiCommonData::Load::Plugin::InsertDBxRefs;
@ISA = qw( GUS::PluginMgr::Plugin);

use strict 'vars';

use GUS::PluginMgr::Plugin;
use lib "$ENV{GUS_HOME}/lib/perl";
use FileHandle;
use Carp;
use ApiCommonData::Load::Util;
use GUS::Model::SRes::DbRef;
use GUS::Model::DoTS::DbRefNAFeature;
use GUS::Model::DoTS::DbRefAAFeature;


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
   stringArg ({name => 'columnSpec',
	       descr => 'Comma delimited list specifying the correspondence of the file columns to the columns in sres.dbref starting with the second column of the file.Ex secondary_identifier,primary_identifier,remark for input line = PB402242        68056705        XP_670763.1     hypothetical protein',
	       reqd => 1,
               constraintFunc => undef,
               isList=> 1
              }),
   enumArg({name => 'tableName',
	    descr => 'The name of the mapping table for the sequences we are loading DBxRefs for. The default table for this plugin is "DoTS.DbRefNAFeature".  Note: If loading AAFeatures, then the provided source_ids must be AA source_ids not gene source_ids',
	    constraintFunc=> undef,
	    reqd  => 0,
	    isList => 0,
	    enum => "DbRefNAFeature,DbRefNASequence,DbRefAAFeature,AASequenceDbRef",
	    default => "DbRefNAFeature",
	   }),

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

sub run {
  my ($self) = @_;

  my $mappingFile = $self->getArg('DbRefMappingFile');

  my $tables = getTableParams();

  my $msg = $self->getMapping($mappingFile, $tables);

  return $msg;

}

sub getMapping {
  my ($self, $mappingFile, $tables) = @_;

  my $lineCt = 0;

  my $dbRls = $self->getExtDbRlsId($self->getArg('extDbName'),
                                     $self->getArg('extDbReleaseNumber'))
      || die "Couldn't retrieve external database!\n";

  my $cols = $self->getArg('columnSpec');



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

    for (my $i=0;$i<@{$cols};$i++) {
      next if (! (defined $vals[$i+1]));
      $dbRef{$cols->[$i]} = $vals[$i+1];
    }

    if($lineCt%100 == 0){
      $self->log("Processed $lineCt entries.\n");
    }

    my $tableName = $self->getArg('tableName');
    my $getter = $$tables{$tableName}->{getId};
    my $type = $$tables{$tableName}->{type};

print "GETTER: $getter\n";

#    my $featId = $getter($self, $sourceId);

#    unless($featId){
#      $self->log("Skipping: source_id '$sourceId' not found in database.");
#      next;
#    }


#    $self->makeDbXRef($featId, \%dbRef, $type, $tableName);

    $lineCt++;
  }

  close (XREFMAP);

  my $msg = "Finished processing DbXRef Mapping file, number of lines: $lineCt \n";

  return $msg;
}

sub makeDbXRef {
  my ($self, $featId, $dbRef, $type, $tableName) = @_;

  my $newDbRef = GUS::Model::SRes::DbRef->new($dbRef);

  $newDbRef->submit() unless $newDbRef->retrieveFromDB();

  my $dbRefId = $newDbRef->getId();

  my $tableName = "GUS::Model::DoTS::${tableName}";

  my $column = lc($type);
  $column = "${type}_feature_id";

  my $dbXref = $tableName->new({
				$column => $featId,
				db_ref_id => $dbRefId,
			       });

  $dbXref->submit() unless $dbXref->retrieveFromDB();

}

sub undoTables {
  my ($self) = @_;

  return ('DoTS.DbRefNAFeature',
	  'DoTS.DbRefAAFeature',
          'SRes.DbRef',
	 );
}

sub getTableParams{
  my ($self) = @_;
  my %tables;

  $tables{'DbRefNAFeature'} = ({getId => "ApiCommonData::Load::Util::getGeneFeatureId",
			      type => "NA"});

  $tables{'DbRefAAFeature'} = ({getId => "ApiCommonData::Load::Util::getTranslatedAAFeatureIdFromGeneSourceId",
				type => "AA"});

  $tables{'DbRefNASequence'} = ({getId => "ApiCommonData::Load::Util::getNASequenceId",
				 type => "NA"});

  $tables{'DbRefAASequence'} = ({getId => "ApiCommonData::Load::Util::getAASequenceId",
				 type => "AA"});

  return \%tables;
}

1;
