package ApiCommonData::Load::Plugin::InsertGeneProfileCorrelation;

@ISA = qw(GUS::PluginMgr::Plugin);

use strict;

use GUS::PluginMgr::Plugin;
use FileHandle;

use ApiCommonData::Load::Util;

use GUS::Model::ApiDB::GeneProfileCorrelation;
use GUS::Model::ApiDB::ProfileSet;

my $argsDeclaration =
[

   fileArg({name           => 'correlationFile',
	    descr          => 'A tab delimeted file containing correlation between profile sets.',
	    reqd           => 1,
	    mustExist      => 1,
	    format         => 'First Column must be the sourceId then Column Headers must be exact as in Profile Name.',
	    constraintFunc => undef,
	    isList         => 0, }),

];

my $purpose = <<PURPOSE;
The purpose of this plugin is to load GeneFeature correlation data between 2 profileSets
PURPOSE

my $purposeBrief = <<PURPOSE_BRIEF;
The purpose of this plugin is to load GeneFeature correlation data between 2 profileSets
PURPOSE_BRIEF

my $notes = <<NOTES;
A tab delimeted file containing the correlation data.  The first column contains
source_ids...The remaining columns should contain correlation data.  The header is the 
first line in this file.  For the Columns containig correlation data, the header for
each column should be 2 ProfileSet Names delimeted by "-".
NOTES

my $tablesAffected = <<TABLES_AFFECTED;
ApiDB::GeneProfileCorrelation
TABLES_AFFECTED

my $tablesDependedOn = <<TABLES_DEPENDED_ON;
ApiDB:GeneProfileCorrelation, ApiDB::ProfileSet, ApiDB::GeneFeature
TABLES_DEPENDED_ON

my $howToRestart = <<RESTART;
No Restart utilities for this plugin.
RESTART

my $failureCases = <<FAIL_CASES;
FAIL_CASES

my $documentation = { purpose          => $purpose,
		      purposeBrief     => $purposeBrief,
		      notes            => $notes,
		      tablesAffected   => $tablesAffected,
		      tablesDependedOn => $tablesDependedOn,
		      howToRestart     => $howToRestart,
		      failureCases     => $failureCases };

# ----------------------------------------------------------------------

sub new {
  my ($class) = @_;
  my $self = {};
  bless($self,$class);

  $self->initialize({ requiredDbVersion => 3.5,
		      cvsRevision       => '$Revision$',
		      name              => ref($self),
		      argsDeclaration   => $argsDeclaration,
		      documentation     => $documentation});

  return $self;
}

# ======================================================================

sub run {
  my ($self) = @_;

  open(FILE, $self->getArg('correlationFile')) || die "Could Not open File for reading: $!\n";

  my $header = <FILE>;
  chomp $header;
  my @colNames = split("\t", $header);

  my $profileIdRef = $self->_getProfileIds(\@colNames);

  my $line = 1;

  while(<FILE>) {
    chomp;

    my @row = split("\t", $_);

    for(my $i = 1; $i < scalar @row; $i++){
      my $geneFeatureId = ApiCommonData::Load::Util::getGeneFeatureId($self, $row[0]);
      my $correlationValue = $row[$i];

      my @profiles = split("-", $colNames[$i]);

      if($correlationValue && $self->_okToLoad($colNames[$i], $profileIdRef)) {
	my $correlation = GUS::Model::ApiDB::GeneProfileCorrelation->
	  new({ gene_feature_id  => $geneFeatureId,
		first_profile_set_id => $profileIdRef->{$profiles[0]},
		second_profile_set_id => $profileIdRef->{$profiles[1]},
		score => $correlationValue
          });

        if($line % 1000 == 0) {
          $self->log("Processed $line GeneProfileCorrelation Entries");
        }

	$correlation->submit();
	$line++;
        $self->undefPointerCache();
      }
    }
  }
  close(FILE);

  return("Inserted $line rows into GeneProfileCorrelation");
}

=pod 

=head2 subroutine _getProfileIds

Returns a Hashref mapping ProfileSet Names to profileSet Ids

=cut

# ----------------------------------------------------------------------

sub _getProfileIds {
  my ($self, $colName) = @_;

  my %rv;

  foreach my $profiles (@$colName) {
    my @profileNames = split("-", $profiles);

    next if(scalar @profileNames != 2);

    foreach my $name (@profileNames) {
      my $profileSet = GUS::Model::ApiDB::ProfileSet->
	new({name => $name });

      if ($profileSet->retrieveFromDB()) {
	$rv{$name} = $profileSet->getId();
      }
      else {
	$self->log('ERRROR', 'ProfileSet Name not (uniquely) matched', $profileSet->getName());
	die 'Profile Set Name Not Uniquely Matched.\n $!\n';
      }
    }
  }
  return(\%rv);
}

=pod

=head2 subroutine _okToLoad

boolean; Check that the header for this column was in the right format.

=cut

# ----------------------------------------------------------------------

sub _okToLoad {
  my ($self, $header, $profileIdsRef) = @_;

  my @profileNames = split("-", $header);

  return(0) if(scalar @profileNames != 2);

  foreach my $name (@profileNames) {
    if(!exists($profileIdsRef->{$name})) {
      print STDERR "Incorrect header $header.  No profileSetId for name $name\n";
      return(0);
    }
  }
  return(1);
}


1;

