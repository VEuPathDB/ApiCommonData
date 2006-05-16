#######################################################################
##                 InsertDBxRefs.pm
##
## Creates new entries in the tables SRes.DbRef and DoTS.DbRefNAFeature
## to represent mappings to external resources that are found in a tab
## delimited file of the form gene_id, DbRef_pk, DbRef remark
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


my $purposeBrief = <<PURPOSEBRIEF;
Creates new entries in tables SRes.DbRef and DoTS.DbRefNAFeature to represent new DBxRef associations with NAFeature.
PURPOSEBRIEF

my $purpose = <<PLUGIN_PURPOSE;
Takes in a tab delimited file and creates new entries in tables SRes.DbRef, DoTS.DbRefNAFeature to represent new DbRef/NAFeature class associations.
NOTE: If there are only three columns in the input file, the third column can either be loaded into SRes.DbRef.remark or SRes.DbRef.lowercase_secondary_identifier, depending on whether the loadRemarks flag is set or not.
HACK: We are loading the map name into
SRes.DbRef.lowercase_secondary_identifier until we can fix GUS b/c
SRes.DbRef.secondary_identifier is too short
PLUGIN_PURPOSE

my $tablesAffected =
	[['SRes.DbRef', 'The entries representing the new links to the external datasets will go here.'],['DoTS.DbRefNAFeature', 'The entries representing the new DbRef/NAFeature class mappings are created here.']];

my $tablesDependedOn = [['DoTS.NAFeature', 'The genes to be linked to external datasets are found here.'],['DoTS.NAGene','If the gene id is not found in DoTS.NAFeature, this table will be checked in case the gene id is an alias.']];

my $howToRestart = <<PLUGIN_RESTART;
There is currently no restart method.
PLUGIN_RESTART

my $failureCases = <<PLUGIN_FAILURE_CASES;
There are no known failure cases.
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
   booleanArg ({name => 'loadRemarks',
	              descr => 'Set this to load the third column of a three column file into Sres.DbRef.remark instead of Sres.DbRef.lowercase_secondary_identifier.',
	              reqd => 0,
                      default =>0
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

  my $msg = $self->getMapping($mappingFile);

  return $msg;

}

sub getMapping {
  my ($self, $mappingFile) = @_;

  my $lineCt = 0;

  my $dbRls = $self->getExtDbRlsId($self->getArg('extDbName'),
                                     $self->getArg('extDbReleaseNumber'))
      || die "Couldn't retrieve external database!\n";

  open (XREFMAP, "$mappingFile") ||
                    die "Can't open the file $mappingFile.  Reason: $!\n";

    while (<XREFMAP>) {
	chomp;
	my ($locusTag, $primaryId, $secondaryId, $remark) = split('\t', $_);

	if (!$primaryId || !$locusTag){
	  $self->log("Missing a required field. primaryId: $primaryId, locusTag: $locusTag.");
	  next;
	}

	if ($self->getArg('loadRemarks')){
	  $remark = $secondaryId;
	  $secondaryId = "";
	}

	$locusTag =~ s/\s//g;
	$primaryId =~ s/\s//g;

	if($lineCt%100 == 0){
	  $self->log("Processed $lineCt entries.\n");
	}

	$self->makeDbXRef($locusTag, $primaryId, $secondaryId, $remark, $dbRls);

	$self->undefPointerCache();

        $lineCt++;
      }

close (XREFMAP);

  my $msg = "Finished processing DbXRef Mapping file, number of lines: $lineCt \n";

  return $msg;
}

sub makeDbXRef {
  my ($self, $locusTag, $primaryId, $secondaryId, $remark, $dbRls) = @_;

  my $dbRef = GUS::Model::SRes::DbRef->new({ primary_identifier => $primaryId,
					     lowercase_secondary_identifier => $secondaryId,
					     remark => $remark,
					     external_database_release_id => $dbRls,
					   });

    $dbRef->submit() unless $dbRef->retrieveFromDB();


  my $dbRefId = $dbRef->getId();

  my $naFeatId = ApiCommonData::Load::Util::getGeneFeatureId($self, $locusTag);

  unless($naFeatId){
    $self->log("Skipping: source_id $locusTag not found in database.");
    next;
  }

  my $dbXref = GUS::Model::DoTS::DbRefNAFeature->new({
						    na_feature_id => $naFeatId,
						    db_ref_id => $dbRefId,
						    });

  $dbXref->submit() unless $dbXref->retrieveFromDB();

}

sub undoTables {
  my ($self) = @_;

  return ('DoTS.DbRefNAFeature',
          'SRes.DbRef',
	 );
}



1;
