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
use GUS::Model::DoTS::DbRefAAFeature;


my $purposeBrief = <<PURPOSEBRIEF;
Creates new entries in tables SRes.DbRef and DoTS.DbRefNAFeature to represent new DBxRef associations with NAFeature.
PURPOSEBRIEF

my $purpose = <<PLUGIN_PURPOSE;
Takes in a tab delimited file and creates new entries in tables SRes.DbRef, DoTS.DbRefNAFeature to represent new DbRef/NAFeature class associations.
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
   stringArg ({name => 'columnSpec',
	       descr => 'Comma delimited list specifying the correspondence of the file columns to the columns in sres.dbref starting with the second column of the file.Ex secondary_identifier,primary_identifier,remark for input line = PB402242        68056705        XP_670763.1     hypothetical protein',
	       reqd => 1,
               constraintFunc => undef,
               isList=> 1
              }),
   enumArg({name => 'SequenceType',
	    descr => 'The type of sequence we are loading DBxRefs for.  Default is NA.',
	    constraintFunc=> undef,
	    reqd  => 0,
	    isList => 0,
	    enum => "AA,NA",
	    default => "NA",
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

  my $cols = $self->getArg('columnSpec');



  open (XREFMAP, "$mappingFile") ||
                    die "Can't open the file $mappingFile.  Reason: $!\n";

  while (<XREFMAP>) {
    $self->undefPointerCache(); #if at bottom, not always hit
    chomp;

    my @vals = split(/\t/, $_);

    my $feature = $vals[0];

    $feature =~ s/\s//g;

    my  %dbRef;

    $dbRef{'external_database_release_id'} = $dbRls;

    for (my $i=0;$i<@{$cols};$i++) {
      next if (! (defined $vals[$i+1]));
      $dbRef{$cols->[$i]} = $vals[$i+1];
    }

    if($lineCt%100 == 0){
      $self->log("Processed $lineCt entries.\n");
    }

    my $featId;
    my $type = $self->getArg('SequenceType');

    if($type eq "NA"){

      $featId = ApiCommonData::Load::Util::getGeneFeatureId($self, $feature);

    }elsif($type eq "AA"){

      $featId = ApiCommonData::Load::Util::getAAFeatureId($self, $feature);

    }else{
      die "$type is not a valid sequence type.  Please use one of AA or NA.";
    }

    unless($featId){
      $self->log("Skipping: source_id $feature not found in database.");
      next;
    }


    $self->makeDbXRef($featId, \%dbRef, $type);

    $lineCt++;
  }

  close (XREFMAP);

  my $msg = "Finished processing DbXRef Mapping file, number of lines: $lineCt \n";

  return $msg;
}

sub makeDbXRef {
  my ($self, $featId, $dbRef, $type) = @_;

  my $newDbRef = GUS::Model::SRes::DbRef->new($dbRef);

  $newDbRef->submit() unless $newDbRef->retrieveFromDB();

  my $dbRefId = $newDbRef->getId();

  my $tableName = "GUS::Model::DoTS::DbRef${type}Feature";

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
          'SRes.DbRef',
	 );
}



1;
