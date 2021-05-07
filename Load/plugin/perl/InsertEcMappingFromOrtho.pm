#^^^^^^^^^^^^^^^^^^^^^^^^^ End GUS4_STATUS ^^^^^^^^^^^^^^^^^^^^
##                 InsertEcMappingFromOrtho.pm
##
## Creates new entries in the table DoTS.AASequenceEnzymeClass to represent
## the EC mappings found in a tab delimited file of the form EC number, alias
## $Id$
##
#######################################################################

package ApiCommonData::Load::Plugin::InsertEcMappingFromOrtho;
@ISA = qw( GUS::PluginMgr::Plugin);

use strict 'vars';

use GUS::PluginMgr::Plugin;
use lib "$ENV{GUS_HOME}/lib/perl";
use FileHandle;
use Carp;
use GUS::Model::DoTS::AASequenceEnzymeClass;
use GUS::Model::SRes::EnzymeClass;
use GUS::Model::DoTS::TranslatedAAFeature;
use GUS::Model::DoTS::GeneFeature;
#use GUS::Model::DoTS::NAFeatureNaGene;
use GUS::Model::DoTS::NAGene;


my $purposeBrief = <<PURPOSEBRIEF;
Creates new entries in table DoTS.AASequenceEnzymeClass to represent new aa sequence/enzyme class associations.
PURPOSEBRIEF

my $purpose = <<PLUGIN_PURPOSE;
Takes in a tab delimited file of the order EC number, identifier, and creates new entries in table DoTS.AASequenceEnzymeClass to represent new aa sequence/enzyme class associations.  If the identifier is not the primary identifier, we will map the EC number to the primary identifier via the NAGene table, which houses gene aliases.  The mapping then will be NAGene to NAFeatureNAGene to Transcript.
PLUGIN_PURPOSE

my $tablesAffected =
	[['DoTS.AASequenceEnzymeClass', 'The entries representing the new aa_sequence/enzyme class mappings are created here']];

my $tablesDependedOn = [['SRes::EnzymeClass','The EC Numbers from the EC mapping file must have entries in this table to be considered legitimate'],['DoTS::TranslatedAAFeature','The sequences mapped to EC Numbers by the EC mapping file must have entries in this table'],['DoTS::GeneFeature','This table may contain the source ID that will be used to map from the Pfid provided by the mapping file to the entry in DoTS::TranslatedAAFeature'],['DoTS::NAFeatureNaGene','If DoTS::GeneFeature does not contain the Pfid from the mapping file as a source ID, we will need to use this table to check synonyms so that we can map the Pfid to the entry in DoTS::TranslatedAAFeature'],['DoTS::NAGene','If DoTS::GeneFeature does not contain the Pfid from the mapping file as a source ID, we will need to check this table for synonyms so that we can map the Pfid to the entry in DoTS::TranslatedAAFeature']];

my $howToRestart = <<PLUGIN_RESTART;
There is currently no restart method
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
   stringArg({name => 'aaSeqLocusTagMappingSql',
              descr => 'sql which returns aa_sequence_id(s) for a given identifier in the EC mapping file. Use a question mark as a macro for where the id should be interpolated into the sql string.  Id will most likely be a locus tag',
	      reqd => 1,
	      constraintFunc => undef,
	      isList => 0,
	     })

  ];

sub new {
    my ($class) = @_;
    my $self = {};
    bless($self,$class);

    $self->initialize({requiredDbVersion => 4.0,
		       cvsRevision => '$Revision: 24836 $', # cvs fills this in!
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
    my $evidCode = $self->getArg('evidenceCode');
    my $sql = $self->getArg('aaSeqLocusTagMappingSql');  
    $self->getAlgInvocation()->setMaximumNumberOfObjects(100000);

    my $queryHandle = $self->getQueryHandle();
    my $sth = $queryHandle->prepare($sql);

    my $abbrevs = &getOrthoAbbrevs($queryHandle);
    my %ecNumbers;
    my %aaSeqIds;

    open (ECMAP, "$mappingFile") || die "Can't open the file $mappingFile.  Reason: $!\n";
    while (my $line = <ECMAP>) {
	chomp($line);
	my @row = split('\t',$line);
	next if (scalar @row != 9);
	my ($id,$ec,$numProteinsWithEc,$numTotalProteins,$numGeneraWithEc,$numTotalGenera,$lengthScore,$blastScore,$domainScore) = @row; 

	my ($abbrev,$locusTag) = split('\|',$id);
	next if (! exists $abbrevs->{$abbrev});

	my $enzymeClass = $self->getEnzymeClass($ec, \%ecNumbers);
        next unless ($enzymeClass);

        my $aaSeqIds = $self->getAASeqIds($locusTag, \%aaSeqIds, $sth);
        next unless ($aaSeqIds);

	$self->log("Processing Pfid: $locusTag, ECNumber: $ec");
	
        foreach my $aaSeqId(@$aaSeqIds) {
	    my $newAASeqEnzClass =  GUS::Model::DoTS::AASequenceEnzymeClass->new({
		'aa_sequence_id' => $aaSeqId,
		'enzyme_class_id' => $enzymeClass,
		'evidence_code' => $evidCode,
		'num_protein_with_ec' => $numProteinsWithEc,
		'num_protein_in_group' => $numTotalProteins,
		'num_genera_with_ec' => $numGeneraWithEc,
		'num_genera_in_group' => $numTotalGenera,
		'length_score' => $lengthScore,
		'blast_score' => $blastScore,
		'domain_score' => $domainScore
                                                                               });
            if (! $newAASeqEnzClass->retrieveFromDB()) {
		$newAASeqEnzClass->submit();
		$self->log("  submitted enzyme $enzymeClass, seq $aaSeqId");
            }
	    $self->undefPointerCache();
        }
    }

    return "Finished processing EC Mapping file\n";
}

sub getOrthoAbbrevs {
    my ($queryHandle) = @_;
    my %abbrevs;
    my $sql = "SELECT orthomcl_abbrev FROM apidb.organism";
    my $sth = $queryHandle->prepare($sql);
    $sth->execute();
    while (my $abbrev = $sth->fetchrow_array()) {
	$abbrevs{$abbrev} = 1;
    }
    $sth->finish();
    return \%abbrevs;
}


###### FETCH THE EC ID FOR A GIVEN EC NUMBER ######
sub getEnzymeClass {
    my ($self, $ecNumber, $ecHash) = @_;
    if (! exists $ecHash->{$ecNumber}) {
	my $newEnzymeClass =  GUS::Model::SRes::EnzymeClass->new({
	    'ec_number' => $ecNumber
								 });
	$newEnzymeClass->retrieveFromDB();
	$ecHash->{$ecNumber} = $newEnzymeClass->getId();
    }
    return $ecHash->{$ecNumber};
}

###### FETCH THE AA SEQUNCE ID FOR A GIVEN ALIAS ######
sub getAASeqIds {
    my ($self, $locusTag, $aaSeqIdsHash, $sth) = @_;
    if (! exists $aaSeqIdsHash->{$locusTag}){
	$sth->execute($locusTag);
	while (my $aaSequenceId = $sth->fetchrow_array()) {
	    $aaSeqIdsHash->{$locusTag} = &addArrayElement($aaSeqIdsHash->{$locusTag}, $aaSequenceId);
	}
	$sth->finish();
    }
    return $aaSeqIdsHash->{$locusTag};
}

sub addArrayElement {
    my ($arrayRef,$element) = @_;
    if (defined $arrayRef) {
	push @{$arrayRef}, $element;
    } else {
	$arrayRef = [$element];
    }
    return $arrayRef;
}

sub undoTables {
  my ($self) = @_;

  return ('DoTS.AASequenceEnzymeClass');
}

1;
