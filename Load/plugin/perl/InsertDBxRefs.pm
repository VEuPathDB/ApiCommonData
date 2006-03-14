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
Takes in a tab delimited file of the order gene identifier, external database link identifier, and external database remark, and creates new entries in tables SRes.DbRef, DoTS.DbRefNAFeature to represent new DbRef/NAFeature class associations.
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
	  format => 'Three column tab delimited file in the order gene_id, DbRef_pk, DbRef_remark'
        }),
   stringArg({name => 'NAFeatureDbName',
	      descr => 'the external database name in SRes.ExternalDatabase that the NAFeatures were loaded with.',
	      reqd => 1,
	      constraintFunc => undef,
	      isList => 0,
	     }),
   stringArg({name => 'NAFeatureReleaseNumber',
	      descr => 'the version of the external database in SRes.ExternalDatabaseRelease that the NAFeatures were loaded with',
	      reqd => 1,
	      constraintFunc => undef,
	      isList => 0,
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

  my $dbRls = $self->getExtDbRlsId($self->getArg('NAFeatureDbName'),
                                     $self->getArg('NAFeatureReleaseNumber'))
      || die "Couldn't retrieve external database!\n";

print "db release = $dbRls\n";
  open (XREFMAP, "$mappingFile") ||
                    die "Can't open the file $mappingFile.  Reason: $!\n";

    while (<XREFMAP>) {
	chomp;
	my ($locusTag, $dbRef, $remark) = split('\t', $_);
	print "source ID = $locusTag, dbRef = $dbRef, remarks = $remark \n";
	if (!$dbRef || !$locusTag){
	  $self->log("Missing a required field. dbRef: $dbRef, locusTag: $locusTag.");
	  next;
	}

	$locusTag =~ s/\s//g;
	$dbRef =~ s/\s//g;

	if($lineCt%100 == 0){
	  $self->log("Processed $lineCt entries.\n");
	}

	$self->makeDbXRef($locusTag, $dbRef, $remark, $dbRls);

        $lineCt++;
      }

close (XREFMAP);

  my $msg = "Finished processing DbXRef Mapping file, number of lines: $lineCt \n";

  return $msg;
}

sub makeDbXRef {
  my ($self, $locusTag, $dbRef, $remark, $dbRls) = @_;

  my $dbRef = GUS::Model::SRes::DbRef->new({ primary_identifier => $dbRef,
					     remark => $remark,
					     external_database_release_id => $dbRls,
					   });

  unless ($dbRef->retrieveFromDB()) {
print "submitting dbRef $dbRef->{'primary_identifier'}\n";
    $dbRef->submit();
  }

  my $dbRefId = $dbRef->getId();

print "New ID: $dbRefId\n";

  my $naFeatId = ApiCommonData::Load::Util::getGeneFeatureId($self, $locusTag);
print "NAFeatID: $naFeatId\n";
  my $dbXref = GUS::Model::DoTS::DbRefNAFeature->new({
						    na_feature_id => $naFeatId,
						    db_ref_id => $dbRefId,
						    });

  $dbXref->submit();
print "submitted new mapping\n";
}

1;
