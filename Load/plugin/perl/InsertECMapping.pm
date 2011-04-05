#######################################################################
##                 InsertECMapping.pm
##
## Creates new entries in the table DoTS.AASequenceEnzymeClass to represent
## the EC mappings found in a tab delimited file of the form EC number, alias
## $Id$
##
#######################################################################
 
package ApiCommonData::Load::Plugin::InsertECMapping;
@ISA = qw( GUS::PluginMgr::Plugin);

use strict 'vars';

use GUS::PluginMgr::Plugin;
use lib "$ENV{GUS_HOME}/lib/perl";
use FileHandle;
use Carp;
use ApiCommonData::Load::Utility::ECAnnotater;
use ApiCommonData::Load::Util;


my $purposeBrief = <<PURPOSEBRIEF;
Creates new entries in table DoTS.AASequenceEnzymeClass to represent new aa sequence/enzyme class associations.
PURPOSEBRIEF

my $purpose = <<PLUGIN_PURPOSE;
Takes in a tab delimited file of the order identifier, EC number and creates new entries in table DoTS.AASequenceEnzymeClass to represent new aa 
sequence/enzyme 
class associations.  (Lost Functionality = If the identifier is not the primary identifier, we will map the EC number to the primary identifier via the NAGene table, which houses gene aliases.  The mapping then will be NAGene to NAFeatureNAGene to Transcript.)
PLUGIN_PURPOSE

my $tablesAffected =
	[['DoTS.AASequenceEnzymeClass', 'The entries representing the new aa_sequence/enzyme class mappings are created here']];

my $tablesDependedOn = [[ ]];

my $howToRestart = <<PLUGIN_RESTART;
There is currently no restart method (The ECAnnotater object checks for duplicates and will not resubmit existing entries, so restart can just be restarting the run from the beginning of the file.)
PLUGIN_RESTART

my $failureCases = <<PLUGIN_FAILURE_CASES;
There are no known failure cases
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
   fileArg({name => 'ECMappingFile',
	  descr => 'pathname for the file containing the EC mapping data',
	  constraintFunc => undef,
	  reqd => 1,
	  isList => 0,
	  mustExist => 1,
	  format => 'Two column tab delimited file in the order EC number, identifier'
        }),
   stringArg({name => 'evidenceCode',
	      descr => 'the evidence code with which data should be entered into the AASequenceEnzymeClass table',
	      reqd => 1,
	      constraintFunc => undef,
	      isList => 0,
	     }),
   stringArg({name => 'ECDbName',
	      descr => 'the name of the Enzyme database in SRes.ExternalDatabase',
	      reqd => 1,
	      constraintFunc => undef,
	      isList => 0,
	     }),
   stringArg({name => 'ECReleaseNumber',
	      descr => 'the version of the Enzyme database in SRes.ExternalDatabaseRelease',
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
		       cvsRevision => '$Revision: 3951 $', # cvs fills this in!
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
  my $mappingFile = $self->getArg('ECMappingFile');

  my $msg = $self->getMapping($mappingFile);

  return $msg;
}

sub getMapping {
  my ($self, $mappingFile) = @_;

  my $lineCt = 0;

  my $evidenceDescription = $self->getArg('evidenceCode');

  my $dbRls = $self->getExtDbRlsId($self->getArg('ECDbName'),
                                     $self->getArg('ECReleaseNumber'))
      || die "Couldn't retrieve external database!\n";


  my $annotater = ApiCommonData::Load::Utility::ECAnnotater->new();

  open (ECMAP, "$mappingFile") ||
                    die ("Can't open the file $mappingFile.  Reason: $!\n");

    while (<ECMAP>) {
	chomp;
	my ($locusTag, $ecNumber) = split('\t', $_);

	if (!$ecNumber || !$locusTag){
	  next;
	}

	$locusTag =~ s/\s//g;
	$ecNumber =~ s/\s//g;

	$self->log("Processing Pfid: $locusTag, ECNumber: $ecNumber\n");

        my $aaSeq = 
	  ApiCommonData::Load::Util::getAASeqIdFromGeneId($self, $locusTag);
        my $ecAssociation = {
                    'ecNumber' => $ecNumber,
                    'evidenceDescription' => $evidenceDescription,
                    'releaseId' => $dbRls,
                    'sequenceId' => $aaSeq,
                              };
        $annotater->addEnzymeClassAssociation($ecAssociation);
      
        $lineCt++;
      }

  my $msg = "Finished processing EC Mapping file, number of lines: $lineCt \n";

  return $msg;
}


1;

